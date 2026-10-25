
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>:
 11ea3d0:	55                   	push   %rbp
 11ea3d1:	48 89 e5             	mov    %rsp,%rbp
 11ea3d4:	41 57                	push   %r15
 11ea3d6:	41 56                	push   %r14
 11ea3d8:	41 55                	push   %r13
 11ea3da:	41 54                	push   %r12
 11ea3dc:	53                   	push   %rbx
 11ea3dd:	48 81 ec 38 1d 00 00 	sub    $0x1d38,%rsp
 11ea3e4:	4d 89 c7             	mov    %r8,%r15
 11ea3e7:	49 89 cd             	mov    %rcx,%r13
 11ea3ea:	49 89 f4             	mov    %rsi,%r12
 11ea3ed:	48 89 fb             	mov    %rdi,%rbx
 11ea3f0:	49 83 f9 02          	cmp    $0x2,%r9
 11ea3f4:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 11ea3f8:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 11ea3fc:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 11ea400:	48 89 55 a0          	mov    %rdx,-0x60(%rbp)
 11ea404:	0f 85 b6 01 00 00    	jne    11ea5c0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x1f0>
 11ea40a:	41 80 7f 58 01       	cmpb   $0x1,0x58(%r15)
 11ea40f:	0f 85 ab 01 00 00    	jne    11ea5c0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x1f0>
 11ea415:	41 f6 47 59 03       	testb  $0x3,0x59(%r15)
 11ea41a:	0f 85 a0 01 00 00    	jne    11ea5c0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x1f0>
 11ea420:	49 83 7f 10 03       	cmpq   $0x3,0x10(%r15)
 11ea425:	0f 85 95 01 00 00    	jne    11ea5c0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x1f0>
 11ea42b:	48 8d bd 88 f3 ff ff 	lea    -0xc78(%rbp),%rdi
 11ea432:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 11ea438:	4c 89 e6             	mov    %r12,%rsi
 11ea43b:	4c 89 e9             	mov    %r13,%rcx
 11ea43e:	4d 89 f8             	mov    %r15,%r8
 11ea441:	ff 75 18             	push   0x18(%rbp)
 11ea444:	ff 75 10             	push   0x10(%rbp)
 11ea447:	e8 74 59 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea44c:	48 83 c4 10          	add    $0x10,%rsp
 11ea450:	0f b7 85 e8 f4 ff ff 	movzwl -0xb18(%rbp),%eax
 11ea457:	66 85 c0             	test   %ax,%ax
 11ea45a:	0f 85 03 08 00 00    	jne    11eac63 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x893>
 11ea460:	48 8d bd 60 fa ff ff 	lea    -0x5a0(%rbp),%rdi
 11ea467:	48 8d b5 88 f3 ff ff 	lea    -0xc78(%rbp),%rsi
 11ea46e:	ba 60 01 00 00       	mov    $0x160,%edx
 11ea473:	e8 a8 bd 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea478:	48 8b 85 60 fa ff ff 	mov    -0x5a0(%rbp),%rax
 11ea47f:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 11ea483:	48 8b 85 68 fa ff ff 	mov    -0x598(%rbp),%rax
 11ea48a:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 11ea48e:	48 c7 85 68 ff ff ff 	movq   $0x0,-0x98(%rbp)
 11ea495:	00 00 00 00 
 11ea499:	48 8d 85 68 ff ff ff 	lea    -0x98(%rbp),%rax
 11ea4a0:	48 8d bd b8 fe ff ff 	lea    -0x148(%rbp),%rdi
 11ea4a7:	48 8d b5 a8 ee ff ff 	lea    -0x1158(%rbp),%rsi
 11ea4ae:	ba 02 00 00 00       	mov    $0x2,%edx
 11ea4b3:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 11ea4b9:	4c 89 e9             	mov    %r13,%rcx
 11ea4bc:	4c 89 7d 90          	mov    %r15,-0x70(%rbp)
 11ea4c0:	4d 89 f8             	mov    %r15,%r8
 11ea4c3:	6a 01                	push   $0x1
 11ea4c5:	50                   	push   %rax
 11ea4c6:	e8 65 fc ff ff       	call   11ea130 <br.encoder.command_plan.withoutCopiesInto>
 11ea4cb:	48 83 c4 10          	add    $0x10,%rsp
 11ea4cf:	0f b7 9d c8 fe ff ff 	movzwl -0x138(%rbp),%ebx
 11ea4d6:	66 85 db             	test   %bx,%bx
 11ea4d9:	0f 85 e5 07 00 00    	jne    11eacc4 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8f4>
 11ea4df:	4c 8b b5 b8 fe ff ff 	mov    -0x148(%rbp),%r14
 11ea4e6:	4c 8b bd c0 fe ff ff 	mov    -0x140(%rbp),%r15
 11ea4ed:	48 8d bd 20 f2 ff ff 	lea    -0xde0(%rbp),%rdi
 11ea4f4:	4c 89 e6             	mov    %r12,%rsi
 11ea4f7:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea4fb:	4c 89 e9             	mov    %r13,%rcx
 11ea4fe:	4d 89 f0             	mov    %r14,%r8
 11ea501:	4d 89 f9             	mov    %r15,%r9
 11ea504:	ff 75 18             	push   0x18(%rbp)
 11ea507:	ff 75 10             	push   0x10(%rbp)
 11ea50a:	e8 b1 58 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea50f:	48 83 c4 10          	add    $0x10,%rsp
 11ea513:	0f b7 9d 80 f3 ff ff 	movzwl -0xc80(%rbp),%ebx
 11ea51a:	66 85 db             	test   %bx,%bx
 11ea51d:	0f 85 a1 07 00 00    	jne    11eacc4 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8f4>
 11ea523:	48 8d 9d f0 f4 ff ff 	lea    -0xb10(%rbp),%rbx
 11ea52a:	48 8d b5 20 f2 ff ff 	lea    -0xde0(%rbp),%rsi
 11ea531:	ba 60 01 00 00       	mov    $0x160,%edx
 11ea536:	48 89 df             	mov    %rbx,%rdi
 11ea539:	e8 e2 bc 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea53e:	4c 8b ad f0 f4 ff ff 	mov    -0xb10(%rbp),%r13
 11ea545:	4c 8b a5 f8 f4 ff ff 	mov    -0xb08(%rbp),%r12
 11ea54c:	4c 3b 65 d0          	cmp    -0x30(%rbp),%r12
 11ea550:	0f 83 58 05 00 00    	jae    11eaaae <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6de>
 11ea556:	48 83 ec 08          	sub    $0x8,%rsp
 11ea55a:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 11ea561:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11ea565:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea569:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ea56d:	4d 89 f0             	mov    %r14,%r8
 11ea570:	4d 89 f9             	mov    %r15,%r9
 11ea573:	53                   	push   %rbx
 11ea574:	ff 75 18             	push   0x18(%rbp)
 11ea577:	ff 75 10             	push   0x10(%rbp)
 11ea57a:	e8 a1 0a 00 00       	call   11eb020 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527>
 11ea57f:	48 83 c4 20          	add    $0x20,%rsp
 11ea583:	44 0f b7 b5 40 ff ff 	movzwl -0xc0(%rbp),%r14d
 11ea58a:	ff 
 11ea58b:	66 45 85 f6          	test   %r14w,%r14w
 11ea58f:	0f 84 12 06 00 00    	je     11eaba7 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x7d7>
 11ea595:	4d 85 e4             	test   %r12,%r12
 11ea598:	0f 84 5c 06 00 00    	je     11eabfa <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x82a>
 11ea59e:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 11ea5a2:	49 8b 3f             	mov    (%r15),%rdi
 11ea5a5:	49 8b 47 08          	mov    0x8(%r15),%rax
 11ea5a9:	48 8b 5d 08          	mov    0x8(%rbp),%rbx
 11ea5ad:	4c 89 ee             	mov    %r13,%rsi
 11ea5b0:	4c 89 e2             	mov    %r12,%rdx
 11ea5b3:	31 c9                	xor    %ecx,%ecx
 11ea5b5:	49 89 d8             	mov    %rbx,%r8
 11ea5b8:	ff 50 18             	call   *0x18(%rax)
 11ea5bb:	e9 42 06 00 00       	jmp    11eac02 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x832>
 11ea5c0:	48 8d bd 90 fe ff ff 	lea    -0x170(%rbp),%rdi
 11ea5c7:	4c 89 fe             	mov    %r15,%rsi
 11ea5ca:	4d 89 ce             	mov    %r9,%r14
 11ea5cd:	4c 89 ca             	mov    %r9,%rdx
 11ea5d0:	e8 2b 07 00 00       	call   11ead00 <br.encoder.short_match_candidates.collect>
 11ea5d5:	48 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%rax
 11ea5dc:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 11ea5e3:	48 85 c0             	test   %rax,%rax
 11ea5e6:	0f 84 82 03 00 00    	je     11ea96e <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x59e>
 11ea5ec:	48 8d bd 28 fd ff ff 	lea    -0x2d8(%rbp),%rdi
 11ea5f3:	4c 89 e6             	mov    %r12,%rsi
 11ea5f6:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea5fa:	4c 89 e9             	mov    %r13,%rcx
 11ea5fd:	4d 89 f8             	mov    %r15,%r8
 11ea600:	4d 89 f1             	mov    %r14,%r9
 11ea603:	ff 75 18             	push   0x18(%rbp)
 11ea606:	ff 75 10             	push   0x10(%rbp)
 11ea609:	e8 b2 57 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea60e:	48 83 c4 10          	add    $0x10,%rsp
 11ea612:	0f b7 85 88 fe ff ff 	movzwl -0x178(%rbp),%eax
 11ea619:	66 85 c0             	test   %ax,%ax
 11ea61c:	0f 85 41 06 00 00    	jne    11eac63 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x893>
 11ea622:	48 8b 85 28 fd ff ff 	mov    -0x2d8(%rbp),%rax
 11ea629:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 11ea62d:	48 8b 85 30 fd ff ff 	mov    -0x2d0(%rbp),%rax
 11ea634:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 11ea638:	48 8d b5 38 fd ff ff 	lea    -0x2c8(%rbp),%rsi
 11ea63f:	48 8d bd 50 f6 ff ff 	lea    -0x9b0(%rbp),%rdi
 11ea646:	ba 50 01 00 00       	mov    $0x150,%edx
 11ea64b:	e8 d0 bb 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea650:	4d 89 f1             	mov    %r14,%r9
 11ea653:	44 89 c8             	mov    %r9d,%eax
 11ea656:	83 e0 03             	and    $0x3,%eax
 11ea659:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 11ea660:	4c 89 f3             	mov    %r14,%rbx
 11ea663:	48 83 e3 fc          	and    $0xfffffffffffffffc,%rbx
 11ea667:	31 f6                	xor    %esi,%esi
 11ea669:	4c 89 75 80          	mov    %r14,-0x80(%rbp)
 11ea66d:	4c 89 7d 90          	mov    %r15,-0x70(%rbp)
 11ea671:	4c 89 7d 88          	mov    %r15,-0x78(%rbp)
 11ea675:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11ea67c:	00 00 00 00 
 11ea680:	4d 85 c9             	test   %r9,%r9
 11ea683:	0f 84 b7 00 00 00    	je     11ea740 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x370>
 11ea689:	0f b7 84 75 98 fe ff 	movzwl -0x168(%rbp,%rsi,2),%eax
 11ea690:	ff 
 11ea691:	31 c9                	xor    %ecx,%ecx
 11ea693:	45 31 d2             	xor    %r10d,%r10d
 11ea696:	49 83 f9 04          	cmp    $0x4,%r9
 11ea69a:	73 4d                	jae    11ea6e9 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x319>
 11ea69c:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 11ea6a3:	00 
 11ea6a4:	0f 84 99 00 00 00    	je     11ea743 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x373>
 11ea6aa:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 11ea6b1:	eb 15                	jmp    11ea6c8 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x2f8>
 11ea6b3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11ea6ba:	84 00 00 00 00 00 
 11ea6c0:	48 ff c1             	inc    %rcx
 11ea6c3:	48 ff ca             	dec    %rdx
 11ea6c6:	74 7b                	je     11ea743 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x373>
 11ea6c8:	0f a3 c8             	bt     %ecx,%eax
 11ea6cb:	73 f3                	jae    11ea6c0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x2f0>
 11ea6cd:	4a 89 8c d5 48 ff ff 	mov    %rcx,-0xb8(%rbp,%r10,8)
 11ea6d4:	ff 
 11ea6d5:	49 ff c2             	inc    %r10
 11ea6d8:	eb e6                	jmp    11ea6c0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x2f0>
 11ea6da:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 11ea6e0:	48 83 c1 04          	add    $0x4,%rcx
 11ea6e4:	48 39 cb             	cmp    %rcx,%rbx
 11ea6e7:	74 b3                	je     11ea69c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x2cc>
 11ea6e9:	0f a3 c8             	bt     %ecx,%eax
 11ea6ec:	73 0b                	jae    11ea6f9 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x329>
 11ea6ee:	4a 89 8c d5 48 ff ff 	mov    %rcx,-0xb8(%rbp,%r10,8)
 11ea6f5:	ff 
 11ea6f6:	49 ff c2             	inc    %r10
 11ea6f9:	48 8d 51 01          	lea    0x1(%rcx),%rdx
 11ea6fd:	0f a3 d0             	bt     %edx,%eax
 11ea700:	73 0b                	jae    11ea70d <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x33d>
 11ea702:	4a 89 94 d5 48 ff ff 	mov    %rdx,-0xb8(%rbp,%r10,8)
 11ea709:	ff 
 11ea70a:	49 ff c2             	inc    %r10
 11ea70d:	48 8d 51 02          	lea    0x2(%rcx),%rdx
 11ea711:	0f a3 d0             	bt     %edx,%eax
 11ea714:	73 0b                	jae    11ea721 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x351>
 11ea716:	4a 89 94 d5 48 ff ff 	mov    %rdx,-0xb8(%rbp,%r10,8)
 11ea71d:	ff 
 11ea71e:	49 ff c2             	inc    %r10
 11ea721:	48 8d 51 03          	lea    0x3(%rcx),%rdx
 11ea725:	0f a3 d0             	bt     %edx,%eax
 11ea728:	73 b6                	jae    11ea6e0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x310>
 11ea72a:	4a 89 94 d5 48 ff ff 	mov    %rdx,-0xb8(%rbp,%r10,8)
 11ea731:	ff 
 11ea732:	49 ff c2             	inc    %r10
 11ea735:	eb a9                	jmp    11ea6e0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x310>
 11ea737:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 11ea73e:	00 00 
 11ea740:	45 31 d2             	xor    %r10d,%r10d
 11ea743:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 11ea747:	ba 10 00 00 00       	mov    $0x10,%edx
 11ea74c:	48 8d bd 00 ff ff ff 	lea    -0x100(%rbp),%rdi
 11ea753:	48 8d b5 a8 e2 ff ff 	lea    -0x1d58(%rbp),%rsi
 11ea75a:	4c 89 e9             	mov    %r13,%rcx
 11ea75d:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ea761:	4d 89 cf             	mov    %r9,%r15
 11ea764:	41 52                	push   %r10
 11ea766:	48 8d 85 48 ff ff ff 	lea    -0xb8(%rbp),%rax
 11ea76d:	50                   	push   %rax
 11ea76e:	e8 bd f9 ff ff       	call   11ea130 <br.encoder.command_plan.withoutCopiesInto>
 11ea773:	48 83 c4 10          	add    $0x10,%rsp
 11ea777:	44 0f b7 b5 10 ff ff 	movzwl -0xf0(%rbp),%r14d
 11ea77e:	ff 
 11ea77f:	66 45 85 f6          	test   %r14w,%r14w
 11ea783:	0f 85 ca 03 00 00    	jne    11eab53 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x783>
 11ea789:	4c 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%r14
 11ea790:	4c 89 e9             	mov    %r13,%rcx
 11ea793:	4c 8b ad 08 ff ff ff 	mov    -0xf8(%rbp),%r13
 11ea79a:	48 8d bd c0 fb ff ff 	lea    -0x440(%rbp),%rdi
 11ea7a1:	4c 89 e6             	mov    %r12,%rsi
 11ea7a4:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea7a8:	4d 89 f0             	mov    %r14,%r8
 11ea7ab:	4d 89 e9             	mov    %r13,%r9
 11ea7ae:	ff 75 18             	push   0x18(%rbp)
 11ea7b1:	ff 75 10             	push   0x10(%rbp)
 11ea7b4:	e8 07 56 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea7b9:	48 83 c4 10          	add    $0x10,%rsp
 11ea7bd:	44 0f b7 a5 20 fd ff 	movzwl -0x2e0(%rbp),%r12d
 11ea7c4:	ff 
 11ea7c5:	66 45 85 e4          	test   %r12w,%r12w
 11ea7c9:	0f 85 a9 03 00 00    	jne    11eab78 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x7a8>
 11ea7cf:	48 8b 85 c0 fb ff ff 	mov    -0x440(%rbp),%rax
 11ea7d6:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 11ea7da:	4c 8b a5 c8 fb ff ff 	mov    -0x438(%rbp),%r12
 11ea7e1:	ba 50 01 00 00       	mov    $0x150,%edx
 11ea7e6:	48 8d bd 68 ef ff ff 	lea    -0x1098(%rbp),%rdi
 11ea7ed:	48 8d b5 d0 fb ff ff 	lea    -0x430(%rbp),%rsi
 11ea7f4:	e8 27 ba 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea7f9:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 11ea7fd:	49 39 d4             	cmp    %rdx,%r12
 11ea800:	73 6e                	jae    11ea870 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x4a0>
 11ea802:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ea806:	48 8b 38             	mov    (%rax),%rdi
 11ea809:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ea80d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ea811:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 11ea815:	31 c9                	xor    %ecx,%ecx
 11ea817:	ff 50 18             	call   *0x18(%rax)
 11ea81a:	ba 50 01 00 00       	mov    $0x150,%edx
 11ea81f:	48 8d bd 50 f6 ff ff 	lea    -0x9b0(%rbp),%rdi
 11ea826:	48 8d b5 68 ef ff ff 	lea    -0x1098(%rbp),%rsi
 11ea82d:	e8 ee b9 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea832:	4c 89 e8             	mov    %r13,%rax
 11ea835:	48 c1 e0 05          	shl    $0x5,%rax
 11ea839:	48 8d 14 40          	lea    (%rax,%rax,2),%rdx
 11ea83d:	48 8d bd a8 e8 ff ff 	lea    -0x1758(%rbp),%rdi
 11ea844:	4c 89 f6             	mov    %r14,%rsi
 11ea847:	e8 d4 b9 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea84c:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11ea850:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 11ea854:	4c 89 65 b0          	mov    %r12,-0x50(%rbp)
 11ea858:	48 8d 85 a8 e8 ff ff 	lea    -0x1758(%rbp),%rax
 11ea85f:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11ea863:	4c 89 6d 80          	mov    %r13,-0x80(%rbp)
 11ea867:	eb 27                	jmp    11ea890 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x4c0>
 11ea869:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 11ea870:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11ea874:	4d 85 e4             	test   %r12,%r12
 11ea877:	74 17                	je     11ea890 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x4c0>
 11ea879:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ea87d:	48 8b 38             	mov    (%rax),%rdi
 11ea880:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ea884:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ea888:	4c 89 e2             	mov    %r12,%rdx
 11ea88b:	31 c9                	xor    %ecx,%ecx
 11ea88d:	ff 50 18             	call   *0x18(%rax)
 11ea890:	4c 8b 6d 98          	mov    -0x68(%rbp),%r13
 11ea894:	4d 89 f9             	mov    %r15,%r9
 11ea897:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 11ea89b:	48 ff c6             	inc    %rsi
 11ea89e:	48 3b b5 70 ff ff ff 	cmp    -0x90(%rbp),%rsi
 11ea8a5:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 11ea8a9:	0f 85 d1 fd ff ff    	jne    11ea680 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x2b0>
 11ea8af:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11ea8b3:	48 89 85 00 f9 ff ff 	mov    %rax,-0x700(%rbp)
 11ea8ba:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 11ea8be:	48 89 85 08 f9 ff ff 	mov    %rax,-0x6f8(%rbp)
 11ea8c5:	48 8d bd 10 f9 ff ff 	lea    -0x6f0(%rbp),%rdi
 11ea8cc:	48 8d b5 50 f6 ff ff 	lea    -0x9b0(%rbp),%rsi
 11ea8d3:	ba 50 01 00 00       	mov    $0x150,%edx
 11ea8d8:	e8 43 b9 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea8dd:	48 83 ec 08          	sub    $0x8,%rsp
 11ea8e1:	48 8d 85 00 f9 ff ff 	lea    -0x700(%rbp),%rax
 11ea8e8:	48 8d bd e8 fe ff ff 	lea    -0x118(%rbp),%rdi
 11ea8ef:	4c 89 e6             	mov    %r12,%rsi
 11ea8f2:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea8f6:	4c 89 e9             	mov    %r13,%rcx
 11ea8f9:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 11ea8fd:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ea901:	50                   	push   %rax
 11ea902:	ff 75 18             	push   0x18(%rbp)
 11ea905:	ff 75 10             	push   0x10(%rbp)
 11ea908:	e8 13 07 00 00       	call   11eb020 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527>
 11ea90d:	48 83 c4 20          	add    $0x20,%rsp
 11ea911:	0f b7 9d f8 fe ff ff 	movzwl -0x108(%rbp),%ebx
 11ea918:	66 85 db             	test   %bx,%bx
 11ea91b:	0f 85 4b 03 00 00    	jne    11eac6c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x89c>
 11ea921:	48 8b 9d e8 fe ff ff 	mov    -0x118(%rbp),%rbx
 11ea928:	48 85 db             	test   %rbx,%rbx
 11ea92b:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 11ea92f:	0f 84 34 01 00 00    	je     11eaa69 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x699>
 11ea935:	4c 8b b5 f0 fe ff ff 	mov    -0x110(%rbp),%r14
 11ea93c:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 11ea940:	48 85 d2             	test   %rdx,%rdx
 11ea943:	74 16                	je     11ea95b <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x58b>
 11ea945:	49 8b 3c 24          	mov    (%r12),%rdi
 11ea949:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 11ea94e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ea952:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 11ea956:	31 c9                	xor    %ecx,%ecx
 11ea958:	ff 50 18             	call   *0x18(%rax)
 11ea95b:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 11ea962:	49 89 1f             	mov    %rbx,(%r15)
 11ea965:	4d 89 77 08          	mov    %r14,0x8(%r15)
 11ea969:	e9 2e 01 00 00       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11ea96e:	48 8d bd b8 f0 ff ff 	lea    -0xf48(%rbp),%rdi
 11ea975:	4c 89 e6             	mov    %r12,%rsi
 11ea978:	4c 89 f3             	mov    %r14,%rbx
 11ea97b:	4d 89 fe             	mov    %r15,%r14
 11ea97e:	4c 8b 7d a0          	mov    -0x60(%rbp),%r15
 11ea982:	4c 89 fa             	mov    %r15,%rdx
 11ea985:	4c 89 e9             	mov    %r13,%rcx
 11ea988:	4d 89 f0             	mov    %r14,%r8
 11ea98b:	49 89 d9             	mov    %rbx,%r9
 11ea98e:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ea992:	50                   	push   %rax
 11ea993:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ea997:	50                   	push   %rax
 11ea998:	e8 23 54 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea99d:	48 83 c4 10          	add    $0x10,%rsp
 11ea9a1:	0f b7 85 18 f2 ff ff 	movzwl -0xde8(%rbp),%eax
 11ea9a8:	66 85 c0             	test   %ax,%ax
 11ea9ab:	0f 85 e8 02 00 00    	jne    11eac99 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8c9>
 11ea9b1:	48 8d bd a0 f7 ff ff 	lea    -0x860(%rbp),%rdi
 11ea9b8:	48 8d b5 b8 f0 ff ff 	lea    -0xf48(%rbp),%rsi
 11ea9bf:	ba 60 01 00 00       	mov    $0x160,%edx
 11ea9c4:	e8 57 b8 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11ea9c9:	48 8b 8d a0 f7 ff ff 	mov    -0x860(%rbp),%rcx
 11ea9d0:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 11ea9d4:	48 8b 8d a8 f7 ff ff 	mov    -0x858(%rbp),%rcx
 11ea9db:	48 89 4d d0          	mov    %rcx,-0x30(%rbp)
 11ea9df:	48 83 ec 08          	sub    $0x8,%rsp
 11ea9e3:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 11ea9ea:	4c 89 e6             	mov    %r12,%rsi
 11ea9ed:	4c 89 fa             	mov    %r15,%rdx
 11ea9f0:	4c 89 e9             	mov    %r13,%rcx
 11ea9f3:	4d 89 f0             	mov    %r14,%r8
 11ea9f6:	49 89 d9             	mov    %rbx,%r9
 11ea9f9:	48 8d 85 a0 f7 ff ff 	lea    -0x860(%rbp),%rax
 11eaa00:	50                   	push   %rax
 11eaa01:	ff 75 18             	push   0x18(%rbp)
 11eaa04:	ff 75 10             	push   0x10(%rbp)
 11eaa07:	e8 14 06 00 00       	call   11eb020 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527>
 11eaa0c:	48 83 c4 20          	add    $0x20,%rsp
 11eaa10:	0f b7 9d e0 fe ff ff 	movzwl -0x120(%rbp),%ebx
 11eaa17:	66 85 db             	test   %bx,%bx
 11eaa1a:	0f 85 86 02 00 00    	jne    11eaca6 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8d6>
 11eaa20:	48 8b 9d d0 fe ff ff 	mov    -0x130(%rbp),%rbx
 11eaa27:	48 85 db             	test   %rbx,%rbx
 11eaa2a:	74 55                	je     11eaa81 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6b1>
 11eaa2c:	4c 8b a5 d8 fe ff ff 	mov    -0x128(%rbp),%r12
 11eaa33:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eaa37:	48 85 d2             	test   %rdx,%rdx
 11eaa3a:	74 18                	je     11eaa54 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x684>
 11eaa3c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eaa40:	48 8b 38             	mov    (%rax),%rdi
 11eaa43:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eaa47:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eaa4b:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11eaa4f:	31 c9                	xor    %ecx,%ecx
 11eaa51:	ff 50 18             	call   *0x18(%rax)
 11eaa54:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 11eaa58:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 11eaa5f:	49 89 5d 00          	mov    %rbx,0x0(%r13)
 11eaa63:	4d 89 65 08          	mov    %r12,0x8(%r13)
 11eaa67:	eb 33                	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eaa69:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 11eaa70:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11eaa74:	49 89 07             	mov    %rax,(%r15)
 11eaa77:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 11eaa7b:	49 89 47 08          	mov    %rax,0x8(%r15)
 11eaa7f:	eb 1b                	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eaa81:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 11eaa85:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 11eaa8c:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11eaa90:	49 89 45 00          	mov    %rax,0x0(%r13)
 11eaa94:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 11eaa98:	49 89 45 08          	mov    %rax,0x8(%r13)
 11eaa9c:	48 81 c4 38 1d 00 00 	add    $0x1d38,%rsp
 11eaaa3:	5b                   	pop    %rbx
 11eaaa4:	41 5c                	pop    %r12
 11eaaa6:	41 5d                	pop    %r13
 11eaaa8:	41 5e                	pop    %r14
 11eaaaa:	41 5f                	pop    %r15
 11eaaac:	5d                   	pop    %rbp
 11eaaad:	c3                   	ret    
 11eaaae:	4d 85 e4             	test   %r12,%r12
 11eaab1:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 11eaab5:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11eaab9:	74 16                	je     11eaad1 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x701>
 11eaabb:	49 8b 3e             	mov    (%r14),%rdi
 11eaabe:	49 8b 46 08          	mov    0x8(%r14),%rax
 11eaac2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eaac6:	4c 89 ee             	mov    %r13,%rsi
 11eaac9:	4c 89 e2             	mov    %r12,%rdx
 11eaacc:	31 c9                	xor    %ecx,%ecx
 11eaace:	ff 50 18             	call   *0x18(%rax)
 11eaad1:	48 83 ec 08          	sub    $0x8,%rsp
 11eaad5:	48 8d bd 18 ff ff ff 	lea    -0xe8(%rbp),%rdi
 11eaadc:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 11eaae2:	4c 89 f6             	mov    %r14,%rsi
 11eaae5:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11eaae9:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11eaaed:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11eaaf1:	48 8d 85 60 fa ff ff 	lea    -0x5a0(%rbp),%rax
 11eaaf8:	50                   	push   %rax
 11eaaf9:	ff 75 18             	push   0x18(%rbp)
 11eaafc:	ff 75 10             	push   0x10(%rbp)
 11eaaff:	e8 1c 05 00 00       	call   11eb020 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527>
 11eab04:	48 83 c4 20          	add    $0x20,%rsp
 11eab08:	0f b7 9d 28 ff ff ff 	movzwl -0xd8(%rbp),%ebx
 11eab0f:	66 85 db             	test   %bx,%bx
 11eab12:	0f 85 ac 01 00 00    	jne    11eacc4 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8f4>
 11eab18:	48 8b 9d 18 ff ff ff 	mov    -0xe8(%rbp),%rbx
 11eab1f:	48 85 db             	test   %rbx,%rbx
 11eab22:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eab26:	0f 84 b7 00 00 00    	je     11eabe3 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x813>
 11eab2c:	4c 89 f0             	mov    %r14,%rax
 11eab2f:	4c 8b b5 20 ff ff ff 	mov    -0xe0(%rbp),%r14
 11eab36:	48 85 d2             	test   %rdx,%rdx
 11eab39:	0f 84 1c fe ff ff    	je     11ea95b <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x58b>
 11eab3f:	48 8b 38             	mov    (%rax),%rdi
 11eab42:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eab46:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eab4a:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11eab4e:	e9 03 fe ff ff       	jmp    11ea956 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x586>
 11eab53:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 11eab57:	48 85 d2             	test   %rdx,%rdx
 11eab5a:	0f 84 b9 00 00 00    	je     11eac19 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x849>
 11eab60:	49 8b 3c 24          	mov    (%r12),%rdi
 11eab64:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 11eab69:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eab6d:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 11eab71:	31 c9                	xor    %ecx,%ecx
 11eab73:	e9 9e 00 00 00       	jmp    11eac16 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x846>
 11eab78:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 11eab7c:	48 85 d2             	test   %rdx,%rdx
 11eab7f:	74 18                	je     11eab99 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x7c9>
 11eab81:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eab85:	48 8b 38             	mov    (%rax),%rdi
 11eab88:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eab8c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eab90:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 11eab94:	31 c9                	xor    %ecx,%ecx
 11eab96:	ff 50 18             	call   *0x18(%rax)
 11eab99:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11eab9d:	66 44 89 60 10       	mov    %r12w,0x10(%rax)
 11eaba2:	e9 f5 fe ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eaba7:	48 8b 9d 30 ff ff ff 	mov    -0xd0(%rbp),%rbx
 11eabae:	48 85 db             	test   %rbx,%rbx
 11eabb1:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 11eabb5:	74 70                	je     11eac27 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x857>
 11eabb7:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11eabbe:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 11eabc2:	4d 85 e4             	test   %r12,%r12
 11eabc5:	74 69                	je     11eac30 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x860>
 11eabc7:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11eabcb:	49 8b 3e             	mov    (%r14),%rdi
 11eabce:	49 8b 46 08          	mov    0x8(%r14),%rax
 11eabd2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eabd6:	4c 89 ee             	mov    %r13,%rsi
 11eabd9:	4c 89 e2             	mov    %r12,%rdx
 11eabdc:	31 c9                	xor    %ecx,%ecx
 11eabde:	ff 50 18             	call   *0x18(%rax)
 11eabe1:	eb 51                	jmp    11eac34 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x864>
 11eabe3:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 11eabea:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11eabee:	49 89 07             	mov    %rax,(%r15)
 11eabf1:	49 89 57 08          	mov    %rdx,0x8(%r15)
 11eabf5:	e9 a2 fe ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eabfa:	48 8b 5d 08          	mov    0x8(%rbp),%rbx
 11eabfe:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 11eac02:	49 8b 3f             	mov    (%r15),%rdi
 11eac05:	49 8b 47 08          	mov    0x8(%r15),%rax
 11eac09:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11eac0d:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eac11:	31 c9                	xor    %ecx,%ecx
 11eac13:	49 89 d8             	mov    %rbx,%r8
 11eac16:	ff 50 18             	call   *0x18(%rax)
 11eac19:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11eac1d:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 11eac22:	e9 75 fe ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eac27:	4c 89 eb             	mov    %r13,%rbx
 11eac2a:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11eac2e:	eb 08                	jmp    11eac38 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x868>
 11eac30:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11eac34:	4c 8b 65 b0          	mov    -0x50(%rbp),%r12
 11eac38:	49 8b 3e             	mov    (%r14),%rdi
 11eac3b:	49 8b 46 08          	mov    0x8(%r14),%rax
 11eac3f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eac43:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11eac47:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eac4b:	31 c9                	xor    %ecx,%ecx
 11eac4d:	ff 50 18             	call   *0x18(%rax)
 11eac50:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 11eac57:	49 89 1f             	mov    %rbx,(%r15)
 11eac5a:	4d 89 67 08          	mov    %r12,0x8(%r15)
 11eac5e:	e9 39 fe ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eac63:	66 89 43 10          	mov    %ax,0x10(%rbx)
 11eac67:	e9 30 fe ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eac6c:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 11eac70:	48 85 d2             	test   %rdx,%rdx
 11eac73:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 11eac77:	74 16                	je     11eac8f <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8bf>
 11eac79:	49 8b 3c 24          	mov    (%r12),%rdi
 11eac7d:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 11eac82:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eac86:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 11eac8a:	31 c9                	xor    %ecx,%ecx
 11eac8c:	ff 50 18             	call   *0x18(%rax)
 11eac8f:	66 41 89 5e 10       	mov    %bx,0x10(%r14)
 11eac94:	e9 03 fe ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eac99:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 11eac9d:	66 89 41 10          	mov    %ax,0x10(%rcx)
 11eaca1:	e9 f6 fd ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>
 11eaca6:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eacaa:	48 85 d2             	test   %rdx,%rdx
 11eacad:	74 38                	je     11eace7 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x917>
 11eacaf:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eacb3:	48 8b 38             	mov    (%rax),%rdi
 11eacb6:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eacba:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eacbe:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11eacc2:	eb 1e                	jmp    11eace2 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x912>
 11eacc4:	48 83 7d d0 00       	cmpq   $0x0,-0x30(%rbp)
 11eacc9:	74 1c                	je     11eace7 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x917>
 11eaccb:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eaccf:	48 8b 38             	mov    (%rax),%rdi
 11eacd2:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eacd6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eacda:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11eacde:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eace2:	31 c9                	xor    %ecx,%ecx
 11eace4:	ff 50 18             	call   *0x18(%rax)
 11eace7:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11eaceb:	66 89 58 10          	mov    %bx,0x10(%rax)
 11eacef:	e9 a8 fd ff ff       	jmp    11eaa9c <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x6cc>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
