
/tmp/vort-deflate64-index-capacity-20261025/new-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001091900 <deflate64.stream_match.Matcher.find>:
 1091900:	48 8b 46 28          	mov    0x28(%rsi),%rax
 1091904:	49 89 c3             	mov    %rax,%r11
 1091907:	49 29 d3             	sub    %rdx,%r11
 109190a:	4c 03 5e 38          	add    0x38(%rsi),%r11
 109190e:	49 83 fb 03          	cmp    $0x3,%r11
 1091912:	41 0f 92 c1          	setb   %r9b
 1091916:	48 85 c9             	test   %rcx,%rcx
 1091919:	41 0f 94 c2          	sete   %r10b
 109191d:	45 08 ca             	or     %r9b,%r10b
 1091920:	41 80 fa 01          	cmp    $0x1,%r10b
 1091924:	75 09                	jne    109192f <deflate64.stream_match.Matcher.find+0x2f>
 1091926:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 109192a:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 109192e:	c3                   	ret    
 109192f:	55                   	push   %rbp
 1091930:	48 89 e5             	mov    %rsp,%rbp
 1091933:	41 57                	push   %r15
 1091935:	41 56                	push   %r14
 1091937:	41 55                	push   %r13
 1091939:	41 54                	push   %r12
 109193b:	53                   	push   %rbx
 109193c:	49 81 fb 02 00 01 00 	cmp    $0x10002,%r11
 1091943:	41 b9 02 00 01 00    	mov    $0x10002,%r9d
 1091949:	4d 0f 42 cb          	cmovb  %r11,%r9
 109194d:	49 89 d2             	mov    %rdx,%r10
 1091950:	49 29 c2             	sub    %rax,%r10
 1091953:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 1091957:	73 09                	jae    1091962 <deflate64.stream_match.Matcher.find+0x62>
 1091959:	4c 8b 56 20          	mov    0x20(%rsi),%r10
 109195d:	49 01 d2             	add    %rdx,%r10
 1091960:	eb 04                	jmp    1091966 <deflate64.stream_match.Matcher.find+0x66>
 1091962:	4c 03 56 30          	add    0x30(%rsi),%r10
 1091966:	45 0f b6 12          	movzbl (%r10),%r10d
 109196a:	48 8d 7a 01          	lea    0x1(%rdx),%rdi
 109196e:	49 89 fb             	mov    %rdi,%r11
 1091971:	49 29 c3             	sub    %rax,%r11
 1091974:	73 06                	jae    109197c <deflate64.stream_match.Matcher.find+0x7c>
 1091976:	48 03 7e 20          	add    0x20(%rsi),%rdi
 109197a:	eb 07                	jmp    1091983 <deflate64.stream_match.Matcher.find+0x83>
 109197c:	4c 03 5e 30          	add    0x30(%rsi),%r11
 1091980:	4c 89 df             	mov    %r11,%rdi
 1091983:	44 0f b6 1f          	movzbl (%rdi),%r11d
 1091987:	48 8d 5a 02          	lea    0x2(%rdx),%rbx
 109198b:	48 89 df             	mov    %rbx,%rdi
 109198e:	48 29 c7             	sub    %rax,%rdi
 1091991:	73 06                	jae    1091999 <deflate64.stream_match.Matcher.find+0x99>
 1091993:	48 03 5e 20          	add    0x20(%rsi),%rbx
 1091997:	eb 07                	jmp    10919a0 <deflate64.stream_match.Matcher.find+0xa0>
 1091999:	48 03 7e 30          	add    0x30(%rsi),%rdi
 109199d:	48 89 fb             	mov    %rdi,%rbx
 10919a0:	41 c1 e2 10          	shl    $0x10,%r10d
 10919a4:	41 c1 e3 08          	shl    $0x8,%r11d
 10919a8:	45 09 d3             	or     %r10d,%r11d
 10919ab:	0f b6 3b             	movzbl (%rbx),%edi
 10919ae:	44 09 df             	or     %r11d,%edi
 10919b1:	69 ff bd a7 35 1e    	imul   $0x1e35a7bd,%edi,%edi
 10919b7:	4c 8b 16             	mov    (%rsi),%r10
 10919ba:	c1 ef 11             	shr    $0x11,%edi
 10919bd:	45 8b 3c ba          	mov    (%r10,%rdi,4),%r15d
 10919c1:	41 83 ff ff          	cmp    $0xffffffff,%r15d
 10919c5:	0f 84 e5 00 00 00    	je     1091ab0 <deflate64.stream_match.Matcher.find+0x1b0>
 10919cb:	45 31 d2             	xor    %r10d,%r10d
 10919ce:	45 31 db             	xor    %r11d,%r11d
 10919d1:	31 ff                	xor    %edi,%edi
 10919d3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10919da:	84 00 00 00 00 00 
 10919e0:	45 89 ff             	mov    %r15d,%r15d
 10919e3:	49 89 d6             	mov    %rdx,%r14
 10919e6:	4d 29 fe             	sub    %r15,%r14
 10919e9:	0f 86 b9 00 00 00    	jbe    1091aa8 <deflate64.stream_match.Matcher.find+0x1a8>
 10919ef:	49 81 fe 00 00 01 00 	cmp    $0x10000,%r14
 10919f6:	0f 87 ac 00 00 00    	ja     1091aa8 <deflate64.stream_match.Matcher.find+0x1a8>
 10919fc:	45 31 e4             	xor    %r12d,%r12d
 10919ff:	90                   	nop
 1091a00:	4f 8d 2c 3c          	lea    (%r12,%r15,1),%r13
 1091a04:	49 29 c5             	sub    %rax,%r13
 1091a07:	73 27                	jae    1091a30 <deflate64.stream_match.Matcher.find+0x130>
 1091a09:	4c 8b 6e 20          	mov    0x20(%rsi),%r13
 1091a0d:	4d 01 fd             	add    %r15,%r13
 1091a10:	4d 01 e5             	add    %r12,%r13
 1091a13:	49 8d 1c 14          	lea    (%r12,%rdx,1),%rbx
 1091a17:	48 29 c3             	sub    %rax,%rbx
 1091a1a:	72 21                	jb     1091a3d <deflate64.stream_match.Matcher.find+0x13d>
 1091a1c:	48 03 5e 30          	add    0x30(%rsi),%rbx
 1091a20:	45 0f b6 6d 00       	movzbl 0x0(%r13),%r13d
 1091a25:	44 3a 2b             	cmp    (%rbx),%r13b
 1091a28:	74 27                	je     1091a51 <deflate64.stream_match.Matcher.find+0x151>
 1091a2a:	eb 30                	jmp    1091a5c <deflate64.stream_match.Matcher.find+0x15c>
 1091a2c:	0f 1f 40 00          	nopl   0x0(%rax)
 1091a30:	4c 03 6e 30          	add    0x30(%rsi),%r13
 1091a34:	49 8d 1c 14          	lea    (%r12,%rdx,1),%rbx
 1091a38:	48 29 c3             	sub    %rax,%rbx
 1091a3b:	73 df                	jae    1091a1c <deflate64.stream_match.Matcher.find+0x11c>
 1091a3d:	48 8b 5e 20          	mov    0x20(%rsi),%rbx
 1091a41:	48 01 d3             	add    %rdx,%rbx
 1091a44:	4c 01 e3             	add    %r12,%rbx
 1091a47:	45 0f b6 6d 00       	movzbl 0x0(%r13),%r13d
 1091a4c:	44 3a 2b             	cmp    (%rbx),%r13b
 1091a4f:	75 0b                	jne    1091a5c <deflate64.stream_match.Matcher.find+0x15c>
 1091a51:	49 ff c4             	inc    %r12
 1091a54:	4d 39 e1             	cmp    %r12,%r9
 1091a57:	75 a7                	jne    1091a00 <deflate64.stream_match.Matcher.find+0x100>
 1091a59:	4d 89 cc             	mov    %r9,%r12
 1091a5c:	49 83 fc 03          	cmp    $0x3,%r12
 1091a60:	0f 93 c3             	setae  %bl
 1091a63:	4d 39 dc             	cmp    %r11,%r12
 1091a66:	41 0f 97 c5          	seta   %r13b
 1091a6a:	41 20 dd             	and    %bl,%r13b
 1091a6d:	41 80 fd 01          	cmp    $0x1,%r13b
 1091a71:	75 0b                	jne    1091a7e <deflate64.stream_match.Matcher.find+0x17e>
 1091a73:	4c 89 f7             	mov    %r14,%rdi
 1091a76:	4d 89 e3             	mov    %r12,%r11
 1091a79:	4d 39 c4             	cmp    %r8,%r12
 1091a7c:	73 38                	jae    1091ab6 <deflate64.stream_match.Matcher.find+0x1b6>
 1091a7e:	8b 5e 18             	mov    0x18(%rsi),%ebx
 1091a81:	ff cb                	dec    %ebx
 1091a83:	41 21 df             	and    %ebx,%r15d
 1091a86:	48 8b 5e 10          	mov    0x10(%rsi),%rbx
 1091a8a:	46 8b 3c bb          	mov    (%rbx,%r15,4),%r15d
 1091a8e:	41 83 ff ff          	cmp    $0xffffffff,%r15d
 1091a92:	74 14                	je     1091aa8 <deflate64.stream_match.Matcher.find+0x1a8>
 1091a94:	49 ff c2             	inc    %r10
 1091a97:	49 89 fe             	mov    %rdi,%r14
 1091a9a:	4d 89 dc             	mov    %r11,%r12
 1091a9d:	49 39 ca             	cmp    %rcx,%r10
 1091aa0:	0f 82 3a ff ff ff    	jb     10919e0 <deflate64.stream_match.Matcher.find+0xe0>
 1091aa6:	eb 0e                	jmp    1091ab6 <deflate64.stream_match.Matcher.find+0x1b6>
 1091aa8:	49 89 fe             	mov    %rdi,%r14
 1091aab:	4d 89 dc             	mov    %r11,%r12
 1091aae:	eb 06                	jmp    1091ab6 <deflate64.stream_match.Matcher.find+0x1b6>
 1091ab0:	45 31 f6             	xor    %r14d,%r14d
 1091ab3:	45 31 e4             	xor    %r12d,%r12d
 1091ab6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1091aba:	4c 89 20             	mov    %r12,(%rax)
 1091abd:	4c 89 70 08          	mov    %r14,0x8(%rax)
 1091ac1:	5b                   	pop    %rbx
 1091ac2:	41 5c                	pop    %r12
 1091ac4:	41 5d                	pop    %r13
 1091ac6:	41 5e                	pop    %r14
 1091ac8:	41 5f                	pop    %r15
 1091aca:	5d                   	pop    %rbp
 1091acb:	c3                   	ret    
