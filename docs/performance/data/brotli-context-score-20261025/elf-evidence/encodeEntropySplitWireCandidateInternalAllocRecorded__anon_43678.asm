
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>:
 11f05f0:	55                   	push   %rbp
 11f05f1:	48 89 e5             	mov    %rsp,%rbp
 11f05f4:	41 57                	push   %r15
 11f05f6:	41 56                	push   %r14
 11f05f8:	41 55                	push   %r13
 11f05fa:	41 54                	push   %r12
 11f05fc:	53                   	push   %rbx
 11f05fd:	48 81 ec 48 0b 00 00 	sub    $0xb48,%rsp
 11f0604:	4c 89 4d 80          	mov    %r9,-0x80(%rbp)
 11f0608:	4c 89 45 88          	mov    %r8,-0x78(%rbp)
 11f060c:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 11f0610:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 11f0614:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 11f0618:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 11f061c:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11f0620:	48 8b 08             	mov    (%rax),%rcx
 11f0623:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 11f0627:	48 8b 48 08          	mov    0x8(%rax),%rcx
 11f062b:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 11f062f:	48 8b 48 10          	mov    0x10(%rax),%rcx
 11f0633:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 11f0637:	48 8b 48 18          	mov    0x18(%rax),%rcx
 11f063b:	48 89 4d a8          	mov    %rcx,-0x58(%rbp)
 11f063f:	c5 fc 10 40 20       	vmovups 0x20(%rax),%ymm0
 11f0644:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 11f064b:	ff 
 11f064c:	44 0f b6 68 40       	movzbl 0x40(%rax),%r13d
 11f0651:	44 88 6d d0          	mov    %r13b,-0x30(%rbp)
 11f0655:	0f b6 48 4e          	movzbl 0x4e(%rax),%ecx
 11f0659:	88 4d d7             	mov    %cl,-0x29(%rbp)
 11f065c:	4c 8d 60 20          	lea    0x20(%rax),%r12
 11f0660:	4c 8b 7d 28          	mov    0x28(%rbp),%r15
 11f0664:	48 8b 5d 20          	mov    0x20(%rbp),%rbx
 11f0668:	4c 8b 75 10          	mov    0x10(%rbp),%r14
 11f066c:	48 8d bd 98 f4 ff ff 	lea    -0xb68(%rbp),%rdi
 11f0673:	ba 60 01 00 00       	mov    $0x160,%edx
 11f0678:	48 89 de             	mov    %rbx,%rsi
 11f067b:	c5 f8 77             	vzeroupper 
 11f067e:	e8 9d 5b 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11f0683:	c4 c1 7c 10 46 70    	vmovups 0x70(%r14),%ymm0
 11f0689:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 11f0690:	ff 
 11f0691:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 11f0696:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 11f069c:	c4 c1 7c 10 56 40    	vmovups 0x40(%r14),%ymm2
 11f06a2:	c4 c1 7c 10 5e 60    	vmovups 0x60(%r14),%ymm3
 11f06a8:	c5 fc 11 9d 70 fe ff 	vmovups %ymm3,-0x190(%rbp)
 11f06af:	ff 
 11f06b0:	c5 fc 11 95 50 fe ff 	vmovups %ymm2,-0x1b0(%rbp)
 11f06b7:	ff 
 11f06b8:	c5 fc 11 8d 30 fe ff 	vmovups %ymm1,-0x1d0(%rbp)
 11f06bf:	ff 
 11f06c0:	c5 fc 11 85 10 fe ff 	vmovups %ymm0,-0x1f0(%rbp)
 11f06c7:	ff 
 11f06c8:	c4 c1 7c 10 46 70    	vmovups 0x70(%r14),%ymm0
 11f06ce:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 11f06d5:	ff 
 11f06d6:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 11f06db:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 11f06e1:	c4 c1 7c 10 56 40    	vmovups 0x40(%r14),%ymm2
 11f06e7:	c4 c1 7c 10 5e 60    	vmovups 0x60(%r14),%ymm3
 11f06ed:	4c 8b 75 30          	mov    0x30(%rbp),%r14
 11f06f1:	c5 fc 11 9d 00 ff ff 	vmovups %ymm3,-0x100(%rbp)
 11f06f8:	ff 
 11f06f9:	c5 fc 11 95 e0 fe ff 	vmovups %ymm2,-0x120(%rbp)
 11f0700:	ff 
 11f0701:	c5 fc 11 8d c0 fe ff 	vmovups %ymm1,-0x140(%rbp)
 11f0708:	ff 
 11f0709:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 11f0710:	ff 
 11f0711:	0f b6 85 f0 f5 ff ff 	movzbl -0xa10(%rbp),%eax
 11f0718:	41 80 7f 68 00       	cmpb   $0x0,0x68(%r15)
 11f071d:	0f 94 c1             	sete   %cl
 11f0720:	4d 85 f6             	test   %r14,%r14
 11f0723:	0f 94 c2             	sete   %dl
 11f0726:	84 d1                	test   %dl,%cl
 11f0728:	74 30                	je     11f075a <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x16a>
 11f072a:	c5 fc 10 43 10       	vmovups 0x10(%rbx),%ymm0
 11f072f:	c5 fc 10 4b 30       	vmovups 0x30(%rbx),%ymm1
 11f0734:	c5 fc 10 53 48       	vmovups 0x48(%rbx),%ymm2
 11f0739:	c5 fc 11 95 58 f8 ff 	vmovups %ymm2,-0x7a8(%rbp)
 11f0740:	ff 
 11f0741:	c5 fc 11 8d 40 f8 ff 	vmovups %ymm1,-0x7c0(%rbp)
 11f0748:	ff 
 11f0749:	c5 fc 11 85 20 f8 ff 	vmovups %ymm0,-0x7e0(%rbp)
 11f0750:	ff 
 11f0751:	48 8d 8d 20 f8 ff ff 	lea    -0x7e0(%rbp),%rcx
 11f0758:	eb 07                	jmp    11f0761 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x171>
 11f075a:	48 8d 0d cf 1b e2 ff 	lea    -0x1de431(%rip),%rcx        # 1012330 <__anon_35262>
 11f0761:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 11f0767:	c5 fc 10 09          	vmovups (%rcx),%ymm1
 11f076b:	c5 fc 10 51 20       	vmovups 0x20(%rcx),%ymm2
 11f0770:	c5 fc 10 59 38       	vmovups 0x38(%rcx),%ymm3
 11f0775:	c5 fc 11 85 c8 fa ff 	vmovups %ymm0,-0x538(%rbp)
 11f077c:	ff 
 11f077d:	41 80 e5 01          	and    $0x1,%r13b
 11f0781:	44 88 ad c9 fc ff ff 	mov    %r13b,-0x337(%rbp)
 11f0788:	48 c7 85 b8 fa ff ff 	movq   $0x0,-0x548(%rbp)
 11f078f:	00 00 00 00 
 11f0793:	24 01                	and    $0x1,%al
 11f0795:	88 85 cd fc ff ff    	mov    %al,-0x333(%rbp)
 11f079b:	c6 85 cc fc ff ff 00 	movb   $0x0,-0x334(%rbp)
 11f07a2:	c5 fc 11 8d e8 fa ff 	vmovups %ymm1,-0x518(%rbp)
 11f07a9:	ff 
 11f07aa:	c5 fc 11 95 08 fb ff 	vmovups %ymm2,-0x4f8(%rbp)
 11f07b1:	ff 
 11f07b2:	c5 fc 11 9d 20 fb ff 	vmovups %ymm3,-0x4e0(%rbp)
 11f07b9:	ff 
 11f07ba:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 11f07bf:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 11f07c5:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 11f07cb:	c4 c1 7c 10 5f 50    	vmovups 0x50(%r15),%ymm3
 11f07d1:	c5 fc 11 85 40 fb ff 	vmovups %ymm0,-0x4c0(%rbp)
 11f07d8:	ff 
 11f07d9:	c5 fc 11 8d 60 fb ff 	vmovups %ymm1,-0x4a0(%rbp)
 11f07e0:	ff 
 11f07e1:	c5 fc 11 95 80 fb ff 	vmovups %ymm2,-0x480(%rbp)
 11f07e8:	ff 
 11f07e9:	c5 fc 11 9d 90 fb ff 	vmovups %ymm3,-0x470(%rbp)
 11f07f0:	ff 
 11f07f1:	4c 89 b5 b0 fb ff ff 	mov    %r14,-0x450(%rbp)
 11f07f8:	48 8b 45 38          	mov    0x38(%rbp),%rax
 11f07fc:	48 89 85 b8 fb ff ff 	mov    %rax,-0x448(%rbp)
 11f0803:	48 8b 45 40          	mov    0x40(%rbp),%rax
 11f0807:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11f080b:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11f0810:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11f0815:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 11f081a:	c5 fc 11 85 c0 fb ff 	vmovups %ymm0,-0x440(%rbp)
 11f0821:	ff 
 11f0822:	c5 fc 11 8d e0 fb ff 	vmovups %ymm1,-0x420(%rbp)
 11f0829:	ff 
 11f082a:	c5 fc 11 95 00 fc ff 	vmovups %ymm2,-0x400(%rbp)
 11f0831:	ff 
 11f0832:	c5 fc 11 9d 10 fc ff 	vmovups %ymm3,-0x3f0(%rbp)
 11f0839:	ff 
 11f083a:	48 8b 45 48          	mov    0x48(%rbp),%rax
 11f083e:	48 89 85 30 fc ff ff 	mov    %rax,-0x3d0(%rbp)
 11f0845:	48 8b 45 50          	mov    0x50(%rbp),%rax
 11f0849:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11f084d:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11f0852:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11f0857:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 11f085c:	c5 fc 11 9d 88 fc ff 	vmovups %ymm3,-0x378(%rbp)
 11f0863:	ff 
 11f0864:	c5 fc 11 95 78 fc ff 	vmovups %ymm2,-0x388(%rbp)
 11f086b:	ff 
 11f086c:	c5 fc 11 8d 58 fc ff 	vmovups %ymm1,-0x3a8(%rbp)
 11f0873:	ff 
 11f0874:	c5 fc 11 85 38 fc ff 	vmovups %ymm0,-0x3c8(%rbp)
 11f087b:	ff 
 11f087c:	48 8b 45 58          	mov    0x58(%rbp),%rax
 11f0880:	48 89 85 a8 fc ff ff 	mov    %rax,-0x358(%rbp)
 11f0887:	c6 85 c0 fc ff ff 38 	movb   $0x38,-0x340(%rbp)
 11f088e:	c6 85 c8 fc ff ff 00 	movb   $0x0,-0x338(%rbp)
 11f0895:	0f b7 05 ac a6 e4 ff 	movzwl -0x1b5954(%rip),%eax        # 103af48 <__anon_35281>
 11f089c:	66 89 85 c2 fc ff ff 	mov    %ax,-0x33e(%rbp)
 11f08a3:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11f08a7:	24 1f                	and    $0x1f,%al
 11f08a9:	88 45 d7             	mov    %al,-0x29(%rbp)
 11f08ac:	88 85 c1 fc ff ff    	mov    %al,-0x33f(%rbp)
 11f08b2:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 11f08b6:	48 89 85 a8 fa ff ff 	mov    %rax,-0x558(%rbp)
 11f08bd:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11f08c1:	48 89 85 b0 fa ff ff 	mov    %rax,-0x550(%rbp)
 11f08c8:	c7 85 c4 fc ff ff 01 	movl   $0x1000101,-0x33c(%rbp)
 11f08cf:	01 00 01 
 11f08d2:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 11f08d6:	48 89 85 b8 fc ff ff 	mov    %rax,-0x348(%rbp)
 11f08dd:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11f08e1:	48 89 85 b0 fc ff ff 	mov    %rax,-0x350(%rbp)
 11f08e8:	66 c7 85 ca fc ff ff 	movw   $0x0,-0x336(%rbp)
 11f08ef:	00 00 
 11f08f1:	48 c7 85 c0 fa ff ff 	movq   $0x0,-0x540(%rbp)
 11f08f8:	00 00 00 00 
 11f08fc:	48 8d 85 a8 fa ff ff 	lea    -0x558(%rbp),%rax
 11f0903:	4c 8d 95 a0 fe ff ff 	lea    -0x160(%rbp),%r10
 11f090a:	48 8d bd 60 ff ff ff 	lea    -0xa0(%rbp),%rdi
 11f0911:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11f0915:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11f0919:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 11f091d:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 11f0921:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11f0925:	50                   	push   %rax
 11f0926:	41 52                	push   %r10
 11f0928:	c5 f8 77             	vzeroupper 
 11f092b:	e8 d0 40 f8 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 11f0930:	48 83 c4 10          	add    $0x10,%rsp
 11f0934:	0f b7 85 70 ff ff ff 	movzwl -0x90(%rbp),%eax
 11f093b:	66 85 c0             	test   %ax,%ax
 11f093e:	0f 85 96 06 00 00    	jne    11f0fda <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x9ea>
 11f0944:	4d 85 f6             	test   %r14,%r14
 11f0947:	0f 94 c0             	sete   %al
 11f094a:	4c 8b a5 60 ff ff ff 	mov    -0xa0(%rbp),%r12
 11f0951:	4c 8b ad 68 ff ff ff 	mov    -0x98(%rbp),%r13
 11f0958:	41 80 7f 68 00       	cmpb   $0x0,0x68(%r15)
 11f095d:	0f 94 c1             	sete   %cl
 11f0960:	84 c1                	test   %al,%cl
 11f0962:	0f 84 de 05 00 00    	je     11f0f46 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x956>
 11f0968:	0f b6 85 f1 f5 ff ff 	movzbl -0xa0f(%rbp),%eax
 11f096f:	48 83 e0 03          	and    $0x3,%rax
 11f0973:	0f 84 0d 03 00 00    	je     11f0c86 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x696>
 11f0979:	4c 8d b5 38 f6 ff ff 	lea    -0x9c8(%rbp),%r14
 11f0980:	c1 e0 04             	shl    $0x4,%eax
 11f0983:	48 8d 04 80          	lea    (%rax,%rax,4),%rax
 11f0987:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 11f098e:	31 db                	xor    %ebx,%ebx
 11f0990:	e9 95 00 00 00       	jmp    11f0a2a <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x43a>
 11f0995:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11f099c:	00 00 00 00 
 11f09a0:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f09a4:	48 8b 38             	mov    (%rax),%rdi
 11f09a7:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f09ab:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f09af:	4c 89 e1             	mov    %r12,%rcx
 11f09b2:	49 89 f4             	mov    %rsi,%r12
 11f09b5:	48 89 ce             	mov    %rcx,%rsi
 11f09b8:	4c 89 ea             	mov    %r13,%rdx
 11f09bb:	31 c9                	xor    %ecx,%ecx
 11f09bd:	ff 50 18             	call   *0x18(%rax)
 11f09c0:	4c 89 e0             	mov    %r12,%rax
 11f09c3:	c5 fc 10 85 d0 fd ff 	vmovups -0x230(%rbp),%ymm0
 11f09ca:	ff 
 11f09cb:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 11f09d2:	ff 
 11f09d3:	c5 fc 10 85 60 fd ff 	vmovups -0x2a0(%rbp),%ymm0
 11f09da:	ff 
 11f09db:	c5 fc 10 8d 80 fd ff 	vmovups -0x280(%rbp),%ymm1
 11f09e2:	ff 
 11f09e3:	c5 fc 10 95 a0 fd ff 	vmovups -0x260(%rbp),%ymm2
 11f09ea:	ff 
 11f09eb:	c5 fc 10 9d c0 fd ff 	vmovups -0x240(%rbp),%ymm3
 11f09f2:	ff 
 11f09f3:	c5 fc 11 9d 00 ff ff 	vmovups %ymm3,-0x100(%rbp)
 11f09fa:	ff 
 11f09fb:	c5 fc 11 95 e0 fe ff 	vmovups %ymm2,-0x120(%rbp)
 11f0a02:	ff 
 11f0a03:	c5 fc 11 8d c0 fe ff 	vmovups %ymm1,-0x140(%rbp)
 11f0a0a:	ff 
 11f0a0b:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 11f0a12:	ff 
 11f0a13:	48 83 c3 50          	add    $0x50,%rbx
 11f0a17:	4d 89 fd             	mov    %r15,%r13
 11f0a1a:	49 89 c4             	mov    %rax,%r12
 11f0a1d:	48 39 9d 78 ff ff ff 	cmp    %rbx,-0x88(%rbp)
 11f0a24:	0f 84 62 02 00 00    	je     11f0c8c <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x69c>
 11f0a2a:	48 8d 85 00 f5 ff ff 	lea    -0xb00(%rbp),%rax
 11f0a31:	c5 fc 10 04 18       	vmovups (%rax,%rbx,1),%ymm0
 11f0a36:	c5 fc 10 4c 18 20    	vmovups 0x20(%rax,%rbx,1),%ymm1
 11f0a3c:	c5 fc 10 54 18 30    	vmovups 0x30(%rax,%rbx,1),%ymm2
 11f0a42:	c4 c1 7c 11 56 30    	vmovups %ymm2,0x30(%r14)
 11f0a48:	c4 c1 7c 11 4e 20    	vmovups %ymm1,0x20(%r14)
 11f0a4e:	c4 c1 7c 11 06       	vmovups %ymm0,(%r14)
 11f0a53:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 11f0a57:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 11f0a5e:	ff 
 11f0a5f:	c4 c1 7c 11 46 e0    	vmovups %ymm0,-0x20(%r14)
 11f0a65:	88 85 19 f8 ff ff    	mov    %al,-0x7e7(%rbp)
 11f0a6b:	0f b6 85 f0 f5 ff ff 	movzbl -0xa10(%rbp),%eax
 11f0a72:	48 c7 85 08 f6 ff ff 	movq   $0x0,-0x9f8(%rbp)
 11f0a79:	00 00 00 00 
 11f0a7d:	88 85 1d f8 ff ff    	mov    %al,-0x7e3(%rbp)
 11f0a83:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 11f0a8a:	ff 
 11f0a8b:	c5 fc 11 85 d0 fd ff 	vmovups %ymm0,-0x230(%rbp)
 11f0a92:	ff 
 11f0a93:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 11f0a9a:	ff 
 11f0a9b:	c5 fc 10 8d 30 fe ff 	vmovups -0x1d0(%rbp),%ymm1
 11f0aa2:	ff 
 11f0aa3:	c5 fc 10 95 50 fe ff 	vmovups -0x1b0(%rbp),%ymm2
 11f0aaa:	ff 
 11f0aab:	c5 fc 10 9d 70 fe ff 	vmovups -0x190(%rbp),%ymm3
 11f0ab2:	ff 
 11f0ab3:	c5 fc 11 9d c0 fd ff 	vmovups %ymm3,-0x240(%rbp)
 11f0aba:	ff 
 11f0abb:	c5 fc 11 95 a0 fd ff 	vmovups %ymm2,-0x260(%rbp)
 11f0ac2:	ff 
 11f0ac3:	c5 fc 11 8d 80 fd ff 	vmovups %ymm1,-0x280(%rbp)
 11f0aca:	ff 
 11f0acb:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 11f0ad2:	ff 
 11f0ad3:	c6 85 1c f8 ff ff 00 	movb   $0x0,-0x7e4(%rbp)
 11f0ada:	c6 85 88 f6 ff ff 01 	movb   $0x1,-0x978(%rbp)
 11f0ae1:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11f0ae5:	c4 c1 7c 11 86 b8 00 	vmovups %ymm0,0xb8(%r14)
 11f0aec:	00 00 
 11f0aee:	c4 c1 7c 11 86 98 00 	vmovups %ymm0,0x98(%r14)
 11f0af5:	00 00 
 11f0af7:	c4 c1 7c 11 46 78    	vmovups %ymm0,0x78(%r14)
 11f0afd:	c4 c1 7c 11 46 58    	vmovups %ymm0,0x58(%r14)
 11f0b03:	48 8b 45 40          	mov    0x40(%rbp),%rax
 11f0b07:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11f0b0b:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11f0b10:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11f0b15:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 11f0b1a:	c4 c1 7c 11 9e 28 01 	vmovups %ymm3,0x128(%r14)
 11f0b21:	00 00 
 11f0b23:	c4 c1 7c 11 96 18 01 	vmovups %ymm2,0x118(%r14)
 11f0b2a:	00 00 
 11f0b2c:	c4 c1 7c 11 8e f8 00 	vmovups %ymm1,0xf8(%r14)
 11f0b33:	00 00 
 11f0b35:	c4 c1 7c 11 86 d8 00 	vmovups %ymm0,0xd8(%r14)
 11f0b3c:	00 00 
 11f0b3e:	48 8b 45 48          	mov    0x48(%rbp),%rax
 11f0b42:	48 89 85 80 f7 ff ff 	mov    %rax,-0x880(%rbp)
 11f0b49:	48 8b 45 50          	mov    0x50(%rbp),%rax
 11f0b4d:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11f0b51:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11f0b56:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11f0b5b:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 11f0b60:	c4 c1 7c 11 9e a0 01 	vmovups %ymm3,0x1a0(%r14)
 11f0b67:	00 00 
 11f0b69:	c4 c1 7c 11 96 90 01 	vmovups %ymm2,0x190(%r14)
 11f0b70:	00 00 
 11f0b72:	c4 c1 7c 11 8e 70 01 	vmovups %ymm1,0x170(%r14)
 11f0b79:	00 00 
 11f0b7b:	c4 c1 7c 11 86 50 01 	vmovups %ymm0,0x150(%r14)
 11f0b82:	00 00 
 11f0b84:	48 8b 45 58          	mov    0x58(%rbp),%rax
 11f0b88:	48 89 85 f8 f7 ff ff 	mov    %rax,-0x808(%rbp)
 11f0b8f:	c6 85 10 f8 ff ff 38 	movb   $0x38,-0x7f0(%rbp)
 11f0b96:	c6 85 18 f8 ff ff 00 	movb   $0x0,-0x7e8(%rbp)
 11f0b9d:	0f b7 05 a4 a3 e4 ff 	movzwl -0x1b5c5c(%rip),%eax        # 103af48 <__anon_35281>
 11f0ba4:	66 89 85 12 f8 ff ff 	mov    %ax,-0x7ee(%rbp)
 11f0bab:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11f0baf:	88 85 11 f8 ff ff    	mov    %al,-0x7ef(%rbp)
 11f0bb5:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 11f0bb9:	48 89 85 f8 f5 ff ff 	mov    %rax,-0xa08(%rbp)
 11f0bc0:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11f0bc4:	48 89 85 00 f6 ff ff 	mov    %rax,-0xa00(%rbp)
 11f0bcb:	c7 85 14 f8 ff ff 01 	movl   $0x1000101,-0x7ec(%rbp)
 11f0bd2:	01 00 01 
 11f0bd5:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 11f0bd9:	48 89 85 08 f8 ff ff 	mov    %rax,-0x7f8(%rbp)
 11f0be0:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11f0be4:	48 89 85 00 f8 ff ff 	mov    %rax,-0x800(%rbp)
 11f0beb:	66 c7 85 1a f8 ff ff 	movw   $0x0,-0x7e6(%rbp)
 11f0bf2:	00 00 
 11f0bf4:	48 c7 85 10 f6 ff ff 	movq   $0x0,-0x9f0(%rbp)
 11f0bfb:	00 00 00 00 
 11f0bff:	48 8d bd 48 ff ff ff 	lea    -0xb8(%rbp),%rdi
 11f0c06:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11f0c0a:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11f0c0e:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 11f0c12:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 11f0c16:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11f0c1a:	48 8d 85 f8 f5 ff ff 	lea    -0xa08(%rbp),%rax
 11f0c21:	50                   	push   %rax
 11f0c22:	48 8d 85 60 fd ff ff 	lea    -0x2a0(%rbp),%rax
 11f0c29:	50                   	push   %rax
 11f0c2a:	c5 f8 77             	vzeroupper 
 11f0c2d:	e8 ce 3d f8 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 11f0c32:	48 83 c4 10          	add    $0x10,%rsp
 11f0c36:	44 0f b7 bd 58 ff ff 	movzwl -0xa8(%rbp),%r15d
 11f0c3d:	ff 
 11f0c3e:	66 45 85 ff          	test   %r15w,%r15w
 11f0c42:	0f 85 68 03 00 00    	jne    11f0fb0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x9c0>
 11f0c48:	48 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%rsi
 11f0c4f:	4c 8b bd 50 ff ff ff 	mov    -0xb0(%rbp),%r15
 11f0c56:	4d 39 ef             	cmp    %r13,%r15
 11f0c59:	0f 82 41 fd ff ff    	jb     11f09a0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x3b0>
 11f0c5f:	4d 85 ff             	test   %r15,%r15
 11f0c62:	74 17                	je     11f0c7b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x68b>
 11f0c64:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f0c68:	48 8b 38             	mov    (%rax),%rdi
 11f0c6b:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f0c6f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f0c73:	4c 89 fa             	mov    %r15,%rdx
 11f0c76:	31 c9                	xor    %ecx,%ecx
 11f0c78:	ff 50 18             	call   *0x18(%rax)
 11f0c7b:	4c 89 e0             	mov    %r12,%rax
 11f0c7e:	4d 89 ef             	mov    %r13,%r15
 11f0c81:	e9 8d fd ff ff       	jmp    11f0a13 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x423>
 11f0c86:	4c 89 e0             	mov    %r12,%rax
 11f0c89:	4d 89 ef             	mov    %r13,%r15
 11f0c8c:	80 bd f2 f5 ff ff 00 	cmpb   $0x0,-0xa0e(%rbp)
 11f0c93:	0f 84 83 02 00 00    	je     11f0f1c <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x92c>
 11f0c99:	49 89 c6             	mov    %rax,%r14
 11f0c9c:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 11f0ca3:	ff 
 11f0ca4:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 11f0cab:	ff 
 11f0cac:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 11f0cb3:	ff 
 11f0cb4:	c5 fc 10 8d 30 fe ff 	vmovups -0x1d0(%rbp),%ymm1
 11f0cbb:	ff 
 11f0cbc:	c5 fc 10 95 50 fe ff 	vmovups -0x1b0(%rbp),%ymm2
 11f0cc3:	ff 
 11f0cc4:	c5 fc 10 9d 70 fe ff 	vmovups -0x190(%rbp),%ymm3
 11f0ccb:	ff 
 11f0ccc:	c5 fc 11 9d 30 fd ff 	vmovups %ymm3,-0x2d0(%rbp)
 11f0cd3:	ff 
 11f0cd4:	c5 fc 11 95 10 fd ff 	vmovups %ymm2,-0x2f0(%rbp)
 11f0cdb:	ff 
 11f0cdc:	c5 fc 11 8d f0 fc ff 	vmovups %ymm1,-0x310(%rbp)
 11f0ce3:	ff 
 11f0ce4:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 11f0ceb:	ff 
 11f0cec:	0f b6 85 f0 f5 ff ff 	movzbl -0xa10(%rbp),%eax
 11f0cf3:	0f b6 4d d0          	movzbl -0x30(%rbp),%ecx
 11f0cf7:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 11f0cfe:	ff 
 11f0cff:	c5 fc 11 85 a0 f8 ff 	vmovups %ymm0,-0x760(%rbp)
 11f0d06:	ff 
 11f0d07:	88 8d a1 fa ff ff    	mov    %cl,-0x55f(%rbp)
 11f0d0d:	48 c7 85 90 f8 ff ff 	movq   $0x0,-0x770(%rbp)
 11f0d14:	00 00 00 00 
 11f0d18:	88 85 a5 fa ff ff    	mov    %al,-0x55b(%rbp)
 11f0d1e:	c6 85 a4 fa ff ff 00 	movb   $0x0,-0x55c(%rbp)
 11f0d25:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11f0d29:	c5 fc 11 85 c0 f8 ff 	vmovups %ymm0,-0x740(%rbp)
 11f0d30:	ff 
 11f0d31:	c5 fc 11 85 e0 f8 ff 	vmovups %ymm0,-0x720(%rbp)
 11f0d38:	ff 
 11f0d39:	c5 fc 11 85 00 f9 ff 	vmovups %ymm0,-0x700(%rbp)
 11f0d40:	ff 
 11f0d41:	c5 fc 11 85 20 f9 ff 	vmovups %ymm0,-0x6e0(%rbp)
 11f0d48:	ff 
 11f0d49:	c5 fc 11 85 40 f9 ff 	vmovups %ymm0,-0x6c0(%rbp)
 11f0d50:	ff 
 11f0d51:	c5 fc 11 85 60 f9 ff 	vmovups %ymm0,-0x6a0(%rbp)
 11f0d58:	ff 
 11f0d59:	c5 fc 11 85 78 f9 ff 	vmovups %ymm0,-0x688(%rbp)
 11f0d60:	ff 
 11f0d61:	48 8b 45 40          	mov    0x40(%rbp),%rax
 11f0d65:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11f0d69:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11f0d6e:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11f0d73:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 11f0d78:	c5 fc 11 85 98 f9 ff 	vmovups %ymm0,-0x668(%rbp)
 11f0d7f:	ff 
 11f0d80:	c5 fc 11 8d b8 f9 ff 	vmovups %ymm1,-0x648(%rbp)
 11f0d87:	ff 
 11f0d88:	c5 fc 11 95 d8 f9 ff 	vmovups %ymm2,-0x628(%rbp)
 11f0d8f:	ff 
 11f0d90:	c5 fc 11 9d e8 f9 ff 	vmovups %ymm3,-0x618(%rbp)
 11f0d97:	ff 
 11f0d98:	48 8b 45 48          	mov    0x48(%rbp),%rax
 11f0d9c:	48 89 85 08 fa ff ff 	mov    %rax,-0x5f8(%rbp)
 11f0da3:	48 8b 45 50          	mov    0x50(%rbp),%rax
 11f0da7:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11f0dab:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11f0db0:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11f0db5:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 11f0dba:	c5 fc 11 85 10 fa ff 	vmovups %ymm0,-0x5f0(%rbp)
 11f0dc1:	ff 
 11f0dc2:	c5 fc 11 8d 30 fa ff 	vmovups %ymm1,-0x5d0(%rbp)
 11f0dc9:	ff 
 11f0dca:	c5 fc 11 95 50 fa ff 	vmovups %ymm2,-0x5b0(%rbp)
 11f0dd1:	ff 
 11f0dd2:	c5 fc 11 9d 60 fa ff 	vmovups %ymm3,-0x5a0(%rbp)
 11f0dd9:	ff 
 11f0dda:	48 8b 45 58          	mov    0x58(%rbp),%rax
 11f0dde:	48 89 85 80 fa ff ff 	mov    %rax,-0x580(%rbp)
 11f0de5:	c6 85 98 fa ff ff 38 	movb   $0x38,-0x568(%rbp)
 11f0dec:	c6 85 a0 fa ff ff 00 	movb   $0x0,-0x560(%rbp)
 11f0df3:	0f b7 05 4e a1 e4 ff 	movzwl -0x1b5eb2(%rip),%eax        # 103af48 <__anon_35281>
 11f0dfa:	66 89 85 9a fa ff ff 	mov    %ax,-0x566(%rbp)
 11f0e01:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11f0e05:	88 85 99 fa ff ff    	mov    %al,-0x567(%rbp)
 11f0e0b:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 11f0e0f:	48 89 85 80 f8 ff ff 	mov    %rax,-0x780(%rbp)
 11f0e16:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11f0e1a:	48 89 85 88 f8 ff ff 	mov    %rax,-0x778(%rbp)
 11f0e21:	c7 85 9c fa ff ff 01 	movl   $0x1000101,-0x564(%rbp)
 11f0e28:	01 00 01 
 11f0e2b:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 11f0e2f:	48 89 85 90 fa ff ff 	mov    %rax,-0x570(%rbp)
 11f0e36:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11f0e3a:	48 89 85 88 fa ff ff 	mov    %rax,-0x578(%rbp)
 11f0e41:	66 c7 85 a2 fa ff ff 	movw   $0x0,-0x55e(%rbp)
 11f0e48:	00 00 
 11f0e4a:	48 c7 85 98 f8 ff ff 	movq   $0x0,-0x768(%rbp)
 11f0e51:	00 00 00 00 
 11f0e55:	48 8d 85 80 f8 ff ff 	lea    -0x780(%rbp),%rax
 11f0e5c:	4c 8d 95 d0 fc ff ff 	lea    -0x330(%rbp),%r10
 11f0e63:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 11f0e6a:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11f0e6e:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11f0e72:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 11f0e76:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 11f0e7a:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11f0e7e:	50                   	push   %rax
 11f0e7f:	41 52                	push   %r10
 11f0e81:	c5 f8 77             	vzeroupper 
 11f0e84:	e8 77 3b f8 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 11f0e89:	48 83 c4 10          	add    $0x10,%rsp
 11f0e8d:	0f b7 9d 40 ff ff ff 	movzwl -0xc0(%rbp),%ebx
 11f0e94:	66 85 db             	test   %bx,%bx
 11f0e97:	0f 85 47 01 00 00    	jne    11f0fe4 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x9f4>
 11f0e9d:	4c 8b a5 30 ff ff ff 	mov    -0xd0(%rbp),%r12
 11f0ea4:	4c 8b ad 38 ff ff ff 	mov    -0xc8(%rbp),%r13
 11f0eab:	4d 39 fd             	cmp    %r15,%r13
 11f0eae:	73 71                	jae    11f0f21 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x931>
 11f0eb0:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f0eb4:	48 8b 38             	mov    (%rax),%rdi
 11f0eb7:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f0ebb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f0ebf:	4c 89 f6             	mov    %r14,%rsi
 11f0ec2:	4c 89 fa             	mov    %r15,%rdx
 11f0ec5:	31 c9                	xor    %ecx,%ecx
 11f0ec7:	ff 50 18             	call   *0x18(%rax)
 11f0eca:	c5 fc 10 85 40 fd ff 	vmovups -0x2c0(%rbp),%ymm0
 11f0ed1:	ff 
 11f0ed2:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 11f0ed9:	ff 
 11f0eda:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 11f0ee1:	ff 
 11f0ee2:	c5 fc 10 8d f0 fc ff 	vmovups -0x310(%rbp),%ymm1
 11f0ee9:	ff 
 11f0eea:	c5 fc 10 95 10 fd ff 	vmovups -0x2f0(%rbp),%ymm2
 11f0ef1:	ff 
 11f0ef2:	c5 fc 10 9d 30 fd ff 	vmovups -0x2d0(%rbp),%ymm3
 11f0ef9:	ff 
 11f0efa:	c5 fc 11 9d 00 ff ff 	vmovups %ymm3,-0x100(%rbp)
 11f0f01:	ff 
 11f0f02:	c5 fc 11 95 e0 fe ff 	vmovups %ymm2,-0x120(%rbp)
 11f0f09:	ff 
 11f0f0a:	c5 fc 11 8d c0 fe ff 	vmovups %ymm1,-0x140(%rbp)
 11f0f11:	ff 
 11f0f12:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 11f0f19:	ff 
 11f0f1a:	eb 2a                	jmp    11f0f46 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x956>
 11f0f1c:	49 89 c4             	mov    %rax,%r12
 11f0f1f:	eb 22                	jmp    11f0f43 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x953>
 11f0f21:	4d 85 ed             	test   %r13,%r13
 11f0f24:	74 1a                	je     11f0f40 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x950>
 11f0f26:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f0f2a:	48 8b 38             	mov    (%rax),%rdi
 11f0f2d:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f0f31:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f0f35:	4c 89 e6             	mov    %r12,%rsi
 11f0f38:	4c 89 ea             	mov    %r13,%rdx
 11f0f3b:	31 c9                	xor    %ecx,%ecx
 11f0f3d:	ff 50 18             	call   *0x18(%rax)
 11f0f40:	4d 89 f4             	mov    %r14,%r12
 11f0f43:	4d 89 fd             	mov    %r15,%r13
 11f0f46:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11f0f4a:	c5 fc 10 85 10 ff ff 	vmovups -0xf0(%rbp),%ymm0
 11f0f51:	ff 
 11f0f52:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11f0f57:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 11f0f5e:	ff 
 11f0f5f:	c5 fc 10 8d c0 fe ff 	vmovups -0x140(%rbp),%ymm1
 11f0f66:	ff 
 11f0f67:	c5 fc 10 95 e0 fe ff 	vmovups -0x120(%rbp),%ymm2
 11f0f6e:	ff 
 11f0f6f:	c5 fc 10 9d 00 ff ff 	vmovups -0x100(%rbp),%ymm3
 11f0f76:	ff 
 11f0f77:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11f0f7c:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11f0f81:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11f0f86:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11f0f8a:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11f0f8e:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 11f0f94:	4c 89 20             	mov    %r12,(%rax)
 11f0f97:	4c 89 68 08          	mov    %r13,0x8(%rax)
 11f0f9b:	48 81 c4 48 0b 00 00 	add    $0xb48,%rsp
 11f0fa2:	5b                   	pop    %rbx
 11f0fa3:	41 5c                	pop    %r12
 11f0fa5:	41 5d                	pop    %r13
 11f0fa7:	41 5e                	pop    %r14
 11f0fa9:	41 5f                	pop    %r15
 11f0fab:	5d                   	pop    %rbp
 11f0fac:	c5 f8 77             	vzeroupper 
 11f0faf:	c3                   	ret    
 11f0fb0:	4d 85 ed             	test   %r13,%r13
 11f0fb3:	74 1a                	je     11f0fcf <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x9df>
 11f0fb5:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f0fb9:	48 8b 38             	mov    (%rax),%rdi
 11f0fbc:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f0fc0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f0fc4:	4c 89 e6             	mov    %r12,%rsi
 11f0fc7:	4c 89 ea             	mov    %r13,%rdx
 11f0fca:	31 c9                	xor    %ecx,%ecx
 11f0fcc:	ff 50 18             	call   *0x18(%rax)
 11f0fcf:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11f0fd3:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 11f0fd8:	eb c1                	jmp    11f0f9b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x9ab>
 11f0fda:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 11f0fde:	66 89 41 10          	mov    %ax,0x10(%rcx)
 11f0fe2:	eb b7                	jmp    11f0f9b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x9ab>
 11f0fe4:	4d 85 ff             	test   %r15,%r15
 11f0fe7:	74 1a                	je     11f1003 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0xa13>
 11f0fe9:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f0fed:	48 8b 38             	mov    (%rax),%rdi
 11f0ff0:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f0ff4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f0ff8:	4c 89 f6             	mov    %r14,%rsi
 11f0ffb:	4c 89 fa             	mov    %r15,%rdx
 11f0ffe:	31 c9                	xor    %ecx,%ecx
 11f1000:	ff 50 18             	call   *0x18(%rax)
 11f1003:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11f1007:	66 89 58 10          	mov    %bx,0x10(%rax)
 11f100b:	eb 8e                	jmp    11f0f9b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678+0x9ab>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
