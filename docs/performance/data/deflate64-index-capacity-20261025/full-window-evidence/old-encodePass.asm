
/tmp/vort-deflate64-index-capacity-20261025/old-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001063a40 <deflate64_index_probe.encodePass>:
 1063a40:	55                   	push   %rbp
 1063a41:	48 89 e5             	mov    %rsp,%rbp
 1063a44:	41 57                	push   %r15
 1063a46:	41 56                	push   %r14
 1063a48:	41 54                	push   %r12
 1063a4a:	53                   	push   %rbx
 1063a4b:	48 83 ec 20          	sub    $0x20,%rsp
 1063a4f:	48 89 fb             	mov    %rdi,%rbx
 1063a52:	4c 8b 36             	mov    (%rsi),%r14
 1063a55:	4c 8b 7e 08          	mov    0x8(%rsi),%r15
 1063a59:	48 8d 7d c8          	lea    -0x38(%rbp),%rdi
 1063a5d:	e8 0e c0 ff ff       	call   105fa70 <deflate64.encoder.encodeAlloc>
 1063a62:	0f b7 45 d8          	movzwl -0x28(%rbp),%eax
 1063a66:	66 85 c0             	test   %ax,%ax
 1063a69:	0f 85 38 01 00 00    	jne    1063ba7 <deflate64_index_probe.encodePass+0x167>
 1063a6f:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 1063a73:	48 85 d2             	test   %rdx,%rdx
 1063a76:	74 22                	je     1063a9a <deflate64_index_probe.encodePass+0x5a>
 1063a78:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 1063a7c:	89 d0                	mov    %edx,%eax
 1063a7e:	83 e0 07             	and    $0x7,%eax
 1063a81:	48 83 fa 08          	cmp    $0x8,%rdx
 1063a85:	73 1b                	jae    1063aa2 <deflate64_index_probe.encodePass+0x62>
 1063a87:	31 c9                	xor    %ecx,%ecx
 1063a89:	49 89 d4             	mov    %rdx,%r12
 1063a8c:	48 85 c0             	test   %rax,%rax
 1063a8f:	0f 85 cd 00 00 00    	jne    1063b62 <deflate64_index_probe.encodePass+0x122>
 1063a95:	e9 ea 00 00 00       	jmp    1063b84 <deflate64_index_probe.encodePass+0x144>
 1063a9a:	45 31 e4             	xor    %r12d,%r12d
 1063a9d:	e9 ef 00 00 00       	jmp    1063b91 <deflate64_index_probe.encodePass+0x151>
 1063aa2:	48 89 d7             	mov    %rdx,%rdi
 1063aa5:	48 83 e7 f8          	and    $0xfffffffffffffff8,%rdi
 1063aa9:	48 f7 df             	neg    %rdi
 1063aac:	b9 04 00 00 00       	mov    $0x4,%ecx
 1063ab1:	49 89 d4             	mov    %rdx,%r12
 1063ab4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1063abb:	00 00 00 00 00 
 1063ac0:	44 0f b6 44 0e fc    	movzbl -0x4(%rsi,%rcx,1),%r8d
 1063ac6:	4c 8d 49 fd          	lea    -0x3(%rcx),%r9
 1063aca:	4d 0f af c8          	imul   %r8,%r9
 1063ace:	4d 01 e1             	add    %r12,%r9
 1063ad1:	44 0f b6 44 0e fd    	movzbl -0x3(%rsi,%rcx,1),%r8d
 1063ad7:	4c 8d 51 fe          	lea    -0x2(%rcx),%r10
 1063adb:	4d 0f af d0          	imul   %r8,%r10
 1063adf:	44 0f b6 44 0e fe    	movzbl -0x2(%rsi,%rcx,1),%r8d
 1063ae5:	4c 8d 59 ff          	lea    -0x1(%rcx),%r11
 1063ae9:	4d 0f af d8          	imul   %r8,%r11
 1063aed:	4d 01 d3             	add    %r10,%r11
 1063af0:	4d 01 cb             	add    %r9,%r11
 1063af3:	44 0f b6 44 0e ff    	movzbl -0x1(%rsi,%rcx,1),%r8d
 1063af9:	4c 0f af c1          	imul   %rcx,%r8
 1063afd:	44 0f b6 0c 0e       	movzbl (%rsi,%rcx,1),%r9d
 1063b02:	4c 8d 51 01          	lea    0x1(%rcx),%r10
 1063b06:	4d 0f af d1          	imul   %r9,%r10
 1063b0a:	4d 01 c2             	add    %r8,%r10
 1063b0d:	44 0f b6 44 0e 01    	movzbl 0x1(%rsi,%rcx,1),%r8d
 1063b13:	4c 8d 49 02          	lea    0x2(%rcx),%r9
 1063b17:	4d 0f af c8          	imul   %r8,%r9
 1063b1b:	4d 01 d1             	add    %r10,%r9
 1063b1e:	4d 01 d9             	add    %r11,%r9
 1063b21:	44 0f b6 44 0e 02    	movzbl 0x2(%rsi,%rcx,1),%r8d
 1063b27:	4c 8d 51 03          	lea    0x3(%rcx),%r10
 1063b2b:	4d 0f af d0          	imul   %r8,%r10
 1063b2f:	44 0f b6 44 0e 03    	movzbl 0x3(%rsi,%rcx,1),%r8d
 1063b35:	4c 8d 61 04          	lea    0x4(%rcx),%r12
 1063b39:	4d 0f af e0          	imul   %r8,%r12
 1063b3d:	4d 01 d4             	add    %r10,%r12
 1063b40:	4d 01 cc             	add    %r9,%r12
 1063b43:	4c 8d 04 0f          	lea    (%rdi,%rcx,1),%r8
 1063b47:	49 83 c0 08          	add    $0x8,%r8
 1063b4b:	48 83 c1 08          	add    $0x8,%rcx
 1063b4f:	49 83 f8 04          	cmp    $0x4,%r8
 1063b53:	0f 85 67 ff ff ff    	jne    1063ac0 <deflate64_index_probe.encodePass+0x80>
 1063b59:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 1063b5d:	48 85 c0             	test   %rax,%rax
 1063b60:	74 22                	je     1063b84 <deflate64_index_probe.encodePass+0x144>
 1063b62:	48 ff c1             	inc    %rcx
 1063b65:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 1063b6c:	00 00 00 00 
 1063b70:	0f b6 7c 0e ff       	movzbl -0x1(%rsi,%rcx,1),%edi
 1063b75:	48 0f af f9          	imul   %rcx,%rdi
 1063b79:	49 01 fc             	add    %rdi,%r12
 1063b7c:	48 ff c1             	inc    %rcx
 1063b7f:	48 ff c8             	dec    %rax
 1063b82:	75 ec                	jne    1063b70 <deflate64_index_probe.encodePass+0x130>
 1063b84:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1063b88:	4c 89 f7             	mov    %r14,%rdi
 1063b8b:	31 c9                	xor    %ecx,%ecx
 1063b8d:	41 ff 57 18          	call   *0x18(%r15)
 1063b91:	66 c7 43 08 00 00    	movw   $0x0,0x8(%rbx)
 1063b97:	4c 89 23             	mov    %r12,(%rbx)
 1063b9a:	48 83 c4 20          	add    $0x20,%rsp
 1063b9e:	5b                   	pop    %rbx
 1063b9f:	41 5c                	pop    %r12
 1063ba1:	41 5e                	pop    %r14
 1063ba3:	41 5f                	pop    %r15
 1063ba5:	5d                   	pop    %rbp
 1063ba6:	c3                   	ret    
 1063ba7:	66 89 43 08          	mov    %ax,0x8(%rbx)
 1063bab:	eb ed                	jmp    1063b9a <deflate64_index_probe.encodePass+0x15a>
