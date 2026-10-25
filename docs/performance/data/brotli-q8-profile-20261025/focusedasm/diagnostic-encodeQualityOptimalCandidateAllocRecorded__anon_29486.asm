
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000123a8a0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486>:
 123a8a0:	55                   	push   %rbp
 123a8a1:	48 89 e5             	mov    %rsp,%rbp
 123a8a4:	41 57                	push   %r15
 123a8a6:	41 56                	push   %r14
 123a8a8:	41 55                	push   %r13
 123a8aa:	41 54                	push   %r12
 123a8ac:	53                   	push   %rbx
 123a8ad:	48 81 ec e8 22 00 00 	sub    $0x22e8,%rsp
 123a8b4:	4c 89 cb             	mov    %r9,%rbx
 123a8b7:	4d 89 c4             	mov    %r8,%r12
 123a8ba:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 123a8c1:	48 89 55 d0          	mov    %rdx,-0x30(%rbp)
 123a8c5:	49 89 ff             	mov    %rdi,%r15
 123a8c8:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123a8cc:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 123a8d0:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 123a8d7:	ff 
 123a8d8:	41 8b 09             	mov    (%r9),%ecx
 123a8db:	48 89 8d e0 fe ff ff 	mov    %rcx,-0x120(%rbp)
 123a8e2:	41 0f b7 49 08       	movzwl 0x8(%r9),%ecx
 123a8e7:	48 89 4d a8          	mov    %rcx,-0x58(%rbp)
 123a8eb:	41 0f b7 49 0a       	movzwl 0xa(%r9),%ecx
 123a8f0:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 123a8f4:	41 0f b7 49 0c       	movzwl 0xc(%r9),%ecx
 123a8f9:	48 89 8d 78 ff ff ff 	mov    %rcx,-0x88(%rbp)
 123a900:	41 0f b6 49 0f       	movzbl 0xf(%r9),%ecx
 123a905:	88 4d 88             	mov    %cl,-0x78(%rbp)
 123a908:	44 0f b6 70 4e       	movzbl 0x4e(%rax),%r14d
 123a90d:	48 89 75 80          	mov    %rsi,-0x80(%rbp)
 123a911:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 123a915:	45 0f b6 69 0e       	movzbl 0xe(%r9),%r13d
 123a91a:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 123a921:	ff 
 123a922:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123a929:	48 8d b5 20 fd ff ff 	lea    -0x2e0(%rbp),%rsi
 123a930:	ba 0a 00 00 00       	mov    $0xa,%edx
 123a935:	4c 89 c1             	mov    %r8,%rcx
 123a938:	45 31 c0             	xor    %r8d,%r8d
 123a93b:	c5 f8 77             	vzeroupper 
 123a93e:	e8 4d cc 03 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 123a943:	41 f6 c5 01          	test   $0x1,%r13b
 123a947:	0f 84 a3 05 00 00    	je     123aef0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x650>
 123a94d:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 123a951:	41 80 e6 1f          	and    $0x1f,%r14b
 123a955:	b8 01 00 00 00       	mov    $0x1,%eax
 123a95a:	c4 e2 89 f7 c0       	shlx   %r14,%rax,%rax
 123a95f:	48 83 c0 f0          	add    $0xfffffffffffffff0,%rax
 123a963:	4c 39 e0             	cmp    %r12,%rax
 123a966:	49 0f 43 c4          	cmovae %r12,%rax
 123a96a:	48 3d 00 80 00 00    	cmp    $0x8000,%rax
 123a970:	41 be 00 80 00 00    	mov    $0x8000,%r14d
 123a976:	4c 0f 42 f0          	cmovb  %rax,%r14
 123a97a:	48 8d bd c0 fc ff ff 	lea    -0x340(%rbp),%rdi
 123a981:	48 8d b5 40 fd ff ff 	lea    -0x2c0(%rbp),%rsi
 123a988:	ba 03 00 00 00       	mov    $0x3,%edx
 123a98d:	4c 89 e1             	mov    %r12,%rcx
 123a990:	45 31 c0             	xor    %r8d,%r8d
 123a993:	e8 f8 cb 03 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 123a998:	4c 89 b5 a8 fd ff ff 	mov    %r14,-0x258(%rbp)
 123a99f:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 123a9a3:	48 89 85 b0 fd ff ff 	mov    %rax,-0x250(%rbp)
 123a9aa:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 123a9ae:	48 89 85 b8 fd ff ff 	mov    %rax,-0x248(%rbp)
 123a9b5:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 123a9bc:	48 89 85 c0 fd ff ff 	mov    %rax,-0x240(%rbp)
 123a9c3:	c5 fc 28 05 15 5b dc 	vmovaps -0x23a4eb(%rip),%ymm0        # 10004e0 <__anon_248258+0xa0>
 123a9ca:	ff 
 123a9cb:	c5 fc 11 85 c8 fd ff 	vmovups %ymm0,-0x238(%rbp)
 123a9d2:	ff 
 123a9d3:	c6 85 e8 fd ff ff 00 	movb   $0x0,-0x218(%rbp)
 123a9da:	48 8d bd 20 fe ff ff 	lea    -0x1e0(%rbp),%rdi
 123a9e1:	4c 8d 85 a8 fd ff ff 	lea    -0x258(%rbp),%r8
 123a9e8:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123a9ec:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 123a9f3:	4c 89 e1             	mov    %r12,%rcx
 123a9f6:	c5 f8 77             	vzeroupper 
 123a9f9:	e8 f2 e1 ff ff       	call   1238bf0 <lz77.optimalPlanAlloc>
 123a9fe:	44 0f b7 ad 48 fe ff 	movzwl -0x1b8(%rbp),%r13d
 123aa05:	ff 
 123aa06:	4d 85 ed             	test   %r13,%r13
 123aa09:	0f 85 8d 06 00 00    	jne    123b09c <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x7fc>
 123aa0f:	4c 89 a5 68 ff ff ff 	mov    %r12,-0x98(%rbp)
 123aa16:	4c 8b bd 20 fe ff ff 	mov    -0x1e0(%rbp),%r15
 123aa1d:	4c 8b a5 28 fe ff ff 	mov    -0x1d8(%rbp),%r12
 123aa24:	4c 8b ad 38 fe ff ff 	mov    -0x1c8(%rbp),%r13
 123aa2b:	48 8d bd c0 fc ff ff 	lea    -0x340(%rbp),%rdi
 123aa32:	e8 39 c7 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123aa37:	4d 85 ed             	test   %r13,%r13
 123aa3a:	0f 84 c2 04 00 00    	je     123af02 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x662>
 123aa40:	4c 89 b5 e8 fe ff ff 	mov    %r14,-0x118(%rbp)
 123aa47:	48 8d bd 60 fc ff ff 	lea    -0x3a0(%rbp),%rdi
 123aa4e:	48 8d b5 40 fd ff ff 	lea    -0x2c0(%rbp),%rsi
 123aa55:	ba 04 00 00 00       	mov    $0x4,%edx
 123aa5a:	4c 8b ad 68 ff ff ff 	mov    -0x98(%rbp),%r13
 123aa61:	4c 89 e9             	mov    %r13,%rcx
 123aa64:	45 31 c0             	xor    %r8d,%r8d
 123aa67:	e8 24 cb 03 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 123aa6c:	48 8d bd 90 fe ff ff 	lea    -0x170(%rbp),%rdi
 123aa73:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123aa77:	49 89 f6             	mov    %rsi,%r14
 123aa7a:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 123aa81:	4c 89 e9             	mov    %r13,%rcx
 123aa84:	4d 89 f8             	mov    %r15,%r8
 123aa87:	4c 89 65 c8          	mov    %r12,-0x38(%rbp)
 123aa8b:	4d 89 e1             	mov    %r12,%r9
 123aa8e:	e8 9d 4f f7 ff       	call   11afa30 <br.encoder.command_plan.buildAlloc>
 123aa93:	44 0f b7 a5 a8 fe ff 	movzwl -0x158(%rbp),%r12d
 123aa9a:	ff 
 123aa9b:	4d 85 e4             	test   %r12,%r12
 123aa9e:	0f 85 3c 06 00 00    	jne    123b0e0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x840>
 123aaa4:	4c 89 7d a0          	mov    %r15,-0x60(%rbp)
 123aaa8:	4c 8b ad 90 fe ff ff 	mov    -0x170(%rbp),%r13
 123aaaf:	4c 8b bd 98 fe ff ff 	mov    -0x168(%rbp),%r15
 123aab6:	48 8d bd 60 fc ff ff 	lea    -0x3a0(%rbp),%rdi
 123aabd:	e8 ae c6 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123aac2:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123aac6:	c5 fc 11 85 40 fc ff 	vmovups %ymm0,-0x3c0(%rbp)
 123aacd:	ff 
 123aace:	c5 fc 11 85 30 fc ff 	vmovups %ymm0,-0x3d0(%rbp)
 123aad5:	ff 
 123aad6:	c5 fc 11 85 10 fc ff 	vmovups %ymm0,-0x3f0(%rbp)
 123aadd:	ff 
 123aade:	c5 fc 11 85 f0 fb ff 	vmovups %ymm0,-0x410(%rbp)
 123aae5:	ff 
 123aae6:	c5 fc 11 85 d0 fb ff 	vmovups %ymm0,-0x430(%rbp)
 123aaed:	ff 
 123aaee:	48 83 ec 08          	sub    $0x8,%rsp
 123aaf2:	48 8d 85 d0 fb ff ff 	lea    -0x430(%rbp),%rax
 123aaf9:	48 8d bd c8 fe ff ff 	lea    -0x138(%rbp),%rdi
 123ab00:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 123ab04:	4c 89 f2             	mov    %r14,%rdx
 123ab07:	4c 8b a5 70 ff ff ff 	mov    -0x90(%rbp),%r12
 123ab0e:	4c 89 e1             	mov    %r12,%rcx
 123ab11:	4c 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%r8
 123ab18:	4c 89 6d b0          	mov    %r13,-0x50(%rbp)
 123ab1c:	4d 89 e9             	mov    %r13,%r9
 123ab1f:	ff 75 10             	push   0x10(%rbp)
 123ab22:	50                   	push   %rax
 123ab23:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 123ab27:	41 57                	push   %r15
 123ab29:	c5 f8 77             	vzeroupper 
 123ab2c:	e8 af e4 02 00       	call   1268fe0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228>
 123ab31:	48 83 c4 20          	add    $0x20,%rsp
 123ab35:	44 0f b7 ad d8 fe ff 	movzwl -0x128(%rbp),%r13d
 123ab3c:	ff 
 123ab3d:	4d 85 ed             	test   %r13,%r13
 123ab40:	0f 85 47 06 00 00    	jne    123b18d <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x8ed>
 123ab46:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 123ab4d:	4c 8b bd d0 fe ff ff 	mov    -0x130(%rbp),%r15
 123ab54:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 123ab58:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 123ab5f:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 123ab66:	f6 45 88 01          	testb  $0x1,-0x78(%rbp)
 123ab6a:	0f 84 eb 03 00 00    	je     123af5b <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6bb>
 123ab70:	48 8d bd 08 e7 ff ff 	lea    -0x18f8(%rbp),%rdi
 123ab77:	4c 89 f6             	mov    %r14,%rsi
 123ab7a:	4c 89 e2             	mov    %r12,%rdx
 123ab7d:	4d 89 e5             	mov    %r12,%r13
 123ab80:	4c 8b a5 68 ff ff ff 	mov    -0x98(%rbp),%r12
 123ab87:	4c 89 e1             	mov    %r12,%rcx
 123ab8a:	4c 8b 45 b0          	mov    -0x50(%rbp),%r8
 123ab8e:	4c 8b 4d c0          	mov    -0x40(%rbp),%r9
 123ab92:	68 80 03 00 01       	push   $0x1000380
 123ab97:	4c 8b b5 e8 fe ff ff 	mov    -0x118(%rbp),%r14
 123ab9e:	41 56                	push   %r14
 123aba0:	e8 8b cd 02 00       	call   1267930 <br.encoder.entropy_feedback.buildWithStartingDistances>
 123aba5:	48 83 c4 10          	add    $0x10,%rsp
 123aba9:	48 8d bd f0 dc ff ff 	lea    -0x2310(%rbp),%rdi
 123abb0:	ba 18 0a 00 00       	mov    $0xa18,%edx
 123abb5:	48 8d b5 08 e7 ff ff 	lea    -0x18f8(%rbp),%rsi
 123abbc:	e8 9f 4b 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123abc1:	0f b7 85 20 f1 ff ff 	movzwl -0xee0(%rbp),%eax
 123abc8:	48 85 c0             	test   %rax,%rax
 123abcb:	0f 85 54 06 00 00    	jne    123b225 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x985>
 123abd1:	4c 89 7d 88          	mov    %r15,-0x78(%rbp)
 123abd5:	48 8d bd 28 f1 ff ff 	lea    -0xed8(%rbp),%rdi
 123abdc:	48 8d b5 f0 dc ff ff 	lea    -0x2310(%rbp),%rsi
 123abe3:	ba 18 0a 00 00       	mov    $0xa18,%edx
 123abe8:	e8 73 4b 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123abed:	4c 89 b5 60 fd ff ff 	mov    %r14,-0x2a0(%rbp)
 123abf4:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 123abf8:	48 89 85 68 fd ff ff 	mov    %rax,-0x298(%rbp)
 123abff:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 123ac03:	48 89 85 70 fd ff ff 	mov    %rax,-0x290(%rbp)
 123ac0a:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 123ac11:	48 89 85 78 fd ff ff 	mov    %rax,-0x288(%rbp)
 123ac18:	c5 fc 28 05 c0 58 dc 	vmovaps -0x23a740(%rip),%ymm0        # 10004e0 <__anon_248258+0xa0>
 123ac1f:	ff 
 123ac20:	c5 fc 11 85 80 fd ff 	vmovups %ymm0,-0x280(%rbp)
 123ac27:	ff 
 123ac28:	c6 85 a0 fd ff ff 00 	movb   $0x0,-0x260(%rbp)
 123ac2f:	48 8d 85 38 f1 ff ff 	lea    -0xec8(%rbp),%rax
 123ac36:	48 89 85 70 fe ff ff 	mov    %rax,-0x190(%rbp)
 123ac3d:	48 8d 85 38 f3 ff ff 	lea    -0xcc8(%rbp),%rax
 123ac44:	48 89 85 78 fe ff ff 	mov    %rax,-0x188(%rbp)
 123ac4b:	c5 f8 10 85 28 f1 ff 	vmovups -0xed8(%rbp),%xmm0
 123ac52:	ff 
 123ac53:	c5 f8 11 85 80 fe ff 	vmovups %xmm0,-0x180(%rbp)
 123ac5a:	ff 
 123ac5b:	48 8d bd f0 fd ff ff 	lea    -0x210(%rbp),%rdi
 123ac62:	4c 8d 85 60 fd ff ff 	lea    -0x2a0(%rbp),%r8
 123ac69:	4c 8d 8d 70 fe ff ff 	lea    -0x190(%rbp),%r9
 123ac70:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123ac74:	4c 89 ea             	mov    %r13,%rdx
 123ac77:	4c 89 e1             	mov    %r12,%rcx
 123ac7a:	c5 f8 77             	vzeroupper 
 123ac7d:	e8 be ee ff ff       	call   1239b40 <lz77.optimalPlanAllocWithCostModel>
 123ac82:	44 0f b7 ad 18 fe ff 	movzwl -0x1e8(%rbp),%r13d
 123ac89:	ff 
 123ac8a:	4d 85 ed             	test   %r13,%r13
 123ac8d:	4c 8b 7d 80          	mov    -0x80(%rbp),%r15
 123ac91:	0f 85 f0 05 00 00    	jne    123b287 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x9e7>
 123ac97:	4c 8b 85 f0 fd ff ff 	mov    -0x210(%rbp),%r8
 123ac9e:	4c 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%r9
 123aca5:	48 83 bd 08 fe ff ff 	cmpq   $0x0,-0x1f8(%rbp)
 123acac:	00 
 123acad:	4c 8b 75 b0          	mov    -0x50(%rbp),%r14
 123acb1:	0f 84 1d 03 00 00    	je     123afd4 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x734>
 123acb7:	4d 89 fd             	mov    %r15,%r13
 123acba:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 123acc1:	4c 8b 65 d0          	mov    -0x30(%rbp),%r12
 123acc5:	4c 89 e6             	mov    %r12,%rsi
 123acc8:	4c 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%r14
 123accf:	4c 89 f2             	mov    %r14,%rdx
 123acd2:	4c 8b bd 68 ff ff ff 	mov    -0x98(%rbp),%r15
 123acd9:	4c 89 f9             	mov    %r15,%rcx
 123acdc:	4c 89 45 98          	mov    %r8,-0x68(%rbp)
 123ace0:	4c 89 4d a8          	mov    %r9,-0x58(%rbp)
 123ace4:	e8 47 4d f7 ff       	call   11afa30 <br.encoder.command_plan.buildAlloc>
 123ace9:	0f b7 85 68 fe ff ff 	movzwl -0x198(%rbp),%eax
 123acf0:	48 85 c0             	test   %rax,%rax
 123acf3:	0f 85 75 06 00 00    	jne    123b36e <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xace>
 123acf9:	4c 8b 8d 50 fe ff ff 	mov    -0x1b0(%rbp),%r9
 123ad00:	4c 8b 95 58 fe ff ff 	mov    -0x1a8(%rbp),%r10
 123ad07:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123ad0b:	c5 fc 11 85 40 fb ff 	vmovups %ymm0,-0x4c0(%rbp)
 123ad12:	ff 
 123ad13:	c5 fc 11 85 60 fb ff 	vmovups %ymm0,-0x4a0(%rbp)
 123ad1a:	ff 
 123ad1b:	c5 fc 11 85 80 fb ff 	vmovups %ymm0,-0x480(%rbp)
 123ad22:	ff 
 123ad23:	c5 fc 11 85 a0 fb ff 	vmovups %ymm0,-0x460(%rbp)
 123ad2a:	ff 
 123ad2b:	c5 fc 11 85 b0 fb ff 	vmovups %ymm0,-0x450(%rbp)
 123ad32:	ff 
 123ad33:	48 83 ec 08          	sub    $0x8,%rsp
 123ad37:	48 8d 85 40 fb ff ff 	lea    -0x4c0(%rbp),%rax
 123ad3e:	48 8d bd b0 fe ff ff 	lea    -0x150(%rbp),%rdi
 123ad45:	4c 89 ee             	mov    %r13,%rsi
 123ad48:	4c 89 e2             	mov    %r12,%rdx
 123ad4b:	4c 89 f1             	mov    %r14,%rcx
 123ad4e:	4d 89 f8             	mov    %r15,%r8
 123ad51:	4c 89 8d 78 ff ff ff 	mov    %r9,-0x88(%rbp)
 123ad58:	ff 75 10             	push   0x10(%rbp)
 123ad5b:	50                   	push   %rax
 123ad5c:	4d 89 d6             	mov    %r10,%r14
 123ad5f:	41 52                	push   %r10
 123ad61:	c5 f8 77             	vzeroupper 
 123ad64:	e8 77 e2 02 00       	call   1268fe0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228>
 123ad69:	48 83 c4 20          	add    $0x20,%rsp
 123ad6d:	0f b7 85 c0 fe ff ff 	movzwl -0x140(%rbp),%eax
 123ad74:	48 85 c0             	test   %rax,%rax
 123ad77:	0f 85 f6 05 00 00    	jne    123b373 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xad3>
 123ad7d:	48 8b 8d b0 fe ff ff 	mov    -0x150(%rbp),%rcx
 123ad84:	4c 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%r8
 123ad8b:	48 8d 85 58 ff ff ff 	lea    -0xa8(%rbp),%rax
 123ad92:	4c 89 ef             	mov    %r13,%rdi
 123ad95:	4c 89 e6             	mov    %r12,%rsi
 123ad98:	49 89 c4             	mov    %rax,%r12
 123ad9b:	48 89 c2             	mov    %rax,%rdx
 123ad9e:	e8 7d df 02 00       	call   1268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>
 123ada3:	48 8b 8d e0 fe ff ff 	mov    -0x120(%rbp),%rcx
 123adaa:	85 c9                	test   %ecx,%ecx
 123adac:	0f 95 c0             	setne  %al
 123adaf:	49 39 cf             	cmp    %rcx,%r15
 123adb2:	0f 96 c1             	setbe  %cl
 123adb5:	84 c8                	test   %cl,%al
 123adb7:	4c 8b 85 e8 fe ff ff 	mov    -0x118(%rbp),%r8
 123adbe:	74 31                	je     123adf1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x551>
 123adc0:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 123adc4:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 123adcb:	4c 89 fa             	mov    %r15,%rdx
 123adce:	48 89 d9             	mov    %rbx,%rcx
 123add1:	4c 8b 4d 10          	mov    0x10(%rbp),%r9
 123add5:	41 54                	push   %r12
 123add7:	48 8d 85 28 f1 ff ff 	lea    -0xed8(%rbp),%rax
 123adde:	50                   	push   %rax
 123addf:	e8 0c be 0b 00       	call   12f6bf0 <br.selectQualityCommandStateCandidate>
 123ade4:	48 83 c4 10          	add    $0x10,%rsp
 123ade8:	66 85 c0             	test   %ax,%ax
 123adeb:	0f 85 c1 06 00 00    	jne    123b4b2 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xc12>
 123adf1:	48 8b 9d 58 ff ff ff 	mov    -0xa8(%rbp),%rbx
 123adf8:	4c 8b ad 60 ff ff ff 	mov    -0xa0(%rbp),%r13
 123adff:	4d 85 f6             	test   %r14,%r14
 123ae02:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 123ae06:	74 26                	je     123ae2e <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x58e>
 123ae08:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123ae0c:	48 8b 38             	mov    (%rax),%rdi
 123ae0f:	48 8b 40 08          	mov    0x8(%rax),%rax
 123ae13:	49 c1 e6 05          	shl    $0x5,%r14
 123ae17:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 123ae1b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ae1f:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 123ae26:	b9 03 00 00 00       	mov    $0x3,%ecx
 123ae2b:	ff 50 18             	call   *0x18(%rax)
 123ae2e:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 123ae32:	48 85 c9             	test   %rcx,%rcx
 123ae35:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 123ae39:	74 1e                	je     123ae59 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x5b9>
 123ae3b:	49 8b 3f             	mov    (%r15),%rdi
 123ae3e:	49 8b 47 08          	mov    0x8(%r15),%rax
 123ae42:	48 01 c9             	add    %rcx,%rcx
 123ae45:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123ae49:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ae4d:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 123ae51:	b9 01 00 00 00       	mov    $0x1,%ecx
 123ae56:	ff 50 18             	call   *0x18(%rax)
 123ae59:	48 8b 95 30 f1 ff ff 	mov    -0xed0(%rbp),%rdx
 123ae60:	48 85 d2             	test   %rdx,%rdx
 123ae63:	74 1d                	je     123ae82 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x5e2>
 123ae65:	48 8b b5 28 f1 ff ff 	mov    -0xed8(%rbp),%rsi
 123ae6c:	49 8b 3f             	mov    (%r15),%rdi
 123ae6f:	49 8b 47 08          	mov    0x8(%r15),%rax
 123ae73:	48 01 d2             	add    %rdx,%rdx
 123ae76:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ae7a:	b9 01 00 00 00       	mov    $0x1,%ecx
 123ae7f:	ff 50 18             	call   *0x18(%rax)
 123ae82:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123ae86:	48 85 c9             	test   %rcx,%rcx
 123ae89:	74 1f                	je     123aeaa <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x60a>
 123ae8b:	49 8b 3f             	mov    (%r15),%rdi
 123ae8e:	49 8b 47 08          	mov    0x8(%r15),%rax
 123ae92:	48 c1 e1 05          	shl    $0x5,%rcx
 123ae96:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123ae9a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ae9e:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123aea2:	b9 03 00 00 00       	mov    $0x3,%ecx
 123aea7:	ff 50 18             	call   *0x18(%rax)
 123aeaa:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123aeae:	48 85 c9             	test   %rcx,%rcx
 123aeb1:	74 1d                	je     123aed0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x630>
 123aeb3:	49 8b 3f             	mov    (%r15),%rdi
 123aeb6:	49 8b 47 08          	mov    0x8(%r15),%rax
 123aeba:	48 01 c9             	add    %rcx,%rcx
 123aebd:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123aec1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123aec5:	4c 89 e6             	mov    %r12,%rsi
 123aec8:	b9 01 00 00 00       	mov    $0x1,%ecx
 123aecd:	ff 50 18             	call   *0x18(%rax)
 123aed0:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123aed7:	e8 94 c2 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123aedc:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 123aee0:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 123aee7:	49 89 1f             	mov    %rbx,(%r15)
 123aeea:	4d 89 6f 08          	mov    %r13,0x8(%r15)
 123aeee:	eb 59                	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>
 123aef0:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123aef7:	e8 74 c2 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123aefc:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123af00:	eb 3a                	jmp    123af3c <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x69c>
 123af02:	4c 89 fe             	mov    %r15,%rsi
 123af05:	4d 85 e4             	test   %r12,%r12
 123af08:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 123af0c:	74 1a                	je     123af28 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x688>
 123af0e:	49 8b 3f             	mov    (%r15),%rdi
 123af11:	49 8b 47 08          	mov    0x8(%r15),%rax
 123af15:	4d 01 e4             	add    %r12,%r12
 123af18:	4b 8d 14 64          	lea    (%r12,%r12,2),%rdx
 123af1c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123af20:	b9 01 00 00 00       	mov    $0x1,%ecx
 123af25:	ff 50 18             	call   *0x18(%rax)
 123af28:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123af2f:	e8 3c c2 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123af34:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123af38:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 123af3c:	c4 c1 78 11 07       	vmovups %xmm0,(%r15)
 123af41:	49 c7 47 10 00 00 00 	movq   $0x0,0x10(%r15)
 123af48:	00 
 123af49:	48 81 c4 e8 22 00 00 	add    $0x22e8,%rsp
 123af50:	5b                   	pop    %rbx
 123af51:	41 5c                	pop    %r12
 123af53:	41 5d                	pop    %r13
 123af55:	41 5e                	pop    %r14
 123af57:	41 5f                	pop    %r15
 123af59:	5d                   	pop    %rbp
 123af5a:	c3                   	ret    
 123af5b:	4c 89 fb             	mov    %r15,%rbx
 123af5e:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123af62:	48 85 c9             	test   %rcx,%rcx
 123af65:	74 1f                	je     123af86 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6e6>
 123af67:	49 8b 3e             	mov    (%r14),%rdi
 123af6a:	49 8b 46 08          	mov    0x8(%r14),%rax
 123af6e:	48 c1 e1 05          	shl    $0x5,%rcx
 123af72:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123af76:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123af7a:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123af7e:	b9 03 00 00 00       	mov    $0x3,%ecx
 123af83:	ff 50 18             	call   *0x18(%rax)
 123af86:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123af8a:	48 85 c9             	test   %rcx,%rcx
 123af8d:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 123af91:	74 1e                	je     123afb1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x711>
 123af93:	49 8b 3e             	mov    (%r14),%rdi
 123af96:	49 8b 46 08          	mov    0x8(%r14),%rax
 123af9a:	48 01 c9             	add    %rcx,%rcx
 123af9d:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123afa1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123afa5:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 123afa9:	b9 01 00 00 00       	mov    $0x1,%ecx
 123afae:	ff 50 18             	call   *0x18(%rax)
 123afb1:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123afb8:	e8 b3 c1 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123afbd:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 123afc4:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 123afc8:	49 89 07             	mov    %rax,(%r15)
 123afcb:	49 89 5f 08          	mov    %rbx,0x8(%r15)
 123afcf:	e9 75 ff ff ff       	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>
 123afd4:	4d 85 c9             	test   %r9,%r9
 123afd7:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 123afdb:	74 1d                	je     123affa <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x75a>
 123afdd:	48 8b 3b             	mov    (%rbx),%rdi
 123afe0:	48 8b 43 08          	mov    0x8(%rbx),%rax
 123afe4:	4d 01 c9             	add    %r9,%r9
 123afe7:	4b 8d 14 49          	lea    (%r9,%r9,2),%rdx
 123afeb:	4c 89 c6             	mov    %r8,%rsi
 123afee:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123aff2:	b9 01 00 00 00       	mov    $0x1,%ecx
 123aff7:	ff 50 18             	call   *0x18(%rax)
 123affa:	48 8b 95 30 f1 ff ff 	mov    -0xed0(%rbp),%rdx
 123b001:	48 85 d2             	test   %rdx,%rdx
 123b004:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 123b008:	74 1d                	je     123b027 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x787>
 123b00a:	48 8b b5 28 f1 ff ff 	mov    -0xed8(%rbp),%rsi
 123b011:	48 8b 3b             	mov    (%rbx),%rdi
 123b014:	48 8b 43 08          	mov    0x8(%rbx),%rax
 123b018:	48 01 d2             	add    %rdx,%rdx
 123b01b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b01f:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b024:	ff 50 18             	call   *0x18(%rax)
 123b027:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123b02b:	48 85 c9             	test   %rcx,%rcx
 123b02e:	74 1e                	je     123b04e <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x7ae>
 123b030:	48 8b 3b             	mov    (%rbx),%rdi
 123b033:	48 8b 43 08          	mov    0x8(%rbx),%rax
 123b037:	48 c1 e1 05          	shl    $0x5,%rcx
 123b03b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b03f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b043:	4c 89 f6             	mov    %r14,%rsi
 123b046:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b04b:	ff 50 18             	call   *0x18(%rax)
 123b04e:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123b052:	48 85 c9             	test   %rcx,%rcx
 123b055:	74 1e                	je     123b075 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x7d5>
 123b057:	48 8b 3b             	mov    (%rbx),%rdi
 123b05a:	48 8b 43 08          	mov    0x8(%rbx),%rax
 123b05e:	48 01 c9             	add    %rcx,%rcx
 123b061:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b065:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b069:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 123b06d:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b072:	ff 50 18             	call   *0x18(%rax)
 123b075:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123b07c:	e8 ef c0 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b081:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 123b088:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 123b08c:	49 89 07             	mov    %rax,(%r15)
 123b08f:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 123b093:	49 89 47 08          	mov    %rax,0x8(%r15)
 123b097:	e9 ad fe ff ff       	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>
 123b09c:	80 bd f8 fc ff ff 00 	cmpb   $0x0,-0x308(%rbp)
 123b0a3:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 123b0a7:	74 26                	je     123b0cf <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x82f>
 123b0a9:	48 8b 85 e0 fc ff ff 	mov    -0x320(%rbp),%rax
 123b0b0:	48 69 8d f0 fc ff ff 	imul   $0x118,-0x310(%rbp),%rcx
 123b0b7:	18 01 00 00 
 123b0bb:	44 89 ea             	mov    %r13d,%edx
 123b0be:	c1 e2 04             	shl    $0x4,%edx
 123b0c1:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123b0c8:	01 
 123b0c9:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123b0cf:	48 8d bd c0 fc ff ff 	lea    -0x340(%rbp),%rdi
 123b0d6:	e8 95 c0 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b0db:	e9 00 01 00 00       	jmp    123b1e0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x940>
 123b0e0:	4c 89 fb             	mov    %r15,%rbx
 123b0e3:	80 bd 98 fc ff ff 00 	cmpb   $0x0,-0x368(%rbp)
 123b0ea:	74 26                	je     123b112 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x872>
 123b0ec:	48 8b 85 80 fc ff ff 	mov    -0x380(%rbp),%rax
 123b0f3:	48 69 8d 90 fc ff ff 	imul   $0x118,-0x370(%rbp),%rcx
 123b0fa:	18 01 00 00 
 123b0fe:	44 89 e2             	mov    %r12d,%edx
 123b101:	c1 e2 04             	shl    $0x4,%edx
 123b104:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123b10b:	01 
 123b10c:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123b112:	48 8d bd 60 fc ff ff 	lea    -0x3a0(%rbp),%rdi
 123b119:	e8 52 c0 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b11e:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123b122:	48 85 c9             	test   %rcx,%rcx
 123b125:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 123b129:	74 1d                	je     123b148 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x8a8>
 123b12b:	49 8b 3e             	mov    (%r14),%rdi
 123b12e:	49 8b 46 08          	mov    0x8(%r14),%rax
 123b132:	48 01 c9             	add    %rcx,%rcx
 123b135:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b139:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b13d:	48 89 de             	mov    %rbx,%rsi
 123b140:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b145:	ff 50 18             	call   *0x18(%rax)
 123b148:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 123b14f:	74 26                	je     123b177 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x8d7>
 123b151:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 123b158:	48 69 8d 20 ff ff ff 	imul   $0x118,-0xe0(%rbp),%rcx
 123b15f:	18 01 00 00 
 123b163:	44 89 e2             	mov    %r12d,%edx
 123b166:	c1 e2 04             	shl    $0x4,%edx
 123b169:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123b170:	01 
 123b171:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123b177:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123b17e:	e8 ed bf 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b183:	66 45 89 67 10       	mov    %r12w,0x10(%r15)
 123b188:	e9 bc fd ff ff       	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>
 123b18d:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123b191:	48 85 c9             	test   %rcx,%rcx
 123b194:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 123b198:	74 1f                	je     123b1b9 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x919>
 123b19a:	49 8b 3e             	mov    (%r14),%rdi
 123b19d:	49 8b 46 08          	mov    0x8(%r14),%rax
 123b1a1:	48 c1 e1 05          	shl    $0x5,%rcx
 123b1a5:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b1a9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b1ad:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123b1b1:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b1b6:	ff 50 18             	call   *0x18(%rax)
 123b1b9:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123b1bd:	48 85 c9             	test   %rcx,%rcx
 123b1c0:	74 1e                	je     123b1e0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x940>
 123b1c2:	49 8b 3e             	mov    (%r14),%rdi
 123b1c5:	49 8b 46 08          	mov    0x8(%r14),%rax
 123b1c9:	48 01 c9             	add    %rcx,%rcx
 123b1cc:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b1d0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b1d4:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 123b1d8:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b1dd:	ff 50 18             	call   *0x18(%rax)
 123b1e0:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 123b1e7:	74 26                	je     123b20f <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x96f>
 123b1e9:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 123b1f0:	48 69 8d 20 ff ff ff 	imul   $0x118,-0xe0(%rbp),%rcx
 123b1f7:	18 01 00 00 
 123b1fb:	44 89 ea             	mov    %r13d,%edx
 123b1fe:	c1 e2 04             	shl    $0x4,%edx
 123b201:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123b208:	01 
 123b209:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123b20f:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123b216:	e8 55 bf 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b21b:	66 45 89 6f 10       	mov    %r13w,0x10(%r15)
 123b220:	e9 24 fd ff ff       	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>
 123b225:	49 89 c5             	mov    %rax,%r13
 123b228:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 123b22c:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 123b230:	48 8b 7d 80          	mov    -0x80(%rbp),%rdi
 123b234:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123b238:	49 89 f6             	mov    %rsi,%r14
 123b23b:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 123b23f:	4c 89 f9             	mov    %r15,%rcx
 123b242:	e8 59 b3 03 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 123b247:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123b24b:	48 85 c9             	test   %rcx,%rcx
 123b24e:	74 1e                	je     123b26e <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x9ce>
 123b250:	49 8b 3e             	mov    (%r14),%rdi
 123b253:	49 8b 46 08          	mov    0x8(%r14),%rax
 123b257:	48 c1 e1 05          	shl    $0x5,%rcx
 123b25b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b25f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b263:	48 89 de             	mov    %rbx,%rsi
 123b266:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b26b:	ff 50 18             	call   *0x18(%rax)
 123b26e:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123b272:	48 85 c9             	test   %rcx,%rcx
 123b275:	0f 84 aa 00 00 00    	je     123b325 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xa85>
 123b27b:	49 8b 3e             	mov    (%r14),%rdi
 123b27e:	49 8b 46 08          	mov    0x8(%r14),%rax
 123b282:	e9 88 00 00 00       	jmp    123b30f <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xa6f>
 123b287:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 123b28b:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 123b28f:	48 8b 95 30 f1 ff ff 	mov    -0xed0(%rbp),%rdx
 123b296:	48 85 d2             	test   %rdx,%rdx
 123b299:	74 21                	je     123b2bc <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xa1c>
 123b29b:	48 8b b5 28 f1 ff ff 	mov    -0xed8(%rbp),%rsi
 123b2a2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b2a6:	48 8b 38             	mov    (%rax),%rdi
 123b2a9:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b2ad:	48 01 d2             	add    %rdx,%rdx
 123b2b0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b2b4:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b2b9:	ff 50 18             	call   *0x18(%rax)
 123b2bc:	4c 89 ff             	mov    %r15,%rdi
 123b2bf:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123b2c3:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 123b2c7:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 123b2cb:	e8 d0 b2 03 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 123b2d0:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123b2d4:	48 85 c9             	test   %rcx,%rcx
 123b2d7:	74 22                	je     123b2fb <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xa5b>
 123b2d9:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b2dd:	48 8b 38             	mov    (%rax),%rdi
 123b2e0:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b2e4:	48 c1 e1 05          	shl    $0x5,%rcx
 123b2e8:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b2ec:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b2f0:	48 89 de             	mov    %rbx,%rsi
 123b2f3:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b2f8:	ff 50 18             	call   *0x18(%rax)
 123b2fb:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123b2ff:	48 85 c9             	test   %rcx,%rcx
 123b302:	74 21                	je     123b325 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xa85>
 123b304:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 123b308:	49 8b 3f             	mov    (%r15),%rdi
 123b30b:	49 8b 47 08          	mov    0x8(%r15),%rax
 123b30f:	48 01 c9             	add    %rcx,%rcx
 123b312:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b316:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b31a:	4c 89 e6             	mov    %r12,%rsi
 123b31d:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b322:	ff 50 18             	call   *0x18(%rax)
 123b325:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 123b32c:	74 26                	je     123b354 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xab4>
 123b32e:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 123b335:	48 69 8d 20 ff ff ff 	imul   $0x118,-0xe0(%rbp),%rcx
 123b33c:	18 01 00 00 
 123b340:	44 89 ea             	mov    %r13d,%edx
 123b343:	c1 e2 04             	shl    $0x4,%edx
 123b346:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123b34d:	01 
 123b34e:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123b354:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123b35b:	e8 10 be 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b360:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 123b364:	66 44 89 68 10       	mov    %r13w,0x10(%rax)
 123b369:	e9 db fb ff ff       	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>
 123b36e:	48 89 c3             	mov    %rax,%rbx
 123b371:	eb 2e                	jmp    123b3a1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xb01>
 123b373:	48 89 c3             	mov    %rax,%rbx
 123b376:	4d 85 f6             	test   %r14,%r14
 123b379:	74 26                	je     123b3a1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xb01>
 123b37b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b37f:	48 8b 38             	mov    (%rax),%rdi
 123b382:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b386:	49 c1 e6 05          	shl    $0x5,%r14
 123b38a:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 123b38e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b392:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 123b399:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b39e:	ff 50 18             	call   *0x18(%rax)
 123b3a1:	48 83 7d a8 00       	cmpq   $0x0,-0x58(%rbp)
 123b3a6:	74 26                	je     123b3ce <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xb2e>
 123b3a8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b3ac:	48 8b 38             	mov    (%rax),%rdi
 123b3af:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b3b3:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 123b3b7:	48 01 c9             	add    %rcx,%rcx
 123b3ba:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b3be:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b3c2:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 123b3c6:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b3cb:	ff 50 18             	call   *0x18(%rax)
 123b3ce:	48 8b 95 30 f1 ff ff 	mov    -0xed0(%rbp),%rdx
 123b3d5:	48 85 d2             	test   %rdx,%rdx
 123b3d8:	74 21                	je     123b3fb <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xb5b>
 123b3da:	48 8b b5 28 f1 ff ff 	mov    -0xed8(%rbp),%rsi
 123b3e1:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b3e5:	48 8b 38             	mov    (%rax),%rdi
 123b3e8:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b3ec:	48 01 d2             	add    %rdx,%rdx
 123b3ef:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b3f3:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b3f8:	ff 50 18             	call   *0x18(%rax)
 123b3fb:	48 8b 7d 80          	mov    -0x80(%rbp),%rdi
 123b3ff:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123b403:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 123b407:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 123b40b:	e8 90 b1 03 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 123b410:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 123b415:	74 27                	je     123b43e <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xb9e>
 123b417:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b41b:	48 8b 38             	mov    (%rax),%rdi
 123b41e:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b422:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123b426:	48 c1 e1 05          	shl    $0x5,%rcx
 123b42a:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b42e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b432:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123b436:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b43b:	ff 50 18             	call   *0x18(%rax)
 123b43e:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 123b443:	74 26                	je     123b46b <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xbcb>
 123b445:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 123b449:	49 8b 3f             	mov    (%r15),%rdi
 123b44c:	49 8b 47 08          	mov    0x8(%r15),%rax
 123b450:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123b454:	48 01 c9             	add    %rcx,%rcx
 123b457:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b45b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b45f:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 123b463:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b468:	ff 50 18             	call   *0x18(%rax)
 123b46b:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 123b472:	74 25                	je     123b499 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xbf9>
 123b474:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 123b47b:	48 69 8d 20 ff ff ff 	imul   $0x118,-0xe0(%rbp),%rcx
 123b482:	18 01 00 00 
 123b486:	89 da                	mov    %ebx,%edx
 123b488:	c1 e2 04             	shl    $0x4,%edx
 123b48b:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123b492:	01 
 123b493:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123b499:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123b4a0:	e8 cb bc 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b4a5:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 123b4a9:	66 89 58 10          	mov    %bx,0x10(%rax)
 123b4ad:	e9 97 fa ff ff       	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>
 123b4b2:	89 c3                	mov    %eax,%ebx
 123b4b4:	4d 85 f6             	test   %r14,%r14
 123b4b7:	74 26                	je     123b4df <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xc3f>
 123b4b9:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b4bd:	48 8b 38             	mov    (%rax),%rdi
 123b4c0:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b4c4:	49 c1 e6 05          	shl    $0x5,%r14
 123b4c8:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 123b4cc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b4d0:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 123b4d7:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b4dc:	ff 50 18             	call   *0x18(%rax)
 123b4df:	48 83 7d a8 00       	cmpq   $0x0,-0x58(%rbp)
 123b4e4:	74 26                	je     123b50c <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xc6c>
 123b4e6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b4ea:	48 8b 38             	mov    (%rax),%rdi
 123b4ed:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b4f1:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 123b4f5:	48 01 c9             	add    %rcx,%rcx
 123b4f8:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b4fc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b500:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 123b504:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b509:	ff 50 18             	call   *0x18(%rax)
 123b50c:	48 8b 95 30 f1 ff ff 	mov    -0xed0(%rbp),%rdx
 123b513:	48 85 d2             	test   %rdx,%rdx
 123b516:	74 21                	je     123b539 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xc99>
 123b518:	48 8b b5 28 f1 ff ff 	mov    -0xed8(%rbp),%rsi
 123b51f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b523:	48 8b 38             	mov    (%rax),%rdi
 123b526:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b52a:	48 01 d2             	add    %rdx,%rdx
 123b52d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b531:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b536:	ff 50 18             	call   *0x18(%rax)
 123b539:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 123b540:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 123b547:	48 8b 7d 80          	mov    -0x80(%rbp),%rdi
 123b54b:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123b54f:	e8 4c b0 03 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 123b554:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 123b559:	74 27                	je     123b582 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xce2>
 123b55b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123b55f:	48 8b 38             	mov    (%rax),%rdi
 123b562:	48 8b 40 08          	mov    0x8(%rax),%rax
 123b566:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123b56a:	48 c1 e1 05          	shl    $0x5,%rcx
 123b56e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b572:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b576:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123b57a:	b9 03 00 00 00       	mov    $0x3,%ecx
 123b57f:	ff 50 18             	call   *0x18(%rax)
 123b582:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 123b587:	74 26                	je     123b5af <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xd0f>
 123b589:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 123b58d:	49 8b 3f             	mov    (%r15),%rdi
 123b590:	49 8b 47 08          	mov    0x8(%r15),%rax
 123b594:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 123b598:	48 01 c9             	add    %rcx,%rcx
 123b59b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 123b59f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b5a3:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 123b5a7:	b9 01 00 00 00       	mov    $0x1,%ecx
 123b5ac:	ff 50 18             	call   *0x18(%rax)
 123b5af:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 123b5b6:	74 26                	je     123b5de <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0xd3e>
 123b5b8:	48 69 85 20 ff ff ff 	imul   $0x118,-0xe0(%rbp),%rax
 123b5bf:	18 01 00 00 
 123b5c3:	48 8b 8d 10 ff ff ff 	mov    -0xf0(%rbp),%rcx
 123b5ca:	0f b7 d3             	movzwl %bx,%edx
 123b5cd:	c1 e2 04             	shl    $0x4,%edx
 123b5d0:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123b5d7:	01 
 123b5d8:	c5 f8 11 44 01 68    	vmovups %xmm0,0x68(%rcx,%rax,1)
 123b5de:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123b5e5:	e8 86 bb 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b5ea:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 123b5ee:	66 89 58 10          	mov    %bx,0x10(%rax)
 123b5f2:	e9 52 f9 ff ff       	jmp    123af49 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486+0x6a9>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
