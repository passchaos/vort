
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000129a820 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831>:
 129a820:	55                   	push   %rbp
 129a821:	48 89 e5             	mov    %rsp,%rbp
 129a824:	41 57                	push   %r15
 129a826:	41 56                	push   %r14
 129a828:	41 55                	push   %r13
 129a82a:	41 54                	push   %r12
 129a82c:	53                   	push   %rbx
 129a82d:	48 81 ec 28 0c 00 00 	sub    $0xc28,%rsp
 129a834:	4d 89 c7             	mov    %r8,%r15
 129a837:	48 89 4d 88          	mov    %rcx,-0x78(%rbp)
 129a83b:	49 89 d5             	mov    %rdx,%r13
 129a83e:	49 89 f6             	mov    %rsi,%r14
 129a841:	48 89 fb             	mov    %rdi,%rbx
 129a844:	49 8b 40 58          	mov    0x58(%r8),%rax
 129a848:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 129a84f:	49 8b 40 60          	mov    0x60(%r8),%rax
 129a853:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 129a85a:	41 0f b7 80 80 00 00 	movzwl 0x80(%r8),%eax
 129a861:	00 
 129a862:	89 85 b8 fe ff ff    	mov    %eax,-0x148(%rbp)
 129a868:	41 0f b6 80 85 00 00 	movzbl 0x85(%r8),%eax
 129a86f:	00 
 129a870:	88 85 28 ff ff ff    	mov    %al,-0xd8(%rbp)
 129a876:	88 45 ce             	mov    %al,-0x32(%rbp)
 129a879:	4d 8b a0 86 00 00 00 	mov    0x86(%r8),%r12
 129a880:	41 0f b6 80 8e 00 00 	movzbl 0x8e(%r8),%eax
 129a887:	00 
 129a888:	88 45 80             	mov    %al,-0x80(%rbp)
 129a88b:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 129a892:	4c 89 c6             	mov    %r8,%rsi
 129a895:	e8 26 c1 fd ff       	call   12769c0 <br.resolvedQualitySchedule>
 129a89a:	0f b7 85 f4 fe ff ff 	movzwl -0x10c(%rbp),%eax
 129a8a1:	66 85 c0             	test   %ax,%ax
 129a8a4:	0f 85 42 15 00 00    	jne    129bdec <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x15cc>
 129a8aa:	4c 89 75 d0          	mov    %r14,-0x30(%rbp)
 129a8ae:	48 89 5d 98          	mov    %rbx,-0x68(%rbp)
 129a8b2:	4c 89 e3             	mov    %r12,%rbx
 129a8b5:	48 c1 eb 08          	shr    $0x8,%rbx
 129a8b9:	4c 89 a5 60 fe ff ff 	mov    %r12,-0x1a0(%rbp)
 129a8c0:	41 c1 ec 10          	shr    $0x10,%r12d
 129a8c4:	8b 85 c4 fe ff ff    	mov    -0x13c(%rbp),%eax
 129a8ca:	48 89 85 68 fe ff ff 	mov    %rax,-0x198(%rbp)
 129a8d1:	8b 85 c8 fe ff ff    	mov    -0x138(%rbp),%eax
 129a8d7:	c5 fb 10 85 c0 fe ff 	vmovsd -0x140(%rbp),%xmm0
 129a8de:	ff 
 129a8df:	c5 f8 29 85 50 fc ff 	vmovaps %xmm0,-0x3b0(%rbp)
 129a8e6:	ff 
 129a8e7:	89 85 10 ff ff ff    	mov    %eax,-0xf0(%rbp)
 129a8ed:	0f b7 85 cc fe ff ff 	movzwl -0x134(%rbp),%eax
 129a8f4:	66 89 85 14 ff ff ff 	mov    %ax,-0xec(%rbp)
 129a8fb:	0f b6 b5 ce fe ff ff 	movzbl -0x132(%rbp),%esi
 129a902:	0f b6 85 cf fe ff ff 	movzbl -0x131(%rbp),%eax
 129a909:	88 45 82             	mov    %al,-0x7e(%rbp)
 129a90c:	0f b7 85 d4 fe ff ff 	movzwl -0x12c(%rbp),%eax
 129a913:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 129a917:	0f b7 85 d6 fe ff ff 	movzwl -0x12a(%rbp),%eax
 129a91e:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 129a922:	0f b6 85 dc fe ff ff 	movzbl -0x124(%rbp),%eax
 129a929:	0f b6 8d dd fe ff ff 	movzbl -0x123(%rbp),%ecx
 129a930:	44 0f b6 b5 de fe ff 	movzbl -0x122(%rbp),%r14d
 129a937:	ff 
 129a938:	0f b6 95 df fe ff ff 	movzbl -0x121(%rbp),%edx
 129a93f:	88 55 cf             	mov    %dl,-0x31(%rbp)
 129a942:	0f b6 95 e0 fe ff ff 	movzbl -0x120(%rbp),%edx
 129a949:	88 95 18 ff ff ff    	mov    %dl,-0xe8(%rbp)
 129a94f:	0f b6 95 e6 fe ff ff 	movzbl -0x11a(%rbp),%edx
 129a956:	88 95 f8 fe ff ff    	mov    %dl,-0x108(%rbp)
 129a95c:	0f b6 95 e7 fe ff ff 	movzbl -0x119(%rbp),%edx
 129a963:	88 95 7c ff ff ff    	mov    %dl,-0x84(%rbp)
 129a969:	0f b6 95 e8 fe ff ff 	movzbl -0x118(%rbp),%edx
 129a970:	88 95 7d ff ff ff    	mov    %dl,-0x83(%rbp)
 129a976:	0f b6 95 e9 fe ff ff 	movzbl -0x117(%rbp),%edx
 129a97d:	88 95 7a ff ff ff    	mov    %dl,-0x86(%rbp)
 129a983:	0f b6 95 ea fe ff ff 	movzbl -0x116(%rbp),%edx
 129a98a:	88 95 79 ff ff ff    	mov    %dl,-0x87(%rbp)
 129a990:	0f b6 95 eb fe ff ff 	movzbl -0x115(%rbp),%edx
 129a997:	88 95 78 ff ff ff    	mov    %dl,-0x88(%rbp)
 129a99d:	0f b6 95 ec fe ff ff 	movzbl -0x114(%rbp),%edx
 129a9a4:	88 95 7f ff ff ff    	mov    %dl,-0x81(%rbp)
 129a9aa:	0f b6 95 ed fe ff ff 	movzbl -0x113(%rbp),%edx
 129a9b1:	88 95 7e ff ff ff    	mov    %dl,-0x82(%rbp)
 129a9b7:	0f b6 95 ee fe ff ff 	movzbl -0x112(%rbp),%edx
 129a9be:	88 95 7b ff ff ff    	mov    %dl,-0x85(%rbp)
 129a9c4:	88 45 84             	mov    %al,-0x7c(%rbp)
 129a9c7:	0f b6 85 ef fe ff ff 	movzbl -0x111(%rbp),%eax
 129a9ce:	88 8d 76 ff ff ff    	mov    %cl,-0x8a(%rbp)
 129a9d4:	0f b6 8d f0 fe ff ff 	movzbl -0x110(%rbp),%ecx
 129a9db:	88 4d 81             	mov    %cl,-0x7f(%rbp)
 129a9de:	40 88 75 ac          	mov    %sil,-0x54(%rbp)
 129a9e2:	40 88 75 ae          	mov    %sil,-0x52(%rbp)
 129a9e6:	88 45 ab             	mov    %al,-0x55(%rbp)
 129a9e9:	88 85 77 ff ff ff    	mov    %al,-0x89(%rbp)
 129a9ef:	41 80 bf 84 00 00 00 	cmpb   $0x0,0x84(%r15)
 129a9f6:	00 
 129a9f7:	0f b6 85 d8 fe ff ff 	movzbl -0x128(%rbp),%eax
 129a9fe:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 129aa05:	0f b7 85 da fe ff ff 	movzwl -0x126(%rbp),%eax
 129aa0c:	89 85 bc fe ff ff    	mov    %eax,-0x144(%rbp)
 129aa12:	74 4f                	je     129aa63 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x243>
 129aa14:	48 8d bd 70 fe ff ff 	lea    -0x190(%rbp),%rdi
 129aa1b:	4c 89 fe             	mov    %r15,%rsi
 129aa1e:	e8 9d bf fd ff       	call   12769c0 <br.resolvedQualitySchedule>
 129aa23:	0f b7 85 a4 fe ff ff 	movzwl -0x15c(%rbp),%eax
 129aa2a:	66 85 c0             	test   %ax,%ax
 129aa2d:	0f 85 3a 03 00 00    	jne    129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129aa33:	0f b6 85 93 fe ff ff 	movzbl -0x16d(%rbp),%eax
 129aa3a:	f6 85 28 ff ff ff 01 	testb  $0x1,-0xd8(%rbp)
 129aa41:	74 5d                	je     129aaa0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x280>
 129aa43:	45 84 e4             	test   %r12b,%r12b
 129aa46:	0f b6 c0             	movzbl %al,%eax
 129aa49:	0f b6 f3             	movzbl %bl,%esi
 129aa4c:	0f 44 f0             	cmove  %eax,%esi
 129aa4f:	8d 4e 01             	lea    0x1(%rsi),%ecx
 129aa52:	80 e1 1f             	and    $0x1f,%cl
 129aa55:	66 b8 52 00          	mov    $0x52,%ax
 129aa59:	80 f9 0b             	cmp    $0xb,%cl
 129aa5c:	73 7a                	jae    129aad8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x2b8>
 129aa5e:	e9 0a 03 00 00       	jmp    129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129aa63:	45 84 e4             	test   %r12b,%r12b
 129aa66:	be 10 00 00 00       	mov    $0x10,%esi
 129aa6b:	0f 45 f3             	cmovne %ebx,%esi
 129aa6e:	89 f1                	mov    %esi,%ecx
 129aa70:	80 e1 1f             	and    $0x1f,%cl
 129aa73:	f6 85 28 ff ff ff 01 	testb  $0x1,-0xd8(%rbp)
 129aa7a:	b8 fe 00 00 00       	mov    $0xfe,%eax
 129aa7f:	ba f8 00 00 00       	mov    $0xf8,%edx
 129aa84:	0f 45 d0             	cmovne %eax,%edx
 129aa87:	66 b8 52 00          	mov    $0x52,%ax
 129aa8b:	80 f9 0a             	cmp    $0xa,%cl
 129aa8e:	0f 82 d9 02 00 00    	jb     129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129aa94:	80 e2 1f             	and    $0x1f,%dl
 129aa97:	38 d1                	cmp    %dl,%cl
 129aa99:	76 3d                	jbe    129aad8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x2b8>
 129aa9b:	e9 cd 02 00 00       	jmp    129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129aaa0:	0f b7 8d 94 fe ff ff 	movzwl -0x16c(%rbp),%ecx
 129aaa7:	45 84 e4             	test   %r12b,%r12b
 129aaaa:	0f b6 c0             	movzbl %al,%eax
 129aaad:	0f b6 f3             	movzbl %bl,%esi
 129aab0:	0f 44 f0             	cmove  %eax,%esi
 129aab3:	40 80 e6 1f          	and    $0x1f,%sil
 129aab7:	89 ca                	mov    %ecx,%edx
 129aab9:	80 e2 1f             	and    $0x1f,%dl
 129aabc:	66 b8 52 00          	mov    $0x52,%ax
 129aac0:	40 38 d6             	cmp    %dl,%sil
 129aac3:	0f 82 a4 02 00 00    	jb     129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129aac9:	c1 e9 08             	shr    $0x8,%ecx
 129aacc:	80 e1 1f             	and    $0x1f,%cl
 129aacf:	40 38 ce             	cmp    %cl,%sil
 129aad2:	0f 87 95 02 00 00    	ja     129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129aad8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129aadc:	c5 f8 29 85 d0 fd ff 	vmovaps %xmm0,-0x230(%rbp)
 129aae3:	ff 
 129aae4:	48 c7 85 e0 fd ff ff 	movq   $0x0,-0x220(%rbp)
 129aaeb:	00 00 00 00 
 129aaef:	0f b6 85 28 ff ff ff 	movzbl -0xd8(%rbp),%eax
 129aaf6:	24 01                	and    $0x1,%al
 129aaf8:	88 45 83             	mov    %al,-0x7d(%rbp)
 129aafb:	88 85 f8 fd ff ff    	mov    %al,-0x208(%rbp)
 129ab01:	48 89 b5 08 ff ff ff 	mov    %rsi,-0xf8(%rbp)
 129ab08:	40 80 e6 1f          	and    $0x1f,%sil
 129ab0c:	48 89 b5 20 ff ff ff 	mov    %rsi,-0xe0(%rbp)
 129ab13:	40 88 b5 f9 fd ff ff 	mov    %sil,-0x207(%rbp)
 129ab1a:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 129ab21:	48 89 85 e8 fd ff ff 	mov    %rax,-0x218(%rbp)
 129ab28:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 129ab2f:	48 89 85 f0 fd ff ff 	mov    %rax,-0x210(%rbp)
 129ab36:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129ab3a:	48 83 f9 04          	cmp    $0x4,%rcx
 129ab3e:	4c 8b 65 d0          	mov    -0x30(%rbp),%r12
 129ab42:	77 44                	ja     129ab88 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x368>
 129ab44:	48 8d bd 70 fe ff ff 	lea    -0x190(%rbp),%rdi
 129ab4b:	4c 8d 85 d0 fd ff ff 	lea    -0x230(%rbp),%r8
 129ab52:	4c 89 e6             	mov    %r12,%rsi
 129ab55:	4c 89 ea             	mov    %r13,%rdx
 129ab58:	e8 73 32 f9 ff       	call   122ddd0 <br.encodeStoredStreamWithOptionsAlloc>
 129ab5d:	0f b7 85 80 fe ff ff 	movzwl -0x180(%rbp),%eax
 129ab64:	66 85 c0             	test   %ax,%ax
 129ab67:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 129ab6b:	0f 85 00 02 00 00    	jne    129ad71 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x551>
 129ab71:	c5 f8 10 85 70 fe ff 	vmovups -0x190(%rbp),%xmm0
 129ab78:	ff 
 129ab79:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 129ab7d:	66 c7 41 10 00 00    	movw   $0x0,0x10(%rcx)
 129ab83:	e9 ab 10 00 00       	jmp    129bc33 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1413>
 129ab88:	41 80 e6 0f          	and    $0xf,%r14b
 129ab8c:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 129ab93:	00 
 129ab94:	b8 00 00 00 00       	mov    $0x0,%eax
 129ab99:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 129ab9d:	44 88 75 ad          	mov    %r14b,-0x53(%rbp)
 129aba1:	41 80 fe 0b          	cmp    $0xb,%r14b
 129aba5:	0f 85 af 00 00 00    	jne    129ac5a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x43a>
 129abab:	49 8d 87 85 00 00 00 	lea    0x85(%r15),%rax
 129abb2:	41 8b 4f 7f          	mov    0x7f(%r15),%ecx
 129abb6:	89 8d bf fb ff ff    	mov    %ecx,-0x441(%rbp)
 129abbc:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 129abc1:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 129abc7:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 129abcd:	c4 c1 7c 10 5f 60    	vmovups 0x60(%r15),%ymm3
 129abd3:	c5 fc 11 9d a0 fb ff 	vmovups %ymm3,-0x460(%rbp)
 129abda:	ff 
 129abdb:	c5 fc 11 95 80 fb ff 	vmovups %ymm2,-0x480(%rbp)
 129abe2:	ff 
 129abe3:	c5 fc 11 8d 60 fb ff 	vmovups %ymm1,-0x4a0(%rbp)
 129abea:	ff 
 129abeb:	c5 fc 11 85 40 fb ff 	vmovups %ymm0,-0x4c0(%rbp)
 129abf2:	ff 
 129abf3:	0f b7 0d 2e 01 da ff 	movzwl -0x25fed2(%rip),%ecx        # 103ad28 <__anon_28737>
 129abfa:	66 89 8d c3 fb ff ff 	mov    %cx,-0x43d(%rbp)
 129ac01:	48 8b 08             	mov    (%rax),%rcx
 129ac04:	48 89 8d c5 fb ff ff 	mov    %rcx,-0x43b(%rbp)
 129ac0b:	8b 40 07             	mov    0x7(%rax),%eax
 129ac0e:	89 85 cc fb ff ff    	mov    %eax,-0x434(%rbp)
 129ac14:	48 8d bd b8 fd ff ff 	lea    -0x248(%rbp),%rdi
 129ac1b:	4c 8d 85 40 fb ff ff 	lea    -0x4c0(%rbp),%r8
 129ac22:	4c 89 e6             	mov    %r12,%rsi
 129ac25:	4c 89 ea             	mov    %r13,%rdx
 129ac28:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129ac2c:	c5 f8 77             	vzeroupper 
 129ac2f:	e8 ec fb ff ff       	call   129a820 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831>
 129ac34:	0f b7 85 c8 fd ff ff 	movzwl -0x238(%rbp),%eax
 129ac3b:	66 85 c0             	test   %ax,%ax
 129ac3e:	0f 85 29 01 00 00    	jne    129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129ac44:	48 8b 85 b8 fd ff ff 	mov    -0x248(%rbp),%rax
 129ac4b:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 129ac4f:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 129ac56:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 129ac5a:	4c 89 ad 30 ff ff ff 	mov    %r13,-0xd0(%rbp)
 129ac61:	b8 01 00 00 00       	mov    $0x1,%eax
 129ac66:	48 8b 8d 20 ff ff ff 	mov    -0xe0(%rbp),%rcx
 129ac6d:	c4 e2 f1 f7 c0       	shlx   %rcx,%rax,%rax
 129ac72:	48 83 c0 f0          	add    $0xfffffffffffffff0,%rax
 129ac76:	4c 8b 6d 88          	mov    -0x78(%rbp),%r13
 129ac7a:	4c 39 e8             	cmp    %r13,%rax
 129ac7d:	4c 89 e9             	mov    %r13,%rcx
 129ac80:	48 89 85 58 fe ff ff 	mov    %rax,-0x1a8(%rbp)
 129ac87:	48 0f 42 c8          	cmovb  %rax,%rcx
 129ac8b:	48 81 f9 ff ff 00 00 	cmp    $0xffff,%rcx
 129ac92:	b8 ff ff 00 00       	mov    $0xffff,%eax
 129ac97:	48 0f 42 c1          	cmovb  %rcx,%rax
 129ac9b:	f6 85 18 ff ff ff 03 	testb  $0x3,-0xe8(%rbp)
 129aca2:	0f 84 d2 00 00 00    	je     129ad7a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x55a>
 129aca8:	48 89 85 68 fc ff ff 	mov    %rax,-0x398(%rbp)
 129acaf:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 129acb3:	48 89 85 70 fc ff ff 	mov    %rax,-0x390(%rbp)
 129acba:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 129acbe:	48 89 85 78 fc ff ff 	mov    %rax,-0x388(%rbp)
 129acc5:	48 c7 85 80 fc ff ff 	movq   $0x1,-0x380(%rbp)
 129accc:	01 00 00 00 
 129acd0:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 129acd7:	48 89 85 88 fc ff ff 	mov    %rax,-0x378(%rbp)
 129acde:	48 c7 85 90 fc ff ff 	movq   $0x3,-0x370(%rbp)
 129ace5:	03 00 00 00 
 129ace9:	48 c7 85 98 fc ff ff 	movq   $0x102,-0x368(%rbp)
 129acf0:	02 01 00 00 
 129acf4:	48 c7 85 a0 fc ff ff 	movq   $0x0,-0x360(%rbp)
 129acfb:	00 00 00 00 
 129acff:	c6 85 a8 fc ff ff 00 	movb   $0x0,-0x358(%rbp)
 129ad06:	48 8d 9d c0 f3 ff ff 	lea    -0xc40(%rbp),%rbx
 129ad0d:	4c 8d 85 68 fc ff ff 	lea    -0x398(%rbp),%r8
 129ad14:	48 89 df             	mov    %rbx,%rdi
 129ad17:	4c 89 e6             	mov    %r12,%rsi
 129ad1a:	4c 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%r14
 129ad21:	4c 89 f2             	mov    %r14,%rdx
 129ad24:	4c 89 e9             	mov    %r13,%rcx
 129ad27:	e8 94 39 f1 ff       	call   11ae6c0 <lz77.lazyGreedyPlanAlloc>
 129ad2c:	0f b7 85 e8 f3 ff ff 	movzwl -0xc18(%rbp),%eax
 129ad33:	66 85 c0             	test   %ax,%ax
 129ad36:	0f 84 d2 00 00 00    	je     129ae0e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x5ee>
 129ad3c:	89 c3                	mov    %eax,%ebx
 129ad3e:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129ad42:	48 85 f6             	test   %rsi,%rsi
 129ad45:	0f 94 c0             	sete   %al
 129ad48:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129ad4c:	48 85 d2             	test   %rdx,%rdx
 129ad4f:	0f 94 c1             	sete   %cl
 129ad52:	08 c1                	or     %al,%cl
 129ad54:	80 f9 01             	cmp    $0x1,%cl
 129ad57:	0f 84 d3 0f 00 00    	je     129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129ad5d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129ad61:	48 8b 38             	mov    (%rax),%rdi
 129ad64:	48 8b 40 08          	mov    0x8(%rax),%rax
 129ad68:	e9 ab 11 00 00       	jmp    129bf18 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x16f8>
 129ad6d:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 129ad71:	66 89 41 10          	mov    %ax,0x10(%rcx)
 129ad75:	e9 b9 0e 00 00       	jmp    129bc33 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1413>
 129ad7a:	48 89 85 b0 fc ff ff 	mov    %rax,-0x350(%rbp)
 129ad81:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 129ad85:	48 89 85 b8 fc ff ff 	mov    %rax,-0x348(%rbp)
 129ad8c:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 129ad90:	48 89 85 c0 fc ff ff 	mov    %rax,-0x340(%rbp)
 129ad97:	48 c7 85 c8 fc ff ff 	movq   $0x1,-0x338(%rbp)
 129ad9e:	01 00 00 00 
 129ada2:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 129ada9:	48 89 85 d0 fc ff ff 	mov    %rax,-0x330(%rbp)
 129adb0:	48 c7 85 d8 fc ff ff 	movq   $0x3,-0x328(%rbp)
 129adb7:	03 00 00 00 
 129adbb:	48 c7 85 e0 fc ff ff 	movq   $0x102,-0x320(%rbp)
 129adc2:	02 01 00 00 
 129adc6:	48 c7 85 e8 fc ff ff 	movq   $0x0,-0x318(%rbp)
 129adcd:	00 00 00 00 
 129add1:	c6 85 f0 fc ff ff 00 	movb   $0x0,-0x310(%rbp)
 129add8:	48 8d 9d f0 f3 ff ff 	lea    -0xc10(%rbp),%rbx
 129addf:	4c 8d 85 b0 fc ff ff 	lea    -0x350(%rbp),%r8
 129ade6:	48 89 df             	mov    %rbx,%rdi
 129ade9:	4c 89 e6             	mov    %r12,%rsi
 129adec:	4c 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%r14
 129adf3:	4c 89 f2             	mov    %r14,%rdx
 129adf6:	4c 89 e9             	mov    %r13,%rcx
 129adf9:	e8 72 15 f1 ff       	call   11ac370 <lz77.hashGreedyPlanAlloc>
 129adfe:	0f b7 85 18 f4 ff ff 	movzwl -0xbe8(%rbp),%eax
 129ae05:	66 85 c0             	test   %ax,%ax
 129ae08:	0f 85 39 12 00 00    	jne    129c047 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1827>
 129ae0e:	4c 8b 03             	mov    (%rbx),%r8
 129ae11:	4c 8b 4b 08          	mov    0x8(%rbx),%r9
 129ae15:	48 8b 5b 18          	mov    0x18(%rbx),%rbx
 129ae19:	48 8d bd 30 fc ff ff 	lea    -0x3d0(%rbp),%rdi
 129ae20:	4c 89 e6             	mov    %r12,%rsi
 129ae23:	4c 89 f2             	mov    %r14,%rdx
 129ae26:	4c 89 e9             	mov    %r13,%rcx
 129ae29:	4c 89 85 68 ff ff ff 	mov    %r8,-0x98(%rbp)
 129ae30:	4c 89 4d 90          	mov    %r9,-0x70(%rbp)
 129ae34:	e8 f7 4b f1 ff       	call   11afa30 <br.encoder.command_plan.buildAlloc>
 129ae39:	44 0f b7 b5 48 fc ff 	movzwl -0x3b8(%rbp),%r14d
 129ae40:	ff 
 129ae41:	66 45 85 f6          	test   %r14w,%r14w
 129ae45:	0f 85 aa 0f 00 00    	jne    129bdf5 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x15d5>
 129ae4b:	48 8b 85 30 fc ff ff 	mov    -0x3d0(%rbp),%rax
 129ae52:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 129ae56:	48 8b 85 38 fc ff ff 	mov    -0x3c8(%rbp),%rax
 129ae5d:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 129ae61:	c4 c1 78 10 47 58    	vmovups 0x58(%r15),%xmm0
 129ae67:	41 0f b6 87 85 00 00 	movzbl 0x85(%r15),%eax
 129ae6e:	00 
 129ae6f:	0f b6 4d ab          	movzbl -0x55(%rbp),%ecx
 129ae73:	80 e1 01             	and    $0x1,%cl
 129ae76:	0f b6 b5 f8 fe ff ff 	movzbl -0x108(%rbp),%esi
 129ae7d:	40 80 e6 01          	and    $0x1,%sil
 129ae81:	44 0f b6 9d 7c ff ff 	movzbl -0x84(%rbp),%r11d
 129ae88:	ff 
 129ae89:	41 80 e3 01          	and    $0x1,%r11b
 129ae8d:	44 0f b6 ad 7d ff ff 	movzbl -0x83(%rbp),%r13d
 129ae94:	ff 
 129ae95:	41 80 e5 01          	and    $0x1,%r13b
 129ae99:	44 0f b6 95 7a ff ff 	movzbl -0x86(%rbp),%r10d
 129aea0:	ff 
 129aea1:	41 80 e2 01          	and    $0x1,%r10b
 129aea5:	49 89 d9             	mov    %rbx,%r9
 129aea8:	0f b6 9d 7f ff ff ff 	movzbl -0x81(%rbp),%ebx
 129aeaf:	41 0a 9f 8a 00 00 00 	or     0x8a(%r15),%bl
 129aeb6:	80 e3 01             	and    $0x1,%bl
 129aeb9:	44 0f b6 85 79 ff ff 	movzbl -0x87(%rbp),%r8d
 129aec0:	ff 
 129aec1:	41 80 e0 01          	and    $0x1,%r8b
 129aec5:	44 0f b6 b5 7e ff ff 	movzbl -0x82(%rbp),%r14d
 129aecc:	ff 
 129aecd:	45 0a b7 89 00 00 00 	or     0x89(%r15),%r14b
 129aed4:	41 80 e6 01          	and    $0x1,%r14b
 129aed8:	0f b6 bd 78 ff ff ff 	movzbl -0x88(%rbp),%edi
 129aedf:	40 80 e7 01          	and    $0x1,%dil
 129aee3:	41 80 bf 8c 00 00 00 	cmpb   $0x0,0x8c(%r15)
 129aeea:	00 
 129aeeb:	41 0f b6 97 8b 00 00 	movzbl 0x8b(%r15),%edx
 129aef2:	00 
 129aef3:	88 8d 49 fe ff ff    	mov    %cl,-0x1b7(%rbp)
 129aef9:	40 88 b5 4a fe ff ff 	mov    %sil,-0x1b6(%rbp)
 129af00:	c6 85 4b fe ff ff 01 	movb   $0x1,-0x1b5(%rbp)
 129af07:	44 88 9d 4c fe ff ff 	mov    %r11b,-0x1b4(%rbp)
 129af0e:	44 88 ad 4d fe ff ff 	mov    %r13b,-0x1b3(%rbp)
 129af15:	66 c7 85 4e fe ff ff 	movw   $0x0,-0x1b2(%rbp)
 129af1c:	00 00 
 129af1e:	44 88 95 50 fe ff ff 	mov    %r10b,-0x1b0(%rbp)
 129af25:	88 9d 51 fe ff ff    	mov    %bl,-0x1af(%rbp)
 129af2b:	44 88 85 52 fe ff ff 	mov    %r8b,-0x1ae(%rbp)
 129af32:	44 88 b5 53 fe ff ff 	mov    %r14b,-0x1ad(%rbp)
 129af39:	40 88 bd 54 fe ff ff 	mov    %dil,-0x1ac(%rbp)
 129af40:	0f b6 8d 7b ff ff ff 	movzbl -0x85(%rbp),%ecx
 129af47:	0f 45 ca             	cmovne %edx,%ecx
 129af4a:	80 e1 01             	and    $0x1,%cl
 129af4d:	88 8d 55 fe ff ff    	mov    %cl,-0x1ab(%rbp)
 129af53:	24 01                	and    $0x1,%al
 129af55:	88 85 48 fe ff ff    	mov    %al,-0x1b8(%rbp)
 129af5b:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 129af62:	88 85 56 fe ff ff    	mov    %al,-0x1aa(%rbp)
 129af68:	c5 f8 11 85 08 fe ff 	vmovups %xmm0,-0x1f8(%rbp)
 129af6f:	ff 
 129af70:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129af74:	c5 f8 11 85 18 fe ff 	vmovups %xmm0,-0x1e8(%rbp)
 129af7b:	ff 
 129af7c:	c5 fc 10 05 fc 53 d6 	vmovups -0x29ac04(%rip),%ymm0        # 1000380 <__anon_29473>
 129af83:	ff 
 129af84:	c5 fc 11 85 28 fe ff 	vmovups %ymm0,-0x1d8(%rbp)
 129af8b:	ff 
 129af8c:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129af90:	c5 fc 11 85 d0 f6 ff 	vmovups %ymm0,-0x930(%rbp)
 129af97:	ff 
 129af98:	c5 fc 11 85 c0 f6 ff 	vmovups %ymm0,-0x940(%rbp)
 129af9f:	ff 
 129afa0:	c5 fc 11 85 a0 f6 ff 	vmovups %ymm0,-0x960(%rbp)
 129afa7:	ff 
 129afa8:	40 88 b5 70 fe ff ff 	mov    %sil,-0x190(%rbp)
 129afaf:	c5 fc 11 85 80 f6 ff 	vmovups %ymm0,-0x980(%rbp)
 129afb6:	ff 
 129afb7:	c5 fc 11 85 60 f6 ff 	vmovups %ymm0,-0x9a0(%rbp)
 129afbe:	ff 
 129afbf:	4d 85 c9             	test   %r9,%r9
 129afc2:	4d 89 cf             	mov    %r9,%r15
 129afc5:	74 64                	je     129b02b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x80b>
 129afc7:	48 8d 85 08 fe ff ff 	lea    -0x1f8(%rbp),%rax
 129afce:	4c 8d 95 60 f6 ff ff 	lea    -0x9a0(%rbp),%r10
 129afd5:	48 8d bd a0 fd ff ff 	lea    -0x260(%rbp),%rdi
 129afdc:	4c 89 e6             	mov    %r12,%rsi
 129afdf:	4c 8b ad 30 ff ff ff 	mov    -0xd0(%rbp),%r13
 129afe6:	4c 89 ea             	mov    %r13,%rdx
 129afe9:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129afed:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 129aff1:	4d 89 f0             	mov    %r14,%r8
 129aff4:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 129aff8:	50                   	push   %rax
 129aff9:	41 52                	push   %r10
 129affb:	c5 f8 77             	vzeroupper 
 129affe:	e8 cd 35 fa ff       	call   123e5d0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492>
 129b003:	48 83 c4 10          	add    $0x10,%rsp
 129b007:	0f b7 9d b0 fd ff ff 	movzwl -0x250(%rbp),%ebx
 129b00e:	66 85 db             	test   %bx,%bx
 129b011:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 129b015:	0f 85 83 0e 00 00    	jne    129be9e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x167e>
 129b01b:	4c 8b b5 a0 fd ff ff 	mov    -0x260(%rbp),%r14
 129b022:	48 8b 9d a8 fd ff ff 	mov    -0x258(%rbp),%rbx
 129b029:	eb 49                	jmp    129b074 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x854>
 129b02b:	48 8d bd 70 fe ff ff 	lea    -0x190(%rbp),%rdi
 129b032:	4c 8d 85 d0 fd ff ff 	lea    -0x230(%rbp),%r8
 129b039:	4c 89 e6             	mov    %r12,%rsi
 129b03c:	4c 8b ad 30 ff ff ff 	mov    -0xd0(%rbp),%r13
 129b043:	4c 89 ea             	mov    %r13,%rdx
 129b046:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129b04a:	c5 f8 77             	vzeroupper 
 129b04d:	e8 7e 2d f9 ff       	call   122ddd0 <br.encodeStoredStreamWithOptionsAlloc>
 129b052:	0f b7 9d 80 fe ff ff 	movzwl -0x180(%rbp),%ebx
 129b059:	66 85 db             	test   %bx,%bx
 129b05c:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 129b060:	0f 85 00 10 00 00    	jne    129c066 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1846>
 129b066:	4c 8b b5 70 fe ff ff 	mov    -0x190(%rbp),%r14
 129b06d:	48 8b 9d 78 fe ff ff 	mov    -0x188(%rbp),%rbx
 129b074:	4c 89 bd f8 fe ff ff 	mov    %r15,-0x108(%rbp)
 129b07b:	4c 89 b5 58 ff ff ff 	mov    %r14,-0xa8(%rbp)
 129b082:	48 89 9d 60 ff ff ff 	mov    %rbx,-0xa0(%rbp)
 129b089:	48 85 c0             	test   %rax,%rax
 129b08c:	74 56                	je     129b0e4 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x8c4>
 129b08e:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 129b092:	49 39 df             	cmp    %rbx,%r15
 129b095:	73 2f                	jae    129b0c6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x8a6>
 129b097:	49 8b 3c 24          	mov    (%r12),%rdi
 129b09b:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129b0a0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b0a4:	4c 89 f6             	mov    %r14,%rsi
 129b0a7:	48 89 da             	mov    %rbx,%rdx
 129b0aa:	31 c9                	xor    %ecx,%ecx
 129b0ac:	ff 50 18             	call   *0x18(%rax)
 129b0af:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 129b0b3:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 129b0ba:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 129b0c1:	49 89 c7             	mov    %rax,%r15
 129b0c4:	eb 25                	jmp    129b0eb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x8cb>
 129b0c6:	4d 85 ff             	test   %r15,%r15
 129b0c9:	74 19                	je     129b0e4 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x8c4>
 129b0cb:	49 8b 3c 24          	mov    (%r12),%rdi
 129b0cf:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129b0d4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b0d8:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129b0dc:	4c 89 fa             	mov    %r15,%rdx
 129b0df:	31 c9                	xor    %ecx,%ecx
 129b0e1:	ff 50 18             	call   *0x18(%rax)
 129b0e4:	4d 89 f7             	mov    %r14,%r15
 129b0e7:	48 89 5d c0          	mov    %rbx,-0x40(%rbp)
 129b0eb:	0f b6 85 18 ff ff ff 	movzbl -0xe8(%rbp),%eax
 129b0f2:	24 03                	and    $0x3,%al
 129b0f4:	3c 02                	cmp    $0x2,%al
 129b0f6:	0f 94 c0             	sete   %al
 129b0f9:	80 bd 20 ff ff ff 11 	cmpb   $0x11,-0xe0(%rbp)
 129b100:	0f 93 c1             	setae  %cl
 129b103:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 129b107:	49 81 fe f2 ff 00 00 	cmp    $0xfff2,%r14
 129b10e:	0f 93 c2             	setae  %dl
 129b111:	20 ca                	and    %cl,%dl
 129b113:	84 c2                	test   %al,%dl
 129b115:	0f 84 85 02 00 00    	je     129b3a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xb80>
 129b11b:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 129b11f:	c6 85 50 ff ff ff 00 	movb   $0x0,-0xb0(%rbp)
 129b126:	48 c7 85 d0 fb ff ff 	movq   $0x0,-0x430(%rbp)
 129b12d:	00 00 00 00 
 129b131:	4c 89 b5 d8 fb ff ff 	mov    %r14,-0x428(%rbp)
 129b138:	48 c7 85 e0 fb ff ff 	movq   $0x2,-0x420(%rbp)
 129b13f:	02 00 00 00 
 129b143:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129b147:	c5 fc 11 85 e8 fb ff 	vmovups %ymm0,-0x418(%rbp)
 129b14e:	ff 
 129b14f:	c6 85 4f ff ff ff 00 	movb   $0x0,-0xb1(%rbp)
 129b156:	c5 fc 11 85 08 fc ff 	vmovups %ymm0,-0x3f8(%rbp)
 129b15d:	ff 
 129b15e:	66 c7 85 28 fc ff ff 	movw   $0x0,-0x3d8(%rbp)
 129b165:	00 00 
 129b167:	b8 01 00 00 00       	mov    $0x1,%eax
 129b16c:	48 89 85 18 ff ff ff 	mov    %rax,-0xe8(%rbp)
 129b173:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 129b178:	74 32                	je     129b1ac <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x98c>
 129b17a:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 129b17e:	48 83 c0 58          	add    $0x58,%rax
 129b182:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129b186:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 129b18d:	00 00 00 
 129b190:	f6 00 01             	testb  $0x1,(%rax)
 129b193:	75 0b                	jne    129b1a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x980>
 129b195:	48 83 c0 60          	add    $0x60,%rax
 129b199:	48 ff c9             	dec    %rcx
 129b19c:	75 f2                	jne    129b190 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x970>
 129b19e:	eb 0c                	jmp    129b1ac <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x98c>
 129b1a0:	b8 02 00 00 00       	mov    $0x2,%eax
 129b1a5:	48 89 85 18 ff ff ff 	mov    %rax,-0xe8(%rbp)
 129b1ac:	45 31 ff             	xor    %r15d,%r15d
 129b1af:	0f b6 85 28 ff ff ff 	movzbl -0xd8(%rbp),%eax
 129b1b6:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 129b1bd:	e9 91 00 00 00       	jmp    129b253 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xa33>
 129b1c2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 129b1c9:	1f 84 00 00 00 00 00 
 129b1d0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129b1d4:	48 8b 38             	mov    (%rax),%rdi
 129b1d7:	48 8b 40 08          	mov    0x8(%rax),%rax
 129b1db:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b1df:	48 89 b5 00 ff ff ff 	mov    %rsi,-0x100(%rbp)
 129b1e6:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129b1ea:	4c 89 e2             	mov    %r12,%rdx
 129b1ed:	31 c9                	xor    %ecx,%ecx
 129b1ef:	ff 50 18             	call   *0x18(%rax)
 129b1f2:	48 8b 8d 00 ff ff ff 	mov    -0x100(%rbp),%rcx
 129b1f9:	4d 85 ed             	test   %r13,%r13
 129b1fc:	0f 84 77 01 00 00    	je     129b379 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xb59>
 129b202:	4c 8b 65 d0          	mov    -0x30(%rbp),%r12
 129b206:	49 8b 3c 24          	mov    (%r12),%rdi
 129b20a:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129b20f:	49 c1 e5 05          	shl    $0x5,%r13
 129b213:	4a 8d 14 6d 00 00 00 	lea    0x0(,%r13,2),%rdx
 129b21a:	00 
 129b21b:	4c 01 ea             	add    %r13,%rdx
 129b21e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b222:	49 89 cd             	mov    %rcx,%r13
 129b225:	48 89 de             	mov    %rbx,%rsi
 129b228:	b9 03 00 00 00       	mov    $0x3,%ecx
 129b22d:	ff 50 18             	call   *0x18(%rax)
 129b230:	4c 89 6d b8          	mov    %r13,-0x48(%rbp)
 129b234:	4c 89 75 c0          	mov    %r14,-0x40(%rbp)
 129b238:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 129b23c:	4c 8b ad 30 ff ff ff 	mov    -0xd0(%rbp),%r13
 129b243:	49 ff c7             	inc    %r15
 129b246:	4c 39 bd 18 ff ff ff 	cmp    %r15,-0xe8(%rbp)
 129b24d:	0f 84 37 01 00 00    	je     129b38a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xb6a>
 129b253:	4d 85 ff             	test   %r15,%r15
 129b256:	48 8d 85 d0 fb ff ff 	lea    -0x430(%rbp),%rax
 129b25d:	48 0f 44 45 a0       	cmove  -0x60(%rbp),%rax
 129b262:	41 ba 01 00 00 00    	mov    $0x1,%r10d
 129b268:	4c 0f 44 55 b0       	cmove  -0x50(%rbp),%r10
 129b26d:	ba 8e 9e 13 01       	mov    $0x1139e8e,%edx
 129b272:	48 8d bd 70 fe ff ff 	lea    -0x190(%rbp),%rdi
 129b279:	4c 89 e6             	mov    %r12,%rsi
 129b27c:	31 c9                	xor    %ecx,%ecx
 129b27e:	4d 89 e8             	mov    %r13,%r8
 129b281:	4d 89 f1             	mov    %r14,%r9
 129b284:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 129b28a:	ff b5 58 fe ff ff    	push   -0x1a8(%rbp)
 129b290:	41 52                	push   %r10
 129b292:	50                   	push   %rax
 129b293:	c5 f8 77             	vzeroupper 
 129b296:	e8 a5 7d f1 ff       	call   11b3040 <br.encoder.long_distance.augmentAllocWithHistoryAndMaxDistanceForFormat>
 129b29b:	48 83 c4 20          	add    $0x20,%rsp
 129b29f:	0f b7 9d 80 fe ff ff 	movzwl -0x180(%rbp),%ebx
 129b2a6:	66 85 db             	test   %bx,%bx
 129b2a9:	0f 85 0c 0a 00 00    	jne    129bcbb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x149b>
 129b2af:	48 8b 9d 70 fe ff ff 	mov    -0x190(%rbp),%rbx
 129b2b6:	48 85 db             	test   %rbx,%rbx
 129b2b9:	74 88                	je     129b243 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xa23>
 129b2bb:	4c 89 ea             	mov    %r13,%rdx
 129b2be:	4c 8b ad 78 fe ff ff 	mov    -0x188(%rbp),%r13
 129b2c5:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129b2c9:	c5 fc 11 85 40 f6 ff 	vmovups %ymm0,-0x9c0(%rbp)
 129b2d0:	ff 
 129b2d1:	c5 fc 11 85 30 f6 ff 	vmovups %ymm0,-0x9d0(%rbp)
 129b2d8:	ff 
 129b2d9:	c5 fc 11 85 10 f6 ff 	vmovups %ymm0,-0x9f0(%rbp)
 129b2e0:	ff 
 129b2e1:	c5 fc 11 85 f0 f5 ff 	vmovups %ymm0,-0xa10(%rbp)
 129b2e8:	ff 
 129b2e9:	c5 fc 11 85 d0 f5 ff 	vmovups %ymm0,-0xa30(%rbp)
 129b2f0:	ff 
 129b2f1:	48 8d bd 88 fd ff ff 	lea    -0x278(%rbp),%rdi
 129b2f8:	4c 89 e6             	mov    %r12,%rsi
 129b2fb:	4c 89 f1             	mov    %r14,%rcx
 129b2fe:	49 89 d8             	mov    %rbx,%r8
 129b301:	4d 89 e9             	mov    %r13,%r9
 129b304:	48 8d 85 08 fe ff ff 	lea    -0x1f8(%rbp),%rax
 129b30b:	50                   	push   %rax
 129b30c:	48 8d 85 d0 f5 ff ff 	lea    -0xa30(%rbp),%rax
 129b313:	50                   	push   %rax
 129b314:	c5 f8 77             	vzeroupper 
 129b317:	e8 b4 32 fa ff       	call   123e5d0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492>
 129b31c:	48 83 c4 10          	add    $0x10,%rsp
 129b320:	44 0f b7 b5 98 fd ff 	movzwl -0x268(%rbp),%r14d
 129b327:	ff 
 129b328:	66 45 85 f6          	test   %r14w,%r14w
 129b32c:	0f 85 0b 0a 00 00    	jne    129bd3d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x151d>
 129b332:	48 8b b5 88 fd ff ff 	mov    -0x278(%rbp),%rsi
 129b339:	4c 8b b5 90 fd ff ff 	mov    -0x270(%rbp),%r14
 129b340:	4c 8b 65 c0          	mov    -0x40(%rbp),%r12
 129b344:	4d 39 e6             	cmp    %r12,%r14
 129b347:	0f 82 83 fe ff ff    	jb     129b1d0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x9b0>
 129b34d:	4d 85 f6             	test   %r14,%r14
 129b350:	74 17                	je     129b369 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xb49>
 129b352:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129b356:	48 8b 38             	mov    (%rax),%rdi
 129b359:	48 8b 40 08          	mov    0x8(%rax),%rax
 129b35d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b361:	4c 89 f2             	mov    %r14,%rdx
 129b364:	31 c9                	xor    %ecx,%ecx
 129b366:	ff 50 18             	call   *0x18(%rax)
 129b369:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129b36d:	4d 89 e6             	mov    %r12,%r14
 129b370:	4d 85 ed             	test   %r13,%r13
 129b373:	0f 85 89 fe ff ff    	jne    129b202 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x9e2>
 129b379:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 129b37d:	4c 89 75 c0          	mov    %r14,-0x40(%rbp)
 129b381:	4c 8b 65 d0          	mov    -0x30(%rbp),%r12
 129b385:	e9 ae fe ff ff       	jmp    129b238 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xa18>
 129b38a:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 129b38e:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 129b395:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 129b399:	4c 89 bd 58 ff ff ff 	mov    %r15,-0xa8(%rbp)
 129b3a0:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 129b3a7:	48 c1 e8 38          	shr    $0x38,%rax
 129b3ab:	83 e0 01             	and    $0x1,%eax
 129b3ae:	80 7d 80 00          	cmpb   $0x0,-0x80(%rbp)
 129b3b2:	44 0f b6 65 81       	movzbl -0x7f(%rbp),%r12d
 129b3b7:	44 0f 45 e0          	cmovne %eax,%r12d
 129b3bb:	0f b6 4d ab          	movzbl -0x55(%rbp),%ecx
 129b3bf:	44 20 e1             	and    %r12b,%cl
 129b3c2:	48 83 bd f8 fe ff ff 	cmpq   $0x0,-0x108(%rbp)
 129b3c9:	00 
 129b3ca:	0f 95 c0             	setne  %al
 129b3cd:	84 c1                	test   %al,%cl
 129b3cf:	0f 84 2a 02 00 00    	je     129b5ff <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xddf>
 129b3d5:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129b3d9:	c5 fc 11 85 b0 f5 ff 	vmovups %ymm0,-0xa50(%rbp)
 129b3e0:	ff 
 129b3e1:	c5 fc 11 85 a0 f5 ff 	vmovups %ymm0,-0xa60(%rbp)
 129b3e8:	ff 
 129b3e9:	c5 fc 11 85 80 f5 ff 	vmovups %ymm0,-0xa80(%rbp)
 129b3f0:	ff 
 129b3f1:	c5 fc 11 85 60 f5 ff 	vmovups %ymm0,-0xaa0(%rbp)
 129b3f8:	ff 
 129b3f9:	c5 fc 11 85 40 f5 ff 	vmovups %ymm0,-0xac0(%rbp)
 129b400:	ff 
 129b401:	c6 85 74 ff ff ff 00 	movb   $0x0,-0x8c(%rbp)
 129b408:	c6 85 75 ff ff ff 00 	movb   $0x0,-0x8b(%rbp)
 129b40f:	0f b6 45 83          	movzbl -0x7d(%rbp),%eax
 129b413:	88 85 11 f9 ff ff    	mov    %al,-0x6ef(%rbp)
 129b419:	48 c7 85 00 f7 ff ff 	movq   $0x0,-0x900(%rbp)
 129b420:	00 00 00 00 
 129b424:	66 c7 85 14 f9 ff ff 	movw   $0x100,-0x6ec(%rbp)
 129b42b:	00 01 
 129b42d:	c5 fc 11 85 30 f7 ff 	vmovups %ymm0,-0x8d0(%rbp)
 129b434:	ff 
 129b435:	c5 fc 11 85 50 f7 ff 	vmovups %ymm0,-0x8b0(%rbp)
 129b43c:	ff 
 129b43d:	c5 fc 11 85 70 f7 ff 	vmovups %ymm0,-0x890(%rbp)
 129b444:	ff 
 129b445:	c5 fc 11 85 90 f7 ff 	vmovups %ymm0,-0x870(%rbp)
 129b44c:	ff 
 129b44d:	c5 fc 11 85 b0 f7 ff 	vmovups %ymm0,-0x850(%rbp)
 129b454:	ff 
 129b455:	c5 fc 11 85 d0 f7 ff 	vmovups %ymm0,-0x830(%rbp)
 129b45c:	ff 
 129b45d:	c5 fc 11 85 f0 f7 ff 	vmovups %ymm0,-0x810(%rbp)
 129b464:	ff 
 129b465:	c5 fc 11 85 10 f8 ff 	vmovups %ymm0,-0x7f0(%rbp)
 129b46c:	ff 
 129b46d:	c5 fc 11 85 30 f8 ff 	vmovups %ymm0,-0x7d0(%rbp)
 129b474:	ff 
 129b475:	c5 fc 11 85 50 f8 ff 	vmovups %ymm0,-0x7b0(%rbp)
 129b47c:	ff 
 129b47d:	c5 fc 11 85 70 f8 ff 	vmovups %ymm0,-0x790(%rbp)
 129b484:	ff 
 129b485:	c5 fc 11 85 90 f8 ff 	vmovups %ymm0,-0x770(%rbp)
 129b48c:	ff 
 129b48d:	c5 fc 11 85 b0 f8 ff 	vmovups %ymm0,-0x750(%rbp)
 129b494:	ff 
 129b495:	c5 fc 11 85 d0 f8 ff 	vmovups %ymm0,-0x730(%rbp)
 129b49c:	ff 
 129b49d:	48 c7 85 f0 f8 ff ff 	movq   $0x0,-0x710(%rbp)
 129b4a4:	00 00 00 00 
 129b4a8:	c6 85 08 f9 ff ff 38 	movb   $0x38,-0x6f8(%rbp)
 129b4af:	c6 85 10 f9 ff ff 00 	movb   $0x0,-0x6f0(%rbp)
 129b4b6:	0f b6 85 74 ff ff ff 	movzbl -0x8c(%rbp),%eax
 129b4bd:	0f b6 8d 75 ff ff ff 	movzbl -0x8b(%rbp),%ecx
 129b4c4:	88 85 0a f9 ff ff    	mov    %al,-0x6f6(%rbp)
 129b4ca:	88 8d 0b f9 ff ff    	mov    %cl,-0x6f5(%rbp)
 129b4d0:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 129b4d7:	88 85 09 f9 ff ff    	mov    %al,-0x6f7(%rbp)
 129b4dd:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 129b4e4:	48 89 85 f0 f6 ff ff 	mov    %rax,-0x910(%rbp)
 129b4eb:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 129b4f2:	48 89 85 f8 f6 ff ff 	mov    %rax,-0x908(%rbp)
 129b4f9:	c7 85 0c f9 ff ff 01 	movl   $0x1000101,-0x6f4(%rbp)
 129b500:	01 00 01 
 129b503:	66 c7 85 12 f9 ff ff 	movw   $0x0,-0x6ee(%rbp)
 129b50a:	00 00 
 129b50c:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129b510:	c5 f8 11 85 f8 f8 ff 	vmovups %xmm0,-0x708(%rbp)
 129b517:	ff 
 129b518:	c5 fc 10 05 60 4e d6 	vmovups -0x29b1a0(%rip),%ymm0        # 1000380 <__anon_29473>
 129b51f:	ff 
 129b520:	c5 fc 11 85 10 f7 ff 	vmovups %ymm0,-0x8f0(%rbp)
 129b527:	ff 
 129b528:	48 c7 85 08 f7 ff ff 	movq   $0x0,-0x8f8(%rbp)
 129b52f:	00 00 00 00 
 129b533:	48 83 ec 08          	sub    $0x8,%rsp
 129b537:	48 8d 85 f0 f6 ff ff 	lea    -0x910(%rbp),%rax
 129b53e:	4c 8d 95 40 f5 ff ff 	lea    -0xac0(%rbp),%r10
 129b545:	48 8d bd 70 fd ff ff 	lea    -0x290(%rbp),%rdi
 129b54c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 129b550:	4c 89 ea             	mov    %r13,%rdx
 129b553:	4c 89 f1             	mov    %r14,%rcx
 129b556:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 129b55a:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 129b55e:	50                   	push   %rax
 129b55f:	41 52                	push   %r10
 129b561:	6a 01                	push   $0x1
 129b563:	c5 f8 77             	vzeroupper 
 129b566:	e8 85 48 f9 ff       	call   122fdf0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626>
 129b56b:	48 83 c4 20          	add    $0x20,%rsp
 129b56f:	0f b7 9d 80 fd ff ff 	movzwl -0x280(%rbp),%ebx
 129b576:	66 85 db             	test   %bx,%bx
 129b579:	0f 85 a2 09 00 00    	jne    129bf21 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1701>
 129b57f:	4c 8b b5 70 fd ff ff 	mov    -0x290(%rbp),%r14
 129b586:	48 8b 9d 78 fd ff ff 	mov    -0x288(%rbp),%rbx
 129b58d:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129b591:	48 39 d3             	cmp    %rdx,%rbx
 129b594:	73 42                	jae    129b5d8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xdb8>
 129b596:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129b59a:	48 8b 38             	mov    (%rax),%rdi
 129b59d:	48 8b 40 08          	mov    0x8(%rax),%rax
 129b5a1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b5a5:	4c 89 fe             	mov    %r15,%rsi
 129b5a8:	31 c9                	xor    %ecx,%ecx
 129b5aa:	ff 50 18             	call   *0x18(%rax)
 129b5ad:	4c 89 b5 58 ff ff ff 	mov    %r14,-0xa8(%rbp)
 129b5b4:	48 89 9d 60 ff ff ff 	mov    %rbx,-0xa0(%rbp)
 129b5bb:	0f b6 45 ae          	movzbl -0x52(%rbp),%eax
 129b5bf:	88 45 ac             	mov    %al,-0x54(%rbp)
 129b5c2:	4d 89 f7             	mov    %r14,%r15
 129b5c5:	48 89 5d c0          	mov    %rbx,-0x40(%rbp)
 129b5c9:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 129b5cd:	f6 45 ac 01          	testb  $0x1,-0x54(%rbp)
 129b5d1:	75 36                	jne    129b609 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xde9>
 129b5d3:	e9 28 01 00 00       	jmp    129b700 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xee0>
 129b5d8:	48 85 db             	test   %rbx,%rbx
 129b5db:	0f 84 a2 06 00 00    	je     129bc83 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1463>
 129b5e1:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129b5e5:	48 8b 38             	mov    (%rax),%rdi
 129b5e8:	48 8b 40 08          	mov    0x8(%rax),%rax
 129b5ec:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b5f0:	4c 89 f6             	mov    %r14,%rsi
 129b5f3:	48 89 da             	mov    %rbx,%rdx
 129b5f6:	31 c9                	xor    %ecx,%ecx
 129b5f8:	ff 50 18             	call   *0x18(%rax)
 129b5fb:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 129b5ff:	f6 45 ac 01          	testb  $0x1,-0x54(%rbp)
 129b603:	0f 84 f7 00 00 00    	je     129b700 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xee0>
 129b609:	49 81 fe 00 10 00 00 	cmp    $0x1000,%r14
 129b610:	0f 82 ea 00 00 00    	jb     129b700 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xee0>
 129b616:	4c 3b b5 68 fe ff ff 	cmp    -0x198(%rbp),%r14
 129b61d:	0f 87 dd 00 00 00    	ja     129b700 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xee0>
 129b623:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 129b627:	c5 f8 28 85 50 fc ff 	vmovaps -0x3b0(%rbp),%xmm0
 129b62e:	ff 
 129b62f:	c5 f8 13 85 a8 fe ff 	vmovlps %xmm0,-0x158(%rbp)
 129b636:	ff 
 129b637:	8b 85 10 ff ff ff    	mov    -0xf0(%rbp),%eax
 129b63d:	89 85 b0 fe ff ff    	mov    %eax,-0x150(%rbp)
 129b643:	0f b7 85 14 ff ff ff 	movzwl -0xec(%rbp),%eax
 129b64a:	66 89 85 b4 fe ff ff 	mov    %ax,-0x14c(%rbp)
 129b651:	0f b6 45 ae          	movzbl -0x52(%rbp),%eax
 129b655:	88 85 b6 fe ff ff    	mov    %al,-0x14a(%rbp)
 129b65b:	0f b6 45 82          	movzbl -0x7e(%rbp),%eax
 129b65f:	88 85 b7 fe ff ff    	mov    %al,-0x149(%rbp)
 129b665:	48 8d bd 58 fd ff ff 	lea    -0x2a8(%rbp),%rdi
 129b66c:	4c 8d 85 a8 fe ff ff 	lea    -0x158(%rbp),%r8
 129b673:	4c 8d 8d 08 fe ff ff 	lea    -0x1f8(%rbp),%r9
 129b67a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 129b67e:	4c 89 ea             	mov    %r13,%rdx
 129b681:	4c 89 f1             	mov    %r14,%rcx
 129b684:	e8 17 1f 00 00       	call   129d5a0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937>
 129b689:	0f b7 9d 68 fd ff ff 	movzwl -0x298(%rbp),%ebx
 129b690:	66 85 db             	test   %bx,%bx
 129b693:	0f 85 a5 08 00 00    	jne    129bf3e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x171e>
 129b699:	4c 8b bd 58 fd ff ff 	mov    -0x2a8(%rbp),%r15
 129b6a0:	4d 85 ff             	test   %r15,%r15
 129b6a3:	74 57                	je     129b6fc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xedc>
 129b6a5:	48 8b 9d 60 fd ff ff 	mov    -0x2a0(%rbp),%rbx
 129b6ac:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129b6b0:	48 39 d3             	cmp    %rdx,%rbx
 129b6b3:	73 28                	jae    129b6dd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xebd>
 129b6b5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129b6b9:	48 8b 38             	mov    (%rax),%rdi
 129b6bc:	48 8b 40 08          	mov    0x8(%rax),%rax
 129b6c0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b6c4:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129b6c8:	31 c9                	xor    %ecx,%ecx
 129b6ca:	ff 50 18             	call   *0x18(%rax)
 129b6cd:	4c 89 bd 58 ff ff ff 	mov    %r15,-0xa8(%rbp)
 129b6d4:	48 89 9d 60 ff ff ff 	mov    %rbx,-0xa0(%rbp)
 129b6db:	eb 27                	jmp    129b704 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xee4>
 129b6dd:	48 85 db             	test   %rbx,%rbx
 129b6e0:	74 1a                	je     129b6fc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xedc>
 129b6e2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129b6e6:	48 8b 38             	mov    (%rax),%rdi
 129b6e9:	48 8b 40 08          	mov    0x8(%rax),%rax
 129b6ed:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b6f1:	4c 89 fe             	mov    %r15,%rsi
 129b6f4:	48 89 da             	mov    %rbx,%rdx
 129b6f7:	31 c9                	xor    %ecx,%ecx
 129b6f9:	ff 50 18             	call   *0x18(%rax)
 129b6fc:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 129b700:	48 8b 5d c0          	mov    -0x40(%rbp),%rbx
 129b704:	80 7d ad 0a          	cmpb   $0xa,-0x53(%rbp)
 129b708:	0f 93 c0             	setae  %al
 129b70b:	f6 85 08 ff ff ff 10 	testb  $0x10,-0xf8(%rbp)
 129b712:	0f 95 c1             	setne  %cl
 129b715:	20 c1                	and    %al,%cl
 129b717:	49 8d 86 00 f0 ff ff 	lea    -0x1000(%r14),%rax
 129b71e:	48 3d 01 f0 00 00    	cmp    $0xf001,%rax
 129b724:	0f 92 c0             	setb   %al
 129b727:	84 c1                	test   %al,%cl
 129b729:	0f 84 fa 00 00 00    	je     129b829 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1009>
 129b72f:	43 80 7c 35 ff 0a    	cmpb   $0xa,-0x1(%r13,%r14,1)
 129b735:	0f 85 ee 00 00 00    	jne    129b829 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1009>
 129b73b:	4c 89 ef             	mov    %r13,%rdi
 129b73e:	4c 89 f6             	mov    %r14,%rsi
 129b741:	e8 9a b7 ea ff       	call   1146ee0 <vortBrStableFixedWidthRecord>
 129b746:	84 c0                	test   %al,%al
 129b748:	0f 84 db 00 00 00    	je     129b829 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1009>
 129b74e:	4c 89 f1             	mov    %r14,%rcx
 129b751:	48 89 5d b8          	mov    %rbx,-0x48(%rbp)
 129b755:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129b759:	c5 fc 11 85 20 f5 ff 	vmovups %ymm0,-0xae0(%rbp)
 129b760:	ff 
 129b761:	c5 fc 11 85 10 f5 ff 	vmovups %ymm0,-0xaf0(%rbp)
 129b768:	ff 
 129b769:	c5 fc 11 85 f0 f4 ff 	vmovups %ymm0,-0xb10(%rbp)
 129b770:	ff 
 129b771:	c5 fc 11 85 d0 f4 ff 	vmovups %ymm0,-0xb30(%rbp)
 129b778:	ff 
 129b779:	c5 fc 11 85 b0 f4 ff 	vmovups %ymm0,-0xb50(%rbp)
 129b780:	ff 
 129b781:	44 0f b6 4d ce       	movzbl -0x32(%rbp),%r9d
 129b786:	48 8d 85 b0 f4 ff ff 	lea    -0xb50(%rbp),%rax
 129b78d:	45 0f b6 d4          	movzbl %r12b,%r10d
 129b791:	44 0f b6 85 08 ff ff 	movzbl -0xf8(%rbp),%r8d
 129b798:	ff 
 129b799:	48 8d bd 40 fd ff ff 	lea    -0x2c0(%rbp),%rdi
 129b7a0:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 129b7a4:	4c 89 f6             	mov    %r14,%rsi
 129b7a7:	4c 89 ea             	mov    %r13,%rdx
 129b7aa:	50                   	push   %rax
 129b7ab:	41 52                	push   %r10
 129b7ad:	ff b5 40 ff ff ff    	push   -0xc0(%rbp)
 129b7b3:	ff b5 38 ff ff ff    	push   -0xc8(%rbp)
 129b7b9:	c5 f8 77             	vzeroupper 
 129b7bc:	e8 cf 3c f9 ff       	call   122f490 <br.encodeRecordOptimalCandidateWithOptionsAlloc>
 129b7c1:	48 83 c4 20          	add    $0x20,%rsp
 129b7c5:	0f b7 9d 50 fd ff ff 	movzwl -0x2b0(%rbp),%ebx
 129b7cc:	66 85 db             	test   %bx,%bx
 129b7cf:	0f 85 21 09 00 00    	jne    129c0f6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x18d6>
 129b7d5:	48 8b 85 40 fd ff ff 	mov    -0x2c0(%rbp),%rax
 129b7dc:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 129b7e0:	48 85 c0             	test   %rax,%rax
 129b7e3:	44 0f b6 65 cf       	movzbl -0x31(%rbp),%r12d
 129b7e8:	0f 84 c4 04 00 00    	je     129bcb2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1492>
 129b7ee:	48 8b 9d 48 fd ff ff 	mov    -0x2b8(%rbp),%rbx
 129b7f5:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 129b7f9:	48 39 d3             	cmp    %rdx,%rbx
 129b7fc:	0f 83 94 04 00 00    	jae    129bc96 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1476>
 129b802:	49 8b 3e             	mov    (%r14),%rdi
 129b805:	49 8b 46 08          	mov    0x8(%r14),%rax
 129b809:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129b80d:	4c 89 fe             	mov    %r15,%rsi
 129b810:	31 c9                	xor    %ecx,%ecx
 129b812:	ff 50 18             	call   *0x18(%rax)
 129b815:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 129b819:	4c 89 bd 58 ff ff ff 	mov    %r15,-0xa8(%rbp)
 129b820:	48 89 9d 60 ff ff ff 	mov    %rbx,-0xa0(%rbp)
 129b827:	eb 09                	jmp    129b832 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1012>
 129b829:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 129b82d:	44 0f b6 65 cf       	movzbl -0x31(%rbp),%r12d
 129b832:	41 80 e4 03          	and    $0x3,%r12b
 129b836:	41 80 fc 02          	cmp    $0x2,%r12b
 129b83a:	0f 94 c0             	sete   %al
 129b83d:	80 7d ad 04          	cmpb   $0x4,-0x53(%rbp)
 129b841:	0f 93 c1             	setae  %cl
 129b844:	84 c8                	test   %cl,%al
 129b846:	0f 84 a6 02 00 00    	je     129baf2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x12d2>
 129b84c:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 129b850:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129b854:	c5 fc 11 85 90 f4 ff 	vmovups %ymm0,-0xb70(%rbp)
 129b85b:	ff 
 129b85c:	c5 fc 11 85 80 f4 ff 	vmovups %ymm0,-0xb80(%rbp)
 129b863:	ff 
 129b864:	c5 fc 11 85 60 f4 ff 	vmovups %ymm0,-0xba0(%rbp)
 129b86b:	ff 
 129b86c:	c5 fc 11 85 40 f4 ff 	vmovups %ymm0,-0xbc0(%rbp)
 129b873:	ff 
 129b874:	c5 fc 11 85 20 f4 ff 	vmovups %ymm0,-0xbe0(%rbp)
 129b87b:	ff 
 129b87c:	0f b6 85 77 ff ff ff 	movzbl -0x89(%rbp),%eax
 129b883:	c6 85 72 ff ff ff 01 	movb   $0x1,-0x8e(%rbp)
 129b88a:	c6 85 73 ff ff ff 06 	movb   $0x6,-0x8d(%rbp)
 129b891:	0f b6 4d ce          	movzbl -0x32(%rbp),%ecx
 129b895:	88 8d 39 fb ff ff    	mov    %cl,-0x4c7(%rbp)
 129b89b:	48 c7 85 28 f9 ff ff 	movq   $0x0,-0x6d8(%rbp)
 129b8a2:	00 00 00 00 
 129b8a6:	88 85 3d fb ff ff    	mov    %al,-0x4c3(%rbp)
 129b8ac:	c6 85 3c fb ff ff 00 	movb   $0x0,-0x4c4(%rbp)
 129b8b3:	c5 fc 11 85 58 f9 ff 	vmovups %ymm0,-0x6a8(%rbp)
 129b8ba:	ff 
 129b8bb:	c5 fc 11 85 78 f9 ff 	vmovups %ymm0,-0x688(%rbp)
 129b8c2:	ff 
 129b8c3:	c5 fc 11 85 98 f9 ff 	vmovups %ymm0,-0x668(%rbp)
 129b8ca:	ff 
 129b8cb:	c5 fc 11 85 b8 f9 ff 	vmovups %ymm0,-0x648(%rbp)
 129b8d2:	ff 
 129b8d3:	c5 fc 11 85 d8 f9 ff 	vmovups %ymm0,-0x628(%rbp)
 129b8da:	ff 
 129b8db:	c5 fc 11 85 f8 f9 ff 	vmovups %ymm0,-0x608(%rbp)
 129b8e2:	ff 
 129b8e3:	c5 fc 11 85 18 fa ff 	vmovups %ymm0,-0x5e8(%rbp)
 129b8ea:	ff 
 129b8eb:	c5 fc 11 85 38 fa ff 	vmovups %ymm0,-0x5c8(%rbp)
 129b8f2:	ff 
 129b8f3:	c5 fc 11 85 58 fa ff 	vmovups %ymm0,-0x5a8(%rbp)
 129b8fa:	ff 
 129b8fb:	c5 fc 11 85 78 fa ff 	vmovups %ymm0,-0x588(%rbp)
 129b902:	ff 
 129b903:	c5 fc 11 85 98 fa ff 	vmovups %ymm0,-0x568(%rbp)
 129b90a:	ff 
 129b90b:	c5 fc 11 85 b8 fa ff 	vmovups %ymm0,-0x548(%rbp)
 129b912:	ff 
 129b913:	c5 fc 11 85 d8 fa ff 	vmovups %ymm0,-0x528(%rbp)
 129b91a:	ff 
 129b91b:	c5 fc 11 85 f8 fa ff 	vmovups %ymm0,-0x508(%rbp)
 129b922:	ff 
 129b923:	48 c7 85 18 fb ff ff 	movq   $0x0,-0x4e8(%rbp)
 129b92a:	00 00 00 00 
 129b92e:	c6 85 30 fb ff ff 38 	movb   $0x38,-0x4d0(%rbp)
 129b935:	c6 85 38 fb ff ff 00 	movb   $0x0,-0x4c8(%rbp)
 129b93c:	0f b6 85 72 ff ff ff 	movzbl -0x8e(%rbp),%eax
 129b943:	0f b6 8d 73 ff ff ff 	movzbl -0x8d(%rbp),%ecx
 129b94a:	88 85 32 fb ff ff    	mov    %al,-0x4ce(%rbp)
 129b950:	88 8d 33 fb ff ff    	mov    %cl,-0x4cd(%rbp)
 129b956:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 129b95d:	88 85 31 fb ff ff    	mov    %al,-0x4cf(%rbp)
 129b963:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 129b96a:	48 89 85 18 f9 ff ff 	mov    %rax,-0x6e8(%rbp)
 129b971:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 129b978:	48 89 85 20 f9 ff ff 	mov    %rax,-0x6e0(%rbp)
 129b97f:	c7 85 34 fb ff ff 01 	movl   $0x101,-0x4cc(%rbp)
 129b986:	01 00 00 
 129b989:	66 c7 85 3a fb ff ff 	movw   $0x0,-0x4c6(%rbp)
 129b990:	00 00 
 129b992:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129b996:	c5 f8 11 85 20 fb ff 	vmovups %xmm0,-0x4e0(%rbp)
 129b99d:	ff 
 129b99e:	c5 fc 10 05 da 49 d6 	vmovups -0x29b626(%rip),%ymm0        # 1000380 <__anon_29473>
 129b9a5:	ff 
 129b9a6:	c5 fc 11 85 38 f9 ff 	vmovups %ymm0,-0x6c8(%rbp)
 129b9ad:	ff 
 129b9ae:	48 c7 85 30 f9 ff ff 	movq   $0x0,-0x6d0(%rbp)
 129b9b5:	00 00 00 00 
 129b9b9:	48 8d 85 18 f9 ff ff 	lea    -0x6e8(%rbp),%rax
 129b9c0:	4c 8d 95 20 f4 ff ff 	lea    -0xbe0(%rbp),%r10
 129b9c7:	48 8d bd 28 fd ff ff 	lea    -0x2d8(%rbp),%rdi
 129b9ce:	4c 89 f6             	mov    %r14,%rsi
 129b9d1:	4c 89 ea             	mov    %r13,%rdx
 129b9d4:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129b9d8:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 129b9dc:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 129b9e0:	50                   	push   %rax
 129b9e1:	41 52                	push   %r10
 129b9e3:	c5 f8 77             	vzeroupper 
 129b9e6:	e8 35 b7 f1 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 129b9eb:	48 83 c4 10          	add    $0x10,%rsp
 129b9ef:	44 0f b7 b5 38 fd ff 	movzwl -0x2c8(%rbp),%r14d
 129b9f6:	ff 
 129b9f7:	45 85 f6             	test   %r14d,%r14d
 129b9fa:	0f 85 a8 05 00 00    	jne    129bfa8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1788>
 129ba00:	4c 8b bd 28 fd ff ff 	mov    -0x2d8(%rbp),%r15
 129ba07:	4c 8b a5 30 fd ff ff 	mov    -0x2d0(%rbp),%r12
 129ba0e:	4d 85 ff             	test   %r15,%r15
 129ba11:	0f 84 e0 00 00 00    	je     129baf7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x12d7>
 129ba17:	49 39 dc             	cmp    %rbx,%r12
 129ba1a:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 129ba1e:	0f 83 21 02 00 00    	jae    129bc45 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1425>
 129ba24:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129ba28:	48 8b 38             	mov    (%rax),%rdi
 129ba2b:	48 8b 40 08          	mov    0x8(%rax),%rax
 129ba2f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129ba33:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 129ba37:	48 89 da             	mov    %rbx,%rdx
 129ba3a:	31 c9                	xor    %ecx,%ecx
 129ba3c:	ff 50 18             	call   *0x18(%rax)
 129ba3f:	4c 89 bd 58 ff ff ff 	mov    %r15,-0xa8(%rbp)
 129ba46:	4c 89 a5 60 ff ff ff 	mov    %r12,-0xa0(%rbp)
 129ba4d:	49 81 fe 01 01 00 00 	cmp    $0x101,%r14
 129ba54:	0f 92 c0             	setb   %al
 129ba57:	84 45 84             	test   %al,-0x7c(%rbp)
 129ba5a:	0f 85 b5 00 00 00    	jne    129bb15 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x12f5>
 129ba60:	49 81 fe 01 10 00 00 	cmp    $0x1001,%r14
 129ba67:	0f 92 c0             	setb   %al
 129ba6a:	84 85 76 ff ff ff    	test   %al,-0x8a(%rbp)
 129ba70:	0f 84 0c 01 00 00    	je     129bb82 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1362>
 129ba76:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 129ba7c:	66 85 c0             	test   %ax,%ax
 129ba7f:	0f 44 85 bc fe ff ff 	cmove  -0x144(%rbp),%eax
 129ba86:	66 85 c0             	test   %ax,%ax
 129ba89:	0f 84 f3 00 00 00    	je     129bb82 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1362>
 129ba8f:	0f b7 c0             	movzwl %ax,%eax
 129ba92:	44 0f b6 55 ce       	movzbl -0x32(%rbp),%r10d
 129ba97:	48 83 ec 08          	sub    $0x8,%rsp
 129ba9b:	4c 8d 9d 58 ff ff ff 	lea    -0xa8(%rbp),%r11
 129baa2:	44 0f b6 8d 08 ff ff 	movzbl -0xf8(%rbp),%r9d
 129baa9:	ff 
 129baaa:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 129baae:	4c 89 ee             	mov    %r13,%rsi
 129bab1:	4c 89 f2             	mov    %r14,%rdx
 129bab4:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 129bab8:	4c 8b 45 b0          	mov    -0x50(%rbp),%r8
 129babc:	41 53                	push   %r11
 129babe:	50                   	push   %rax
 129babf:	ff b5 40 ff ff ff    	push   -0xc0(%rbp)
 129bac5:	ff b5 38 ff ff ff    	push   -0xc8(%rbp)
 129bacb:	41 52                	push   %r10
 129bacd:	e8 2e b2 f1 ff       	call   11b6d00 <br.selectExtendedRatioStaticDictionary>
 129bad2:	48 83 c4 30          	add    $0x30,%rsp
 129bad6:	66 85 c0             	test   %ax,%ax
 129bad9:	0f 85 36 06 00 00    	jne    129c115 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x18f5>
 129badf:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 129bae6:	4c 8b a5 60 ff ff ff 	mov    -0xa0(%rbp),%r12
 129baed:	e9 90 00 00 00       	jmp    129bb82 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1362>
 129baf2:	49 89 dc             	mov    %rbx,%r12
 129baf5:	eb 07                	jmp    129bafe <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x12de>
 129baf7:	49 89 dc             	mov    %rbx,%r12
 129bafa:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 129bafe:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 129bb02:	49 81 fe 01 01 00 00 	cmp    $0x101,%r14
 129bb09:	0f 92 c0             	setb   %al
 129bb0c:	84 45 84             	test   %al,-0x7c(%rbp)
 129bb0f:	0f 84 4b ff ff ff    	je     129ba60 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1240>
 129bb15:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 129bb19:	44 0f b6 95 08 ff ff 	movzbl -0xf8(%rbp),%r10d
 129bb20:	ff 
 129bb21:	48 8d bd 10 fd ff ff 	lea    -0x2f0(%rbp),%rdi
 129bb28:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 129bb2c:	4c 89 ea             	mov    %r13,%rdx
 129bb2f:	4c 89 f1             	mov    %r14,%rcx
 129bb32:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 129bb36:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 129bb3a:	ff b5 40 ff ff ff    	push   -0xc0(%rbp)
 129bb40:	ff b5 38 ff ff ff    	push   -0xc8(%rbp)
 129bb46:	50                   	push   %rax
 129bb47:	41 52                	push   %r10
 129bb49:	41 54                	push   %r12
 129bb4b:	41 57                	push   %r15
 129bb4d:	e8 3e 0b f9 ff       	call   122c690 <br.selectRatioStaticDictionaryAlloc>
 129bb52:	48 83 c4 30          	add    $0x30,%rsp
 129bb56:	0f b7 9d 20 fd ff ff 	movzwl -0x2e0(%rbp),%ebx
 129bb5d:	66 85 db             	test   %bx,%bx
 129bb60:	0f 85 f9 03 00 00    	jne    129bf5f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x173f>
 129bb66:	4c 8b bd 10 fd ff ff 	mov    -0x2f0(%rbp),%r15
 129bb6d:	4c 8b a5 18 fd ff ff 	mov    -0x2e8(%rbp),%r12
 129bb74:	4c 89 bd 58 ff ff ff 	mov    %r15,-0xa8(%rbp)
 129bb7b:	4c 89 a5 60 ff ff ff 	mov    %r12,-0xa0(%rbp)
 129bb82:	48 83 ec 08          	sub    $0x8,%rsp
 129bb86:	48 8d 85 d0 fd ff ff 	lea    -0x230(%rbp),%rax
 129bb8d:	48 8d bd f8 fc ff ff 	lea    -0x308(%rbp),%rdi
 129bb94:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 129bb98:	4c 89 ea             	mov    %r13,%rdx
 129bb9b:	4c 89 f1             	mov    %r14,%rcx
 129bb9e:	4d 89 f8             	mov    %r15,%r8
 129bba1:	4d 89 e1             	mov    %r12,%r9
 129bba4:	50                   	push   %rax
 129bba5:	e8 36 21 f9 ff       	call   122dce0 <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516>
 129bbaa:	48 83 c4 10          	add    $0x10,%rsp
 129bbae:	0f b7 9d 08 fd ff ff 	movzwl -0x2f8(%rbp),%ebx
 129bbb5:	66 85 db             	test   %bx,%bx
 129bbb8:	0f 85 9b 02 00 00    	jne    129be59 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1639>
 129bbbe:	48 8b 9d f8 fc ff ff 	mov    -0x308(%rbp),%rbx
 129bbc5:	4c 8b b5 00 fd ff ff 	mov    -0x300(%rbp),%r14
 129bbcc:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129bbd0:	48 85 c9             	test   %rcx,%rcx
 129bbd3:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 129bbd7:	74 1f                	je     129bbf8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x13d8>
 129bbd9:	49 8b 3f             	mov    (%r15),%rdi
 129bbdc:	49 8b 47 08          	mov    0x8(%r15),%rax
 129bbe0:	48 c1 e1 05          	shl    $0x5,%rcx
 129bbe4:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bbe8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bbec:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129bbf0:	b9 03 00 00 00       	mov    $0x3,%ecx
 129bbf5:	ff 50 18             	call   *0x18(%rax)
 129bbf8:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129bbfc:	48 85 c9             	test   %rcx,%rcx
 129bbff:	74 21                	je     129bc22 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1402>
 129bc01:	49 8b 3f             	mov    (%r15),%rdi
 129bc04:	49 8b 47 08          	mov    0x8(%r15),%rax
 129bc08:	48 01 c9             	add    %rcx,%rcx
 129bc0b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bc0f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bc13:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129bc1a:	b9 01 00 00 00       	mov    $0x1,%ecx
 129bc1f:	ff 50 18             	call   *0x18(%rax)
 129bc22:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 129bc26:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 129bc2c:	48 89 18             	mov    %rbx,(%rax)
 129bc2f:	4c 89 70 08          	mov    %r14,0x8(%rax)
 129bc33:	48 81 c4 28 0c 00 00 	add    $0xc28,%rsp
 129bc3a:	5b                   	pop    %rbx
 129bc3b:	41 5c                	pop    %r12
 129bc3d:	41 5d                	pop    %r13
 129bc3f:	41 5e                	pop    %r14
 129bc41:	41 5f                	pop    %r15
 129bc43:	5d                   	pop    %rbp
 129bc44:	c3                   	ret    
 129bc45:	4d 85 e4             	test   %r12,%r12
 129bc48:	74 1a                	je     129bc64 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1444>
 129bc4a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129bc4e:	48 8b 38             	mov    (%rax),%rdi
 129bc51:	48 8b 40 08          	mov    0x8(%rax),%rax
 129bc55:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bc59:	4c 89 fe             	mov    %r15,%rsi
 129bc5c:	4c 89 e2             	mov    %r12,%rdx
 129bc5f:	31 c9                	xor    %ecx,%ecx
 129bc61:	ff 50 18             	call   *0x18(%rax)
 129bc64:	49 89 dc             	mov    %rbx,%r12
 129bc67:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 129bc6b:	49 81 fe 01 01 00 00 	cmp    $0x101,%r14
 129bc72:	0f 92 c0             	setb   %al
 129bc75:	84 45 84             	test   %al,-0x7c(%rbp)
 129bc78:	0f 85 97 fe ff ff    	jne    129bb15 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x12f5>
 129bc7e:	e9 dd fd ff ff       	jmp    129ba60 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1240>
 129bc83:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 129bc87:	f6 45 ac 01          	testb  $0x1,-0x54(%rbp)
 129bc8b:	0f 85 78 f9 ff ff    	jne    129b609 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xde9>
 129bc91:	e9 6a fa ff ff       	jmp    129b700 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0xee0>
 129bc96:	48 85 db             	test   %rbx,%rbx
 129bc99:	74 17                	je     129bcb2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1492>
 129bc9b:	49 8b 3e             	mov    (%r14),%rdi
 129bc9e:	49 8b 46 08          	mov    0x8(%r14),%rax
 129bca2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bca6:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 129bcaa:	48 89 da             	mov    %rbx,%rdx
 129bcad:	31 c9                	xor    %ecx,%ecx
 129bcaf:	ff 50 18             	call   *0x18(%rax)
 129bcb2:	48 8b 5d b8          	mov    -0x48(%rbp),%rbx
 129bcb6:	e9 77 fb ff ff       	jmp    129b832 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1012>
 129bcbb:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129bcbf:	48 85 d2             	test   %rdx,%rdx
 129bcc2:	74 16                	je     129bcda <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x14ba>
 129bcc4:	49 8b 3c 24          	mov    (%r12),%rdi
 129bcc8:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bccd:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bcd1:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129bcd5:	31 c9                	xor    %ecx,%ecx
 129bcd7:	ff 50 18             	call   *0x18(%rax)
 129bcda:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129bcde:	48 85 c9             	test   %rcx,%rcx
 129bce1:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129bce5:	74 1d                	je     129bd04 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x14e4>
 129bce7:	49 8b 3c 24          	mov    (%r12),%rdi
 129bceb:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bcf0:	48 c1 e1 05          	shl    $0x5,%rcx
 129bcf4:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bcf8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bcfc:	b9 03 00 00 00       	mov    $0x3,%ecx
 129bd01:	ff 50 18             	call   *0x18(%rax)
 129bd04:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129bd08:	48 85 c9             	test   %rcx,%rcx
 129bd0b:	74 23                	je     129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129bd0d:	49 8b 3c 24          	mov    (%r12),%rdi
 129bd11:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bd16:	48 01 c9             	add    %rcx,%rcx
 129bd19:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bd1d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bd21:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129bd28:	b9 01 00 00 00       	mov    $0x1,%ecx
 129bd2d:	ff 50 18             	call   *0x18(%rax)
 129bd30:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 129bd34:	66 89 58 10          	mov    %bx,0x10(%rax)
 129bd38:	e9 f6 fe ff ff       	jmp    129bc33 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1413>
 129bd3d:	4d 85 ed             	test   %r13,%r13
 129bd40:	74 27                	je     129bd69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1549>
 129bd42:	49 8b 3c 24          	mov    (%r12),%rdi
 129bd46:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bd4b:	49 c1 e5 05          	shl    $0x5,%r13
 129bd4f:	4a 8d 14 6d 00 00 00 	lea    0x0(,%r13,2),%rdx
 129bd56:	00 
 129bd57:	4c 01 ea             	add    %r13,%rdx
 129bd5a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bd5e:	48 89 de             	mov    %rbx,%rsi
 129bd61:	b9 03 00 00 00       	mov    $0x3,%ecx
 129bd66:	ff 50 18             	call   *0x18(%rax)
 129bd69:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129bd6d:	48 85 d2             	test   %rdx,%rdx
 129bd70:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129bd74:	74 12                	je     129bd88 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1568>
 129bd76:	49 8b 3c 24          	mov    (%r12),%rdi
 129bd7a:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bd7f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bd83:	31 c9                	xor    %ecx,%ecx
 129bd85:	ff 50 18             	call   *0x18(%rax)
 129bd88:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129bd8c:	48 85 c9             	test   %rcx,%rcx
 129bd8f:	48 8b 5d 98          	mov    -0x68(%rbp),%rbx
 129bd93:	74 21                	je     129bdb6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1596>
 129bd95:	49 8b 3c 24          	mov    (%r12),%rdi
 129bd99:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bd9e:	48 c1 e1 05          	shl    $0x5,%rcx
 129bda2:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bda6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bdaa:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129bdae:	b9 03 00 00 00       	mov    $0x3,%ecx
 129bdb3:	ff 50 18             	call   *0x18(%rax)
 129bdb6:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129bdba:	48 85 c9             	test   %rcx,%rcx
 129bdbd:	74 23                	je     129bde2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x15c2>
 129bdbf:	49 8b 3c 24          	mov    (%r12),%rdi
 129bdc3:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bdc8:	48 01 c9             	add    %rcx,%rcx
 129bdcb:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bdcf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bdd3:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129bdda:	b9 01 00 00 00       	mov    $0x1,%ecx
 129bddf:	ff 50 18             	call   *0x18(%rax)
 129bde2:	66 44 89 73 10       	mov    %r14w,0x10(%rbx)
 129bde7:	e9 47 fe ff ff       	jmp    129bc33 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1413>
 129bdec:	66 89 43 10          	mov    %ax,0x10(%rbx)
 129bdf0:	e9 3e fe ff ff       	jmp    129bc33 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1413>
 129bdf5:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129bdf9:	48 85 c9             	test   %rcx,%rcx
 129bdfc:	74 23                	je     129be21 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1601>
 129bdfe:	49 8b 3c 24          	mov    (%r12),%rdi
 129be02:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129be07:	48 01 c9             	add    %rcx,%rcx
 129be0a:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129be0e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129be12:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129be19:	b9 01 00 00 00       	mov    $0x1,%ecx
 129be1e:	ff 50 18             	call   *0x18(%rax)
 129be21:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129be25:	48 85 f6             	test   %rsi,%rsi
 129be28:	0f 94 c0             	sete   %al
 129be2b:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129be2f:	48 85 d2             	test   %rdx,%rdx
 129be32:	0f 94 c1             	sete   %cl
 129be35:	08 c1                	or     %al,%cl
 129be37:	75 12                	jne    129be4b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x162b>
 129be39:	49 8b 3c 24          	mov    (%r12),%rdi
 129be3d:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129be42:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129be46:	31 c9                	xor    %ecx,%ecx
 129be48:	ff 50 18             	call   *0x18(%rax)
 129be4b:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 129be4f:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 129be54:	e9 da fd ff ff       	jmp    129bc33 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1413>
 129be59:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129be5d:	48 85 c9             	test   %rcx,%rcx
 129be60:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 129be64:	74 1f                	je     129be85 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1665>
 129be66:	49 8b 3e             	mov    (%r14),%rdi
 129be69:	49 8b 46 08          	mov    0x8(%r14),%rax
 129be6d:	48 c1 e1 05          	shl    $0x5,%rcx
 129be71:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129be75:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129be79:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129be7d:	b9 03 00 00 00       	mov    $0x3,%ecx
 129be82:	ff 50 18             	call   *0x18(%rax)
 129be85:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129be89:	48 85 c9             	test   %rcx,%rcx
 129be8c:	0f 84 9e fe ff ff    	je     129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129be92:	49 8b 3e             	mov    (%r14),%rdi
 129be95:	49 8b 46 08          	mov    0x8(%r14),%rax
 129be99:	e9 78 fe ff ff       	jmp    129bd16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x14f6>
 129be9e:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129bea2:	48 85 c9             	test   %rcx,%rcx
 129bea5:	74 20                	je     129bec7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x16a7>
 129bea7:	49 8b 3c 24          	mov    (%r12),%rdi
 129beab:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129beb0:	48 c1 e1 05          	shl    $0x5,%rcx
 129beb4:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129beb8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bebc:	4c 89 f6             	mov    %r14,%rsi
 129bebf:	b9 03 00 00 00       	mov    $0x3,%ecx
 129bec4:	ff 50 18             	call   *0x18(%rax)
 129bec7:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129becb:	48 85 c9             	test   %rcx,%rcx
 129bece:	74 23                	je     129bef3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x16d3>
 129bed0:	49 8b 3c 24          	mov    (%r12),%rdi
 129bed4:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bed9:	48 01 c9             	add    %rcx,%rcx
 129bedc:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bee0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bee4:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129beeb:	b9 01 00 00 00       	mov    $0x1,%ecx
 129bef0:	ff 50 18             	call   *0x18(%rax)
 129bef3:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129bef7:	48 85 f6             	test   %rsi,%rsi
 129befa:	0f 94 c0             	sete   %al
 129befd:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129bf01:	48 85 d2             	test   %rdx,%rdx
 129bf04:	0f 94 c1             	sete   %cl
 129bf07:	08 c1                	or     %al,%cl
 129bf09:	0f 85 21 fe ff ff    	jne    129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129bf0f:	49 8b 3c 24          	mov    (%r12),%rdi
 129bf13:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129bf18:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bf1c:	e9 ce 01 00 00       	jmp    129c0ef <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x18cf>
 129bf21:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129bf25:	48 85 d2             	test   %rdx,%rdx
 129bf28:	74 35                	je     129bf5f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x173f>
 129bf2a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129bf2e:	48 8b 38             	mov    (%rax),%rdi
 129bf31:	48 8b 40 08          	mov    0x8(%rax),%rax
 129bf35:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bf39:	4c 89 fe             	mov    %r15,%rsi
 129bf3c:	eb 1c                	jmp    129bf5a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x173a>
 129bf3e:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129bf42:	48 85 d2             	test   %rdx,%rdx
 129bf45:	74 18                	je     129bf5f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x173f>
 129bf47:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129bf4b:	48 8b 38             	mov    (%rax),%rdi
 129bf4e:	48 8b 40 08          	mov    0x8(%rax),%rax
 129bf52:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bf56:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129bf5a:	31 c9                	xor    %ecx,%ecx
 129bf5c:	ff 50 18             	call   *0x18(%rax)
 129bf5f:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129bf63:	48 85 c9             	test   %rcx,%rcx
 129bf66:	74 23                	je     129bf8b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x176b>
 129bf68:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129bf6c:	48 8b 38             	mov    (%rax),%rdi
 129bf6f:	48 8b 40 08          	mov    0x8(%rax),%rax
 129bf73:	48 c1 e1 05          	shl    $0x5,%rcx
 129bf77:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bf7b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bf7f:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129bf83:	b9 03 00 00 00       	mov    $0x3,%ecx
 129bf88:	ff 50 18             	call   *0x18(%rax)
 129bf8b:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129bf8f:	48 85 c9             	test   %rcx,%rcx
 129bf92:	0f 84 98 fd ff ff    	je     129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129bf98:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129bf9c:	48 8b 38             	mov    (%rax),%rdi
 129bf9f:	48 8b 40 08          	mov    0x8(%rax),%rax
 129bfa3:	e9 6e fd ff ff       	jmp    129bd16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x14f6>
 129bfa8:	45 31 ff             	xor    %r15d,%r15d
 129bfab:	41 bc 00 00 00 00    	mov    $0x0,%r12d
 129bfb1:	41 83 fe 52          	cmp    $0x52,%r14d
 129bfb5:	0f 84 53 fa ff ff    	je     129ba0e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x11ee>
 129bfbb:	48 85 db             	test   %rbx,%rbx
 129bfbe:	74 1b                	je     129bfdb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x17bb>
 129bfc0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129bfc4:	48 8b 38             	mov    (%rax),%rdi
 129bfc7:	48 8b 40 08          	mov    0x8(%rax),%rax
 129bfcb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bfcf:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 129bfd3:	48 89 da             	mov    %rbx,%rdx
 129bfd6:	31 c9                	xor    %ecx,%ecx
 129bfd8:	ff 50 18             	call   *0x18(%rax)
 129bfdb:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 129bfe0:	74 27                	je     129c009 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x17e9>
 129bfe2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129bfe6:	48 8b 38             	mov    (%rax),%rdi
 129bfe9:	48 8b 40 08          	mov    0x8(%rax),%rax
 129bfed:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129bff1:	48 c1 e1 05          	shl    $0x5,%rcx
 129bff5:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129bff9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129bffd:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129c001:	b9 03 00 00 00       	mov    $0x3,%ecx
 129c006:	ff 50 18             	call   *0x18(%rax)
 129c009:	48 83 7d 90 00       	cmpq   $0x0,-0x70(%rbp)
 129c00e:	74 29                	je     129c039 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1819>
 129c010:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129c014:	48 8b 38             	mov    (%rax),%rdi
 129c017:	48 8b 40 08          	mov    0x8(%rax),%rax
 129c01b:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129c01f:	48 01 c9             	add    %rcx,%rcx
 129c022:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129c026:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129c02a:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129c031:	b9 01 00 00 00       	mov    $0x1,%ecx
 129c036:	ff 50 18             	call   *0x18(%rax)
 129c039:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 129c03d:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 129c042:	e9 ec fb ff ff       	jmp    129bc33 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1413>
 129c047:	89 c3                	mov    %eax,%ebx
 129c049:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 129c04e:	0f 94 c0             	sete   %al
 129c051:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 129c056:	0f 94 c1             	sete   %cl
 129c059:	08 c1                	or     %al,%cl
 129c05b:	80 f9 01             	cmp    $0x1,%cl
 129c05e:	0f 84 cc fc ff ff    	je     129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129c064:	eb 72                	jmp    129c0d8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x18b8>
 129c066:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 129c06b:	74 25                	je     129c092 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1872>
 129c06d:	49 8b 3c 24          	mov    (%r12),%rdi
 129c071:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129c076:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129c07a:	48 c1 e1 05          	shl    $0x5,%rcx
 129c07e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129c082:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129c086:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129c08a:	b9 03 00 00 00       	mov    $0x3,%ecx
 129c08f:	ff 50 18             	call   *0x18(%rax)
 129c092:	48 83 7d 90 00       	cmpq   $0x0,-0x70(%rbp)
 129c097:	74 27                	je     129c0c0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x18a0>
 129c099:	49 8b 3c 24          	mov    (%r12),%rdi
 129c09d:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 129c0a2:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129c0a6:	48 01 c9             	add    %rcx,%rcx
 129c0a9:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129c0ad:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129c0b1:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129c0b8:	b9 01 00 00 00       	mov    $0x1,%ecx
 129c0bd:	ff 50 18             	call   *0x18(%rax)
 129c0c0:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 129c0c5:	0f 94 c0             	sete   %al
 129c0c8:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 129c0cd:	0f 94 c1             	sete   %cl
 129c0d0:	08 c1                	or     %al,%cl
 129c0d2:	0f 85 58 fc ff ff    	jne    129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129c0d8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129c0dc:	48 8b 38             	mov    (%rax),%rdi
 129c0df:	48 8b 40 08          	mov    0x8(%rax),%rax
 129c0e3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129c0e7:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 129c0eb:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129c0ef:	31 c9                	xor    %ecx,%ecx
 129c0f1:	e9 37 fc ff ff       	jmp    129bd2d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x150d>
 129c0f6:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 129c0fb:	74 41                	je     129c13e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x191e>
 129c0fd:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129c101:	48 8b 38             	mov    (%rax),%rdi
 129c104:	48 8b 40 08          	mov    0x8(%rax),%rax
 129c108:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129c10c:	4c 89 fe             	mov    %r15,%rsi
 129c10f:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 129c113:	eb 24                	jmp    129c139 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1919>
 129c115:	89 c3                	mov    %eax,%ebx
 129c117:	48 8b 95 60 ff ff ff 	mov    -0xa0(%rbp),%rdx
 129c11e:	48 85 d2             	test   %rdx,%rdx
 129c121:	74 1b                	je     129c13e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x191e>
 129c123:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 129c12a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129c12e:	48 8b 38             	mov    (%rax),%rdi
 129c131:	48 8b 40 08          	mov    0x8(%rax),%rax
 129c135:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129c139:	31 c9                	xor    %ecx,%ecx
 129c13b:	ff 50 18             	call   *0x18(%rax)
 129c13e:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 129c143:	74 27                	je     129c16c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x194c>
 129c145:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129c149:	48 8b 38             	mov    (%rax),%rdi
 129c14c:	48 8b 40 08          	mov    0x8(%rax),%rax
 129c150:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 129c154:	48 c1 e1 05          	shl    $0x5,%rcx
 129c158:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129c15c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129c160:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129c164:	b9 03 00 00 00       	mov    $0x3,%ecx
 129c169:	ff 50 18             	call   *0x18(%rax)
 129c16c:	48 83 7d 90 00       	cmpq   $0x0,-0x70(%rbp)
 129c171:	0f 84 b9 fb ff ff    	je     129bd30 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x1510>
 129c177:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129c17b:	48 8b 38             	mov    (%rax),%rdi
 129c17e:	48 8b 40 08          	mov    0x8(%rax),%rax
 129c182:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 129c186:	e9 8b fb ff ff       	jmp    129bd16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x14f6>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
