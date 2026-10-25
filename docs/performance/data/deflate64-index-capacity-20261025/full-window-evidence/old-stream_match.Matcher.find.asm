
/tmp/vort-deflate64-index-capacity-20261025/old-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001091970 <deflate64.stream_match.Matcher.find>:
 1091970:	48 8b 46 28          	mov    0x28(%rsi),%rax
 1091974:	49 89 c3             	mov    %rax,%r11
 1091977:	49 29 d3             	sub    %rdx,%r11
 109197a:	4c 03 5e 38          	add    0x38(%rsi),%r11
 109197e:	49 83 fb 03          	cmp    $0x3,%r11
 1091982:	41 0f 92 c1          	setb   %r9b
 1091986:	48 85 c9             	test   %rcx,%rcx
 1091989:	41 0f 94 c2          	sete   %r10b
 109198d:	45 08 ca             	or     %r9b,%r10b
 1091990:	41 80 fa 01          	cmp    $0x1,%r10b
 1091994:	75 09                	jne    109199f <deflate64.stream_match.Matcher.find+0x2f>
 1091996:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 109199a:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 109199e:	c3                   	ret    
 109199f:	55                   	push   %rbp
 10919a0:	48 89 e5             	mov    %rsp,%rbp
 10919a3:	41 57                	push   %r15
 10919a5:	41 56                	push   %r14
 10919a7:	41 55                	push   %r13
 10919a9:	41 54                	push   %r12
 10919ab:	53                   	push   %rbx
 10919ac:	49 81 fb 02 00 01 00 	cmp    $0x10002,%r11
 10919b3:	41 b9 02 00 01 00    	mov    $0x10002,%r9d
 10919b9:	4d 0f 42 cb          	cmovb  %r11,%r9
 10919bd:	49 89 d2             	mov    %rdx,%r10
 10919c0:	49 29 c2             	sub    %rax,%r10
 10919c3:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 10919c7:	73 09                	jae    10919d2 <deflate64.stream_match.Matcher.find+0x62>
 10919c9:	4c 8b 56 20          	mov    0x20(%rsi),%r10
 10919cd:	49 01 d2             	add    %rdx,%r10
 10919d0:	eb 04                	jmp    10919d6 <deflate64.stream_match.Matcher.find+0x66>
 10919d2:	4c 03 56 30          	add    0x30(%rsi),%r10
 10919d6:	45 0f b6 12          	movzbl (%r10),%r10d
 10919da:	48 8d 7a 01          	lea    0x1(%rdx),%rdi
 10919de:	49 89 fb             	mov    %rdi,%r11
 10919e1:	49 29 c3             	sub    %rax,%r11
 10919e4:	73 06                	jae    10919ec <deflate64.stream_match.Matcher.find+0x7c>
 10919e6:	48 03 7e 20          	add    0x20(%rsi),%rdi
 10919ea:	eb 07                	jmp    10919f3 <deflate64.stream_match.Matcher.find+0x83>
 10919ec:	4c 03 5e 30          	add    0x30(%rsi),%r11
 10919f0:	4c 89 df             	mov    %r11,%rdi
 10919f3:	44 0f b6 1f          	movzbl (%rdi),%r11d
 10919f7:	48 8d 5a 02          	lea    0x2(%rdx),%rbx
 10919fb:	48 89 df             	mov    %rbx,%rdi
 10919fe:	48 29 c7             	sub    %rax,%rdi
 1091a01:	73 06                	jae    1091a09 <deflate64.stream_match.Matcher.find+0x99>
 1091a03:	48 03 5e 20          	add    0x20(%rsi),%rbx
 1091a07:	eb 07                	jmp    1091a10 <deflate64.stream_match.Matcher.find+0xa0>
 1091a09:	48 03 7e 30          	add    0x30(%rsi),%rdi
 1091a0d:	48 89 fb             	mov    %rdi,%rbx
 1091a10:	41 c1 e2 10          	shl    $0x10,%r10d
 1091a14:	41 c1 e3 08          	shl    $0x8,%r11d
 1091a18:	45 09 d3             	or     %r10d,%r11d
 1091a1b:	0f b6 3b             	movzbl (%rbx),%edi
 1091a1e:	44 09 df             	or     %r11d,%edi
 1091a21:	69 ff bd a7 35 1e    	imul   $0x1e35a7bd,%edi,%edi
 1091a27:	4c 8b 16             	mov    (%rsi),%r10
 1091a2a:	c1 ef 11             	shr    $0x11,%edi
 1091a2d:	45 8b 3c ba          	mov    (%r10,%rdi,4),%r15d
 1091a31:	41 83 ff ff          	cmp    $0xffffffff,%r15d
 1091a35:	0f 84 e1 00 00 00    	je     1091b1c <deflate64.stream_match.Matcher.find+0x1ac>
 1091a3b:	45 31 d2             	xor    %r10d,%r10d
 1091a3e:	45 31 db             	xor    %r11d,%r11d
 1091a41:	31 ff                	xor    %edi,%edi
 1091a43:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1091a4a:	84 00 00 00 00 00 
 1091a50:	45 89 ff             	mov    %r15d,%r15d
 1091a53:	49 89 d6             	mov    %rdx,%r14
 1091a56:	4d 29 fe             	sub    %r15,%r14
 1091a59:	0f 86 b5 00 00 00    	jbe    1091b14 <deflate64.stream_match.Matcher.find+0x1a4>
 1091a5f:	49 81 fe 00 00 01 00 	cmp    $0x10000,%r14
 1091a66:	0f 87 a8 00 00 00    	ja     1091b14 <deflate64.stream_match.Matcher.find+0x1a4>
 1091a6c:	45 31 e4             	xor    %r12d,%r12d
 1091a6f:	90                   	nop
 1091a70:	4f 8d 2c 3c          	lea    (%r12,%r15,1),%r13
 1091a74:	49 29 c5             	sub    %rax,%r13
 1091a77:	73 27                	jae    1091aa0 <deflate64.stream_match.Matcher.find+0x130>
 1091a79:	4c 8b 6e 20          	mov    0x20(%rsi),%r13
 1091a7d:	4d 01 fd             	add    %r15,%r13
 1091a80:	4d 01 e5             	add    %r12,%r13
 1091a83:	49 8d 1c 14          	lea    (%r12,%rdx,1),%rbx
 1091a87:	48 29 c3             	sub    %rax,%rbx
 1091a8a:	72 21                	jb     1091aad <deflate64.stream_match.Matcher.find+0x13d>
 1091a8c:	48 03 5e 30          	add    0x30(%rsi),%rbx
 1091a90:	45 0f b6 6d 00       	movzbl 0x0(%r13),%r13d
 1091a95:	44 3a 2b             	cmp    (%rbx),%r13b
 1091a98:	74 27                	je     1091ac1 <deflate64.stream_match.Matcher.find+0x151>
 1091a9a:	eb 30                	jmp    1091acc <deflate64.stream_match.Matcher.find+0x15c>
 1091a9c:	0f 1f 40 00          	nopl   0x0(%rax)
 1091aa0:	4c 03 6e 30          	add    0x30(%rsi),%r13
 1091aa4:	49 8d 1c 14          	lea    (%r12,%rdx,1),%rbx
 1091aa8:	48 29 c3             	sub    %rax,%rbx
 1091aab:	73 df                	jae    1091a8c <deflate64.stream_match.Matcher.find+0x11c>
 1091aad:	48 8b 5e 20          	mov    0x20(%rsi),%rbx
 1091ab1:	48 01 d3             	add    %rdx,%rbx
 1091ab4:	4c 01 e3             	add    %r12,%rbx
 1091ab7:	45 0f b6 6d 00       	movzbl 0x0(%r13),%r13d
 1091abc:	44 3a 2b             	cmp    (%rbx),%r13b
 1091abf:	75 0b                	jne    1091acc <deflate64.stream_match.Matcher.find+0x15c>
 1091ac1:	49 ff c4             	inc    %r12
 1091ac4:	4d 39 e1             	cmp    %r12,%r9
 1091ac7:	75 a7                	jne    1091a70 <deflate64.stream_match.Matcher.find+0x100>
 1091ac9:	4d 89 cc             	mov    %r9,%r12
 1091acc:	49 83 fc 03          	cmp    $0x3,%r12
 1091ad0:	0f 93 c3             	setae  %bl
 1091ad3:	4d 39 dc             	cmp    %r11,%r12
 1091ad6:	41 0f 97 c5          	seta   %r13b
 1091ada:	41 20 dd             	and    %bl,%r13b
 1091add:	41 80 fd 01          	cmp    $0x1,%r13b
 1091ae1:	75 0b                	jne    1091aee <deflate64.stream_match.Matcher.find+0x17e>
 1091ae3:	4c 89 f7             	mov    %r14,%rdi
 1091ae6:	4d 89 e3             	mov    %r12,%r11
 1091ae9:	4d 39 c4             	cmp    %r8,%r12
 1091aec:	73 34                	jae    1091b22 <deflate64.stream_match.Matcher.find+0x1b2>
 1091aee:	41 0f b7 df          	movzwl %r15w,%ebx
 1091af2:	4c 8b 76 10          	mov    0x10(%rsi),%r14
 1091af6:	45 8b 3c 9e          	mov    (%r14,%rbx,4),%r15d
 1091afa:	41 83 ff ff          	cmp    $0xffffffff,%r15d
 1091afe:	74 14                	je     1091b14 <deflate64.stream_match.Matcher.find+0x1a4>
 1091b00:	49 ff c2             	inc    %r10
 1091b03:	49 89 fe             	mov    %rdi,%r14
 1091b06:	4d 89 dc             	mov    %r11,%r12
 1091b09:	49 39 ca             	cmp    %rcx,%r10
 1091b0c:	0f 82 3e ff ff ff    	jb     1091a50 <deflate64.stream_match.Matcher.find+0xe0>
 1091b12:	eb 0e                	jmp    1091b22 <deflate64.stream_match.Matcher.find+0x1b2>
 1091b14:	49 89 fe             	mov    %rdi,%r14
 1091b17:	4d 89 dc             	mov    %r11,%r12
 1091b1a:	eb 06                	jmp    1091b22 <deflate64.stream_match.Matcher.find+0x1b2>
 1091b1c:	45 31 f6             	xor    %r14d,%r14d
 1091b1f:	45 31 e4             	xor    %r12d,%r12d
 1091b22:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1091b26:	4c 89 20             	mov    %r12,(%rax)
 1091b29:	4c 89 70 08          	mov    %r14,0x8(%rax)
 1091b2d:	5b                   	pop    %rbx
 1091b2e:	41 5c                	pop    %r12
 1091b30:	41 5d                	pop    %r13
 1091b32:	41 5e                	pop    %r14
 1091b34:	41 5f                	pop    %r15
 1091b36:	5d                   	pop    %rbp
 1091b37:	c3                   	ret    
