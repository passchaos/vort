
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>:
 1244860:	55                   	push   %rbp
 1244861:	48 89 e5             	mov    %rsp,%rbp
 1244864:	41 57                	push   %r15
 1244866:	41 56                	push   %r14
 1244868:	41 55                	push   %r13
 124486a:	41 54                	push   %r12
 124486c:	53                   	push   %rbx
 124486d:	48 81 ec 48 0b 00 00 	sub    $0xb48,%rsp
 1244874:	4c 89 4d 80          	mov    %r9,-0x80(%rbp)
 1244878:	4c 89 45 88          	mov    %r8,-0x78(%rbp)
 124487c:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 1244880:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 1244884:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 1244888:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 124488c:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1244890:	48 8b 08             	mov    (%rax),%rcx
 1244893:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 1244897:	48 8b 48 08          	mov    0x8(%rax),%rcx
 124489b:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 124489f:	48 8b 48 10          	mov    0x10(%rax),%rcx
 12448a3:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 12448a7:	48 8b 48 18          	mov    0x18(%rax),%rcx
 12448ab:	48 89 4d a8          	mov    %rcx,-0x58(%rbp)
 12448af:	c5 fc 10 40 20       	vmovups 0x20(%rax),%ymm0
 12448b4:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 12448bb:	ff 
 12448bc:	44 0f b6 68 40       	movzbl 0x40(%rax),%r13d
 12448c1:	44 88 6d d0          	mov    %r13b,-0x30(%rbp)
 12448c5:	0f b6 48 4e          	movzbl 0x4e(%rax),%ecx
 12448c9:	88 4d d7             	mov    %cl,-0x29(%rbp)
 12448cc:	4c 8d 60 20          	lea    0x20(%rax),%r12
 12448d0:	4c 8b 7d 28          	mov    0x28(%rbp),%r15
 12448d4:	48 8b 5d 20          	mov    0x20(%rbp),%rbx
 12448d8:	4c 8b 75 10          	mov    0x10(%rbp),%r14
 12448dc:	48 8d bd 98 f4 ff ff 	lea    -0xb68(%rbp),%rdi
 12448e3:	ba 60 01 00 00       	mov    $0x160,%edx
 12448e8:	48 89 de             	mov    %rbx,%rsi
 12448eb:	c5 f8 77             	vzeroupper 
 12448ee:	e8 6d ae 09 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 12448f3:	c4 c1 7c 10 46 70    	vmovups 0x70(%r14),%ymm0
 12448f9:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 1244900:	ff 
 1244901:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 1244906:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 124490c:	c4 c1 7c 10 56 40    	vmovups 0x40(%r14),%ymm2
 1244912:	c4 c1 7c 10 5e 60    	vmovups 0x60(%r14),%ymm3
 1244918:	c5 fc 11 9d 70 fe ff 	vmovups %ymm3,-0x190(%rbp)
 124491f:	ff 
 1244920:	c5 fc 11 95 50 fe ff 	vmovups %ymm2,-0x1b0(%rbp)
 1244927:	ff 
 1244928:	c5 fc 11 8d 30 fe ff 	vmovups %ymm1,-0x1d0(%rbp)
 124492f:	ff 
 1244930:	c5 fc 11 85 10 fe ff 	vmovups %ymm0,-0x1f0(%rbp)
 1244937:	ff 
 1244938:	c4 c1 7c 10 46 70    	vmovups 0x70(%r14),%ymm0
 124493e:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 1244945:	ff 
 1244946:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 124494b:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 1244951:	c4 c1 7c 10 56 40    	vmovups 0x40(%r14),%ymm2
 1244957:	c4 c1 7c 10 5e 60    	vmovups 0x60(%r14),%ymm3
 124495d:	4c 8b 75 30          	mov    0x30(%rbp),%r14
 1244961:	c5 fc 11 9d 00 ff ff 	vmovups %ymm3,-0x100(%rbp)
 1244968:	ff 
 1244969:	c5 fc 11 95 e0 fe ff 	vmovups %ymm2,-0x120(%rbp)
 1244970:	ff 
 1244971:	c5 fc 11 8d c0 fe ff 	vmovups %ymm1,-0x140(%rbp)
 1244978:	ff 
 1244979:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1244980:	ff 
 1244981:	41 80 7f 68 00       	cmpb   $0x0,0x68(%r15)
 1244986:	0f b6 85 f0 f5 ff ff 	movzbl -0xa10(%rbp),%eax
 124498d:	0f 94 c2             	sete   %dl
 1244990:	4d 85 f6             	test   %r14,%r14
 1244993:	40 0f 94 c6          	sete   %sil
 1244997:	b9 30 ad 03 01       	mov    $0x103ad30,%ecx
 124499c:	40 84 f2             	test   %sil,%dl
 124499f:	74 2e                	je     12449cf <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x16f>
 12449a1:	c5 fc 10 43 10       	vmovups 0x10(%rbx),%ymm0
 12449a6:	c5 fc 10 4b 30       	vmovups 0x30(%rbx),%ymm1
 12449ab:	c5 fc 10 53 48       	vmovups 0x48(%rbx),%ymm2
 12449b0:	c5 fc 11 95 58 f8 ff 	vmovups %ymm2,-0x7a8(%rbp)
 12449b7:	ff 
 12449b8:	c5 fc 11 8d 40 f8 ff 	vmovups %ymm1,-0x7c0(%rbp)
 12449bf:	ff 
 12449c0:	c5 fc 11 85 20 f8 ff 	vmovups %ymm0,-0x7e0(%rbp)
 12449c7:	ff 
 12449c8:	48 8d 8d 20 f8 ff ff 	lea    -0x7e0(%rbp),%rcx
 12449cf:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 12449d5:	c5 fc 10 09          	vmovups (%rcx),%ymm1
 12449d9:	c5 fc 10 51 20       	vmovups 0x20(%rcx),%ymm2
 12449de:	c5 fc 10 59 38       	vmovups 0x38(%rcx),%ymm3
 12449e3:	c5 fc 11 85 c8 fa ff 	vmovups %ymm0,-0x538(%rbp)
 12449ea:	ff 
 12449eb:	41 80 e5 01          	and    $0x1,%r13b
 12449ef:	44 88 ad c9 fc ff ff 	mov    %r13b,-0x337(%rbp)
 12449f6:	48 c7 85 b8 fa ff ff 	movq   $0x0,-0x548(%rbp)
 12449fd:	00 00 00 00 
 1244a01:	24 01                	and    $0x1,%al
 1244a03:	88 85 cd fc ff ff    	mov    %al,-0x333(%rbp)
 1244a09:	c6 85 cc fc ff ff 00 	movb   $0x0,-0x334(%rbp)
 1244a10:	c5 fc 11 8d e8 fa ff 	vmovups %ymm1,-0x518(%rbp)
 1244a17:	ff 
 1244a18:	c5 fc 11 95 08 fb ff 	vmovups %ymm2,-0x4f8(%rbp)
 1244a1f:	ff 
 1244a20:	c5 fc 11 9d 20 fb ff 	vmovups %ymm3,-0x4e0(%rbp)
 1244a27:	ff 
 1244a28:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1244a2d:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1244a33:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 1244a39:	c4 c1 7c 10 5f 50    	vmovups 0x50(%r15),%ymm3
 1244a3f:	c5 fc 11 85 40 fb ff 	vmovups %ymm0,-0x4c0(%rbp)
 1244a46:	ff 
 1244a47:	c5 fc 11 8d 60 fb ff 	vmovups %ymm1,-0x4a0(%rbp)
 1244a4e:	ff 
 1244a4f:	c5 fc 11 95 80 fb ff 	vmovups %ymm2,-0x480(%rbp)
 1244a56:	ff 
 1244a57:	c5 fc 11 9d 90 fb ff 	vmovups %ymm3,-0x470(%rbp)
 1244a5e:	ff 
 1244a5f:	4c 89 b5 b0 fb ff ff 	mov    %r14,-0x450(%rbp)
 1244a66:	48 8b 45 38          	mov    0x38(%rbp),%rax
 1244a6a:	48 89 85 b8 fb ff ff 	mov    %rax,-0x448(%rbp)
 1244a71:	48 8b 45 40          	mov    0x40(%rbp),%rax
 1244a75:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1244a79:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1244a7e:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1244a83:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1244a88:	c5 fc 11 85 c0 fb ff 	vmovups %ymm0,-0x440(%rbp)
 1244a8f:	ff 
 1244a90:	c5 fc 11 8d e0 fb ff 	vmovups %ymm1,-0x420(%rbp)
 1244a97:	ff 
 1244a98:	c5 fc 11 95 00 fc ff 	vmovups %ymm2,-0x400(%rbp)
 1244a9f:	ff 
 1244aa0:	c5 fc 11 9d 10 fc ff 	vmovups %ymm3,-0x3f0(%rbp)
 1244aa7:	ff 
 1244aa8:	48 8b 45 48          	mov    0x48(%rbp),%rax
 1244aac:	48 89 85 30 fc ff ff 	mov    %rax,-0x3d0(%rbp)
 1244ab3:	48 8b 45 50          	mov    0x50(%rbp),%rax
 1244ab7:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1244abb:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1244ac0:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1244ac5:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1244aca:	c5 fc 11 9d 88 fc ff 	vmovups %ymm3,-0x378(%rbp)
 1244ad1:	ff 
 1244ad2:	c5 fc 11 95 78 fc ff 	vmovups %ymm2,-0x388(%rbp)
 1244ad9:	ff 
 1244ada:	c5 fc 11 8d 58 fc ff 	vmovups %ymm1,-0x3a8(%rbp)
 1244ae1:	ff 
 1244ae2:	c5 fc 11 85 38 fc ff 	vmovups %ymm0,-0x3c8(%rbp)
 1244ae9:	ff 
 1244aea:	48 8b 45 58          	mov    0x58(%rbp),%rax
 1244aee:	48 89 85 a8 fc ff ff 	mov    %rax,-0x358(%rbp)
 1244af5:	c6 85 c0 fc ff ff 38 	movb   $0x38,-0x340(%rbp)
 1244afc:	c6 85 c8 fc ff ff 00 	movb   $0x0,-0x338(%rbp)
 1244b03:	0f b7 05 26 64 df ff 	movzwl -0x209bda(%rip),%eax        # 103af30 <__anon_29470>
 1244b0a:	66 89 85 c2 fc ff ff 	mov    %ax,-0x33e(%rbp)
 1244b11:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 1244b15:	24 1f                	and    $0x1f,%al
 1244b17:	88 45 d7             	mov    %al,-0x29(%rbp)
 1244b1a:	88 85 c1 fc ff ff    	mov    %al,-0x33f(%rbp)
 1244b20:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1244b24:	48 89 85 a8 fa ff ff 	mov    %rax,-0x558(%rbp)
 1244b2b:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1244b2f:	48 89 85 b0 fa ff ff 	mov    %rax,-0x550(%rbp)
 1244b36:	c7 85 c4 fc ff ff 01 	movl   $0x1000101,-0x33c(%rbp)
 1244b3d:	01 00 01 
 1244b40:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 1244b44:	48 89 85 b8 fc ff ff 	mov    %rax,-0x348(%rbp)
 1244b4b:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 1244b4f:	48 89 85 b0 fc ff ff 	mov    %rax,-0x350(%rbp)
 1244b56:	66 c7 85 ca fc ff ff 	movw   $0x0,-0x336(%rbp)
 1244b5d:	00 00 
 1244b5f:	48 c7 85 c0 fa ff ff 	movq   $0x0,-0x540(%rbp)
 1244b66:	00 00 00 00 
 1244b6a:	48 8d 85 a8 fa ff ff 	lea    -0x558(%rbp),%rax
 1244b71:	4c 8d 95 a0 fe ff ff 	lea    -0x160(%rbp),%r10
 1244b78:	48 8d bd 60 ff ff ff 	lea    -0xa0(%rbp),%rdi
 1244b7f:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 1244b83:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 1244b87:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 1244b8b:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 1244b8f:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 1244b93:	50                   	push   %rax
 1244b94:	41 52                	push   %r10
 1244b96:	c5 f8 77             	vzeroupper 
 1244b99:	e8 82 25 f7 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 1244b9e:	48 83 c4 10          	add    $0x10,%rsp
 1244ba2:	0f b7 85 70 ff ff ff 	movzwl -0x90(%rbp),%eax
 1244ba9:	66 85 c0             	test   %ax,%ax
 1244bac:	0f 85 98 06 00 00    	jne    124524a <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x9ea>
 1244bb2:	4d 85 f6             	test   %r14,%r14
 1244bb5:	0f 94 c0             	sete   %al
 1244bb8:	4c 8b a5 60 ff ff ff 	mov    -0xa0(%rbp),%r12
 1244bbf:	4c 8b ad 68 ff ff ff 	mov    -0x98(%rbp),%r13
 1244bc6:	41 80 7f 68 00       	cmpb   $0x0,0x68(%r15)
 1244bcb:	0f 94 c1             	sete   %cl
 1244bce:	84 c1                	test   %al,%cl
 1244bd0:	0f 84 e0 05 00 00    	je     12451b6 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x956>
 1244bd6:	0f b6 85 f1 f5 ff ff 	movzbl -0xa0f(%rbp),%eax
 1244bdd:	48 83 e0 03          	and    $0x3,%rax
 1244be1:	0f 84 0f 03 00 00    	je     1244ef6 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x696>
 1244be7:	4c 8d b5 38 f6 ff ff 	lea    -0x9c8(%rbp),%r14
 1244bee:	c1 e0 04             	shl    $0x4,%eax
 1244bf1:	48 8d 04 80          	lea    (%rax,%rax,4),%rax
 1244bf5:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 1244bfc:	31 db                	xor    %ebx,%ebx
 1244bfe:	e9 97 00 00 00       	jmp    1244c9a <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x43a>
 1244c03:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1244c0a:	84 00 00 00 00 00 
 1244c10:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1244c14:	48 8b 38             	mov    (%rax),%rdi
 1244c17:	48 8b 40 08          	mov    0x8(%rax),%rax
 1244c1b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1244c1f:	4c 89 e1             	mov    %r12,%rcx
 1244c22:	49 89 f4             	mov    %rsi,%r12
 1244c25:	48 89 ce             	mov    %rcx,%rsi
 1244c28:	4c 89 ea             	mov    %r13,%rdx
 1244c2b:	31 c9                	xor    %ecx,%ecx
 1244c2d:	ff 50 18             	call   *0x18(%rax)
 1244c30:	4c 89 e0             	mov    %r12,%rax
 1244c33:	c5 fc 10 85 d0 fd ff 	vmovups -0x230(%rbp),%ymm0
 1244c3a:	ff 
 1244c3b:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 1244c42:	ff 
 1244c43:	c5 fc 10 85 60 fd ff 	vmovups -0x2a0(%rbp),%ymm0
 1244c4a:	ff 
 1244c4b:	c5 fc 10 8d 80 fd ff 	vmovups -0x280(%rbp),%ymm1
 1244c52:	ff 
 1244c53:	c5 fc 10 95 a0 fd ff 	vmovups -0x260(%rbp),%ymm2
 1244c5a:	ff 
 1244c5b:	c5 fc 10 9d c0 fd ff 	vmovups -0x240(%rbp),%ymm3
 1244c62:	ff 
 1244c63:	c5 fc 11 9d 00 ff ff 	vmovups %ymm3,-0x100(%rbp)
 1244c6a:	ff 
 1244c6b:	c5 fc 11 95 e0 fe ff 	vmovups %ymm2,-0x120(%rbp)
 1244c72:	ff 
 1244c73:	c5 fc 11 8d c0 fe ff 	vmovups %ymm1,-0x140(%rbp)
 1244c7a:	ff 
 1244c7b:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1244c82:	ff 
 1244c83:	48 83 c3 50          	add    $0x50,%rbx
 1244c87:	4d 89 fd             	mov    %r15,%r13
 1244c8a:	49 89 c4             	mov    %rax,%r12
 1244c8d:	48 39 9d 78 ff ff ff 	cmp    %rbx,-0x88(%rbp)
 1244c94:	0f 84 62 02 00 00    	je     1244efc <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x69c>
 1244c9a:	48 8d 85 00 f5 ff ff 	lea    -0xb00(%rbp),%rax
 1244ca1:	c5 fc 10 04 18       	vmovups (%rax,%rbx,1),%ymm0
 1244ca6:	c5 fc 10 4c 18 20    	vmovups 0x20(%rax,%rbx,1),%ymm1
 1244cac:	c5 fc 10 54 18 30    	vmovups 0x30(%rax,%rbx,1),%ymm2
 1244cb2:	c4 c1 7c 11 56 30    	vmovups %ymm2,0x30(%r14)
 1244cb8:	c4 c1 7c 11 4e 20    	vmovups %ymm1,0x20(%r14)
 1244cbe:	c4 c1 7c 11 06       	vmovups %ymm0,(%r14)
 1244cc3:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 1244cc7:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 1244cce:	ff 
 1244ccf:	c4 c1 7c 11 46 e0    	vmovups %ymm0,-0x20(%r14)
 1244cd5:	88 85 19 f8 ff ff    	mov    %al,-0x7e7(%rbp)
 1244cdb:	0f b6 85 f0 f5 ff ff 	movzbl -0xa10(%rbp),%eax
 1244ce2:	48 c7 85 08 f6 ff ff 	movq   $0x0,-0x9f8(%rbp)
 1244ce9:	00 00 00 00 
 1244ced:	88 85 1d f8 ff ff    	mov    %al,-0x7e3(%rbp)
 1244cf3:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1244cfa:	ff 
 1244cfb:	c5 fc 11 85 d0 fd ff 	vmovups %ymm0,-0x230(%rbp)
 1244d02:	ff 
 1244d03:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 1244d0a:	ff 
 1244d0b:	c5 fc 10 8d 30 fe ff 	vmovups -0x1d0(%rbp),%ymm1
 1244d12:	ff 
 1244d13:	c5 fc 10 95 50 fe ff 	vmovups -0x1b0(%rbp),%ymm2
 1244d1a:	ff 
 1244d1b:	c5 fc 10 9d 70 fe ff 	vmovups -0x190(%rbp),%ymm3
 1244d22:	ff 
 1244d23:	c5 fc 11 9d c0 fd ff 	vmovups %ymm3,-0x240(%rbp)
 1244d2a:	ff 
 1244d2b:	c5 fc 11 95 a0 fd ff 	vmovups %ymm2,-0x260(%rbp)
 1244d32:	ff 
 1244d33:	c5 fc 11 8d 80 fd ff 	vmovups %ymm1,-0x280(%rbp)
 1244d3a:	ff 
 1244d3b:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 1244d42:	ff 
 1244d43:	c6 85 1c f8 ff ff 00 	movb   $0x0,-0x7e4(%rbp)
 1244d4a:	c6 85 88 f6 ff ff 01 	movb   $0x1,-0x978(%rbp)
 1244d51:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1244d55:	c4 c1 7c 11 86 b8 00 	vmovups %ymm0,0xb8(%r14)
 1244d5c:	00 00 
 1244d5e:	c4 c1 7c 11 86 98 00 	vmovups %ymm0,0x98(%r14)
 1244d65:	00 00 
 1244d67:	c4 c1 7c 11 46 78    	vmovups %ymm0,0x78(%r14)
 1244d6d:	c4 c1 7c 11 46 58    	vmovups %ymm0,0x58(%r14)
 1244d73:	48 8b 45 40          	mov    0x40(%rbp),%rax
 1244d77:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1244d7b:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1244d80:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1244d85:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1244d8a:	c4 c1 7c 11 9e 28 01 	vmovups %ymm3,0x128(%r14)
 1244d91:	00 00 
 1244d93:	c4 c1 7c 11 96 18 01 	vmovups %ymm2,0x118(%r14)
 1244d9a:	00 00 
 1244d9c:	c4 c1 7c 11 8e f8 00 	vmovups %ymm1,0xf8(%r14)
 1244da3:	00 00 
 1244da5:	c4 c1 7c 11 86 d8 00 	vmovups %ymm0,0xd8(%r14)
 1244dac:	00 00 
 1244dae:	48 8b 45 48          	mov    0x48(%rbp),%rax
 1244db2:	48 89 85 80 f7 ff ff 	mov    %rax,-0x880(%rbp)
 1244db9:	48 8b 45 50          	mov    0x50(%rbp),%rax
 1244dbd:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1244dc1:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1244dc6:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1244dcb:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1244dd0:	c4 c1 7c 11 9e a0 01 	vmovups %ymm3,0x1a0(%r14)
 1244dd7:	00 00 
 1244dd9:	c4 c1 7c 11 96 90 01 	vmovups %ymm2,0x190(%r14)
 1244de0:	00 00 
 1244de2:	c4 c1 7c 11 8e 70 01 	vmovups %ymm1,0x170(%r14)
 1244de9:	00 00 
 1244deb:	c4 c1 7c 11 86 50 01 	vmovups %ymm0,0x150(%r14)
 1244df2:	00 00 
 1244df4:	48 8b 45 58          	mov    0x58(%rbp),%rax
 1244df8:	48 89 85 f8 f7 ff ff 	mov    %rax,-0x808(%rbp)
 1244dff:	c6 85 10 f8 ff ff 38 	movb   $0x38,-0x7f0(%rbp)
 1244e06:	c6 85 18 f8 ff ff 00 	movb   $0x0,-0x7e8(%rbp)
 1244e0d:	0f b7 05 1c 61 df ff 	movzwl -0x209ee4(%rip),%eax        # 103af30 <__anon_29470>
 1244e14:	66 89 85 12 f8 ff ff 	mov    %ax,-0x7ee(%rbp)
 1244e1b:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 1244e1f:	88 85 11 f8 ff ff    	mov    %al,-0x7ef(%rbp)
 1244e25:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1244e29:	48 89 85 f8 f5 ff ff 	mov    %rax,-0xa08(%rbp)
 1244e30:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1244e34:	48 89 85 00 f6 ff ff 	mov    %rax,-0xa00(%rbp)
 1244e3b:	c7 85 14 f8 ff ff 01 	movl   $0x1000101,-0x7ec(%rbp)
 1244e42:	01 00 01 
 1244e45:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 1244e49:	48 89 85 08 f8 ff ff 	mov    %rax,-0x7f8(%rbp)
 1244e50:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 1244e54:	48 89 85 00 f8 ff ff 	mov    %rax,-0x800(%rbp)
 1244e5b:	66 c7 85 1a f8 ff ff 	movw   $0x0,-0x7e6(%rbp)
 1244e62:	00 00 
 1244e64:	48 c7 85 10 f6 ff ff 	movq   $0x0,-0x9f0(%rbp)
 1244e6b:	00 00 00 00 
 1244e6f:	48 8d bd 48 ff ff ff 	lea    -0xb8(%rbp),%rdi
 1244e76:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 1244e7a:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 1244e7e:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 1244e82:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 1244e86:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 1244e8a:	48 8d 85 f8 f5 ff ff 	lea    -0xa08(%rbp),%rax
 1244e91:	50                   	push   %rax
 1244e92:	48 8d 85 60 fd ff ff 	lea    -0x2a0(%rbp),%rax
 1244e99:	50                   	push   %rax
 1244e9a:	c5 f8 77             	vzeroupper 
 1244e9d:	e8 7e 22 f7 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 1244ea2:	48 83 c4 10          	add    $0x10,%rsp
 1244ea6:	44 0f b7 bd 58 ff ff 	movzwl -0xa8(%rbp),%r15d
 1244ead:	ff 
 1244eae:	66 45 85 ff          	test   %r15w,%r15w
 1244eb2:	0f 85 68 03 00 00    	jne    1245220 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x9c0>
 1244eb8:	48 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%rsi
 1244ebf:	4c 8b bd 50 ff ff ff 	mov    -0xb0(%rbp),%r15
 1244ec6:	4d 39 ef             	cmp    %r13,%r15
 1244ec9:	0f 82 41 fd ff ff    	jb     1244c10 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x3b0>
 1244ecf:	4d 85 ff             	test   %r15,%r15
 1244ed2:	74 17                	je     1244eeb <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x68b>
 1244ed4:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1244ed8:	48 8b 38             	mov    (%rax),%rdi
 1244edb:	48 8b 40 08          	mov    0x8(%rax),%rax
 1244edf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1244ee3:	4c 89 fa             	mov    %r15,%rdx
 1244ee6:	31 c9                	xor    %ecx,%ecx
 1244ee8:	ff 50 18             	call   *0x18(%rax)
 1244eeb:	4c 89 e0             	mov    %r12,%rax
 1244eee:	4d 89 ef             	mov    %r13,%r15
 1244ef1:	e9 8d fd ff ff       	jmp    1244c83 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x423>
 1244ef6:	4c 89 e0             	mov    %r12,%rax
 1244ef9:	4d 89 ef             	mov    %r13,%r15
 1244efc:	80 bd f2 f5 ff ff 00 	cmpb   $0x0,-0xa0e(%rbp)
 1244f03:	0f 84 83 02 00 00    	je     124518c <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x92c>
 1244f09:	49 89 c6             	mov    %rax,%r14
 1244f0c:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1244f13:	ff 
 1244f14:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 1244f1b:	ff 
 1244f1c:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 1244f23:	ff 
 1244f24:	c5 fc 10 8d 30 fe ff 	vmovups -0x1d0(%rbp),%ymm1
 1244f2b:	ff 
 1244f2c:	c5 fc 10 95 50 fe ff 	vmovups -0x1b0(%rbp),%ymm2
 1244f33:	ff 
 1244f34:	c5 fc 10 9d 70 fe ff 	vmovups -0x190(%rbp),%ymm3
 1244f3b:	ff 
 1244f3c:	c5 fc 11 9d 30 fd ff 	vmovups %ymm3,-0x2d0(%rbp)
 1244f43:	ff 
 1244f44:	c5 fc 11 95 10 fd ff 	vmovups %ymm2,-0x2f0(%rbp)
 1244f4b:	ff 
 1244f4c:	c5 fc 11 8d f0 fc ff 	vmovups %ymm1,-0x310(%rbp)
 1244f53:	ff 
 1244f54:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 1244f5b:	ff 
 1244f5c:	0f b6 85 f0 f5 ff ff 	movzbl -0xa10(%rbp),%eax
 1244f63:	0f b6 4d d0          	movzbl -0x30(%rbp),%ecx
 1244f67:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 1244f6e:	ff 
 1244f6f:	c5 fc 11 85 a0 f8 ff 	vmovups %ymm0,-0x760(%rbp)
 1244f76:	ff 
 1244f77:	88 8d a1 fa ff ff    	mov    %cl,-0x55f(%rbp)
 1244f7d:	48 c7 85 90 f8 ff ff 	movq   $0x0,-0x770(%rbp)
 1244f84:	00 00 00 00 
 1244f88:	88 85 a5 fa ff ff    	mov    %al,-0x55b(%rbp)
 1244f8e:	c6 85 a4 fa ff ff 00 	movb   $0x0,-0x55c(%rbp)
 1244f95:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1244f99:	c5 fc 11 85 c0 f8 ff 	vmovups %ymm0,-0x740(%rbp)
 1244fa0:	ff 
 1244fa1:	c5 fc 11 85 e0 f8 ff 	vmovups %ymm0,-0x720(%rbp)
 1244fa8:	ff 
 1244fa9:	c5 fc 11 85 00 f9 ff 	vmovups %ymm0,-0x700(%rbp)
 1244fb0:	ff 
 1244fb1:	c5 fc 11 85 20 f9 ff 	vmovups %ymm0,-0x6e0(%rbp)
 1244fb8:	ff 
 1244fb9:	c5 fc 11 85 40 f9 ff 	vmovups %ymm0,-0x6c0(%rbp)
 1244fc0:	ff 
 1244fc1:	c5 fc 11 85 60 f9 ff 	vmovups %ymm0,-0x6a0(%rbp)
 1244fc8:	ff 
 1244fc9:	c5 fc 11 85 78 f9 ff 	vmovups %ymm0,-0x688(%rbp)
 1244fd0:	ff 
 1244fd1:	48 8b 45 40          	mov    0x40(%rbp),%rax
 1244fd5:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1244fd9:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1244fde:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1244fe3:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1244fe8:	c5 fc 11 85 98 f9 ff 	vmovups %ymm0,-0x668(%rbp)
 1244fef:	ff 
 1244ff0:	c5 fc 11 8d b8 f9 ff 	vmovups %ymm1,-0x648(%rbp)
 1244ff7:	ff 
 1244ff8:	c5 fc 11 95 d8 f9 ff 	vmovups %ymm2,-0x628(%rbp)
 1244fff:	ff 
 1245000:	c5 fc 11 9d e8 f9 ff 	vmovups %ymm3,-0x618(%rbp)
 1245007:	ff 
 1245008:	48 8b 45 48          	mov    0x48(%rbp),%rax
 124500c:	48 89 85 08 fa ff ff 	mov    %rax,-0x5f8(%rbp)
 1245013:	48 8b 45 50          	mov    0x50(%rbp),%rax
 1245017:	c5 fc 10 00          	vmovups (%rax),%ymm0
 124501b:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1245020:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1245025:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 124502a:	c5 fc 11 85 10 fa ff 	vmovups %ymm0,-0x5f0(%rbp)
 1245031:	ff 
 1245032:	c5 fc 11 8d 30 fa ff 	vmovups %ymm1,-0x5d0(%rbp)
 1245039:	ff 
 124503a:	c5 fc 11 95 50 fa ff 	vmovups %ymm2,-0x5b0(%rbp)
 1245041:	ff 
 1245042:	c5 fc 11 9d 60 fa ff 	vmovups %ymm3,-0x5a0(%rbp)
 1245049:	ff 
 124504a:	48 8b 45 58          	mov    0x58(%rbp),%rax
 124504e:	48 89 85 80 fa ff ff 	mov    %rax,-0x580(%rbp)
 1245055:	c6 85 98 fa ff ff 38 	movb   $0x38,-0x568(%rbp)
 124505c:	c6 85 a0 fa ff ff 00 	movb   $0x0,-0x560(%rbp)
 1245063:	0f b7 05 c6 5e df ff 	movzwl -0x20a13a(%rip),%eax        # 103af30 <__anon_29470>
 124506a:	66 89 85 9a fa ff ff 	mov    %ax,-0x566(%rbp)
 1245071:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 1245075:	88 85 99 fa ff ff    	mov    %al,-0x567(%rbp)
 124507b:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 124507f:	48 89 85 80 f8 ff ff 	mov    %rax,-0x780(%rbp)
 1245086:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 124508a:	48 89 85 88 f8 ff ff 	mov    %rax,-0x778(%rbp)
 1245091:	c7 85 9c fa ff ff 01 	movl   $0x1000101,-0x564(%rbp)
 1245098:	01 00 01 
 124509b:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 124509f:	48 89 85 90 fa ff ff 	mov    %rax,-0x570(%rbp)
 12450a6:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 12450aa:	48 89 85 88 fa ff ff 	mov    %rax,-0x578(%rbp)
 12450b1:	66 c7 85 a2 fa ff ff 	movw   $0x0,-0x55e(%rbp)
 12450b8:	00 00 
 12450ba:	48 c7 85 98 f8 ff ff 	movq   $0x0,-0x768(%rbp)
 12450c1:	00 00 00 00 
 12450c5:	48 8d 85 80 f8 ff ff 	lea    -0x780(%rbp),%rax
 12450cc:	4c 8d 95 d0 fc ff ff 	lea    -0x330(%rbp),%r10
 12450d3:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 12450da:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 12450de:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 12450e2:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 12450e6:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 12450ea:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 12450ee:	50                   	push   %rax
 12450ef:	41 52                	push   %r10
 12450f1:	c5 f8 77             	vzeroupper 
 12450f4:	e8 27 20 f7 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 12450f9:	48 83 c4 10          	add    $0x10,%rsp
 12450fd:	0f b7 9d 40 ff ff ff 	movzwl -0xc0(%rbp),%ebx
 1245104:	66 85 db             	test   %bx,%bx
 1245107:	0f 85 47 01 00 00    	jne    1245254 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x9f4>
 124510d:	4c 8b a5 30 ff ff ff 	mov    -0xd0(%rbp),%r12
 1245114:	4c 8b ad 38 ff ff ff 	mov    -0xc8(%rbp),%r13
 124511b:	4d 39 fd             	cmp    %r15,%r13
 124511e:	73 71                	jae    1245191 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x931>
 1245120:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1245124:	48 8b 38             	mov    (%rax),%rdi
 1245127:	48 8b 40 08          	mov    0x8(%rax),%rax
 124512b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124512f:	4c 89 f6             	mov    %r14,%rsi
 1245132:	4c 89 fa             	mov    %r15,%rdx
 1245135:	31 c9                	xor    %ecx,%ecx
 1245137:	ff 50 18             	call   *0x18(%rax)
 124513a:	c5 fc 10 85 40 fd ff 	vmovups -0x2c0(%rbp),%ymm0
 1245141:	ff 
 1245142:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 1245149:	ff 
 124514a:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 1245151:	ff 
 1245152:	c5 fc 10 8d f0 fc ff 	vmovups -0x310(%rbp),%ymm1
 1245159:	ff 
 124515a:	c5 fc 10 95 10 fd ff 	vmovups -0x2f0(%rbp),%ymm2
 1245161:	ff 
 1245162:	c5 fc 10 9d 30 fd ff 	vmovups -0x2d0(%rbp),%ymm3
 1245169:	ff 
 124516a:	c5 fc 11 9d 00 ff ff 	vmovups %ymm3,-0x100(%rbp)
 1245171:	ff 
 1245172:	c5 fc 11 95 e0 fe ff 	vmovups %ymm2,-0x120(%rbp)
 1245179:	ff 
 124517a:	c5 fc 11 8d c0 fe ff 	vmovups %ymm1,-0x140(%rbp)
 1245181:	ff 
 1245182:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1245189:	ff 
 124518a:	eb 2a                	jmp    12451b6 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x956>
 124518c:	49 89 c4             	mov    %rax,%r12
 124518f:	eb 22                	jmp    12451b3 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x953>
 1245191:	4d 85 ed             	test   %r13,%r13
 1245194:	74 1a                	je     12451b0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x950>
 1245196:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 124519a:	48 8b 38             	mov    (%rax),%rdi
 124519d:	48 8b 40 08          	mov    0x8(%rax),%rax
 12451a1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12451a5:	4c 89 e6             	mov    %r12,%rsi
 12451a8:	4c 89 ea             	mov    %r13,%rdx
 12451ab:	31 c9                	xor    %ecx,%ecx
 12451ad:	ff 50 18             	call   *0x18(%rax)
 12451b0:	4d 89 f4             	mov    %r14,%r12
 12451b3:	4d 89 fd             	mov    %r15,%r13
 12451b6:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12451ba:	c5 fc 10 85 10 ff ff 	vmovups -0xf0(%rbp),%ymm0
 12451c1:	ff 
 12451c2:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12451c7:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 12451ce:	ff 
 12451cf:	c5 fc 10 8d c0 fe ff 	vmovups -0x140(%rbp),%ymm1
 12451d6:	ff 
 12451d7:	c5 fc 10 95 e0 fe ff 	vmovups -0x120(%rbp),%ymm2
 12451de:	ff 
 12451df:	c5 fc 10 9d 00 ff ff 	vmovups -0x100(%rbp),%ymm3
 12451e6:	ff 
 12451e7:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12451ec:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12451f1:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12451f6:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12451fa:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 12451fe:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1245204:	4c 89 20             	mov    %r12,(%rax)
 1245207:	4c 89 68 08          	mov    %r13,0x8(%rax)
 124520b:	48 81 c4 48 0b 00 00 	add    $0xb48,%rsp
 1245212:	5b                   	pop    %rbx
 1245213:	41 5c                	pop    %r12
 1245215:	41 5d                	pop    %r13
 1245217:	41 5e                	pop    %r14
 1245219:	41 5f                	pop    %r15
 124521b:	5d                   	pop    %rbp
 124521c:	c5 f8 77             	vzeroupper 
 124521f:	c3                   	ret    
 1245220:	4d 85 ed             	test   %r13,%r13
 1245223:	74 1a                	je     124523f <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x9df>
 1245225:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1245229:	48 8b 38             	mov    (%rax),%rdi
 124522c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1245230:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1245234:	4c 89 e6             	mov    %r12,%rsi
 1245237:	4c 89 ea             	mov    %r13,%rdx
 124523a:	31 c9                	xor    %ecx,%ecx
 124523c:	ff 50 18             	call   *0x18(%rax)
 124523f:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1245243:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 1245248:	eb c1                	jmp    124520b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x9ab>
 124524a:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 124524e:	66 89 41 10          	mov    %ax,0x10(%rcx)
 1245252:	eb b7                	jmp    124520b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x9ab>
 1245254:	4d 85 ff             	test   %r15,%r15
 1245257:	74 1a                	je     1245273 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0xa13>
 1245259:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 124525d:	48 8b 38             	mov    (%rax),%rdi
 1245260:	48 8b 40 08          	mov    0x8(%rax),%rax
 1245264:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1245268:	4c 89 f6             	mov    %r14,%rsi
 124526b:	4c 89 fa             	mov    %r15,%rdx
 124526e:	31 c9                	xor    %ecx,%ecx
 1245270:	ff 50 18             	call   *0x18(%rax)
 1245273:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1245277:	66 89 58 10          	mov    %bx,0x10(%rax)
 124527b:	eb 8e                	jmp    124520b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684+0x9ab>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
