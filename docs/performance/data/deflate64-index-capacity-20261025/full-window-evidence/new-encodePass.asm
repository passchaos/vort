
/tmp/vort-deflate64-index-capacity-20261025/new-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001063a20 <deflate64_index_probe.encodePass>:
 1063a20:	55                   	push   %rbp
 1063a21:	48 89 e5             	mov    %rsp,%rbp
 1063a24:	41 57                	push   %r15
 1063a26:	41 56                	push   %r14
 1063a28:	41 54                	push   %r12
 1063a2a:	53                   	push   %rbx
 1063a2b:	48 83 ec 20          	sub    $0x20,%rsp
 1063a2f:	48 89 fb             	mov    %rdi,%rbx
 1063a32:	4c 8b 36             	mov    (%rsi),%r14
 1063a35:	4c 8b 7e 08          	mov    0x8(%rsi),%r15
 1063a39:	48 8d 7d c8          	lea    -0x38(%rbp),%rdi
 1063a3d:	e8 6e c0 ff ff       	call   105fab0 <deflate64.encoder.encodeAlloc>
 1063a42:	0f b7 45 d8          	movzwl -0x28(%rbp),%eax
 1063a46:	66 85 c0             	test   %ax,%ax
 1063a49:	0f 85 38 01 00 00    	jne    1063b87 <deflate64_index_probe.encodePass+0x167>
 1063a4f:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 1063a53:	48 85 d2             	test   %rdx,%rdx
 1063a56:	74 22                	je     1063a7a <deflate64_index_probe.encodePass+0x5a>
 1063a58:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 1063a5c:	89 d0                	mov    %edx,%eax
 1063a5e:	83 e0 07             	and    $0x7,%eax
 1063a61:	48 83 fa 08          	cmp    $0x8,%rdx
 1063a65:	73 1b                	jae    1063a82 <deflate64_index_probe.encodePass+0x62>
 1063a67:	31 c9                	xor    %ecx,%ecx
 1063a69:	49 89 d4             	mov    %rdx,%r12
 1063a6c:	48 85 c0             	test   %rax,%rax
 1063a6f:	0f 85 cd 00 00 00    	jne    1063b42 <deflate64_index_probe.encodePass+0x122>
 1063a75:	e9 ea 00 00 00       	jmp    1063b64 <deflate64_index_probe.encodePass+0x144>
 1063a7a:	45 31 e4             	xor    %r12d,%r12d
 1063a7d:	e9 ef 00 00 00       	jmp    1063b71 <deflate64_index_probe.encodePass+0x151>
 1063a82:	48 89 d7             	mov    %rdx,%rdi
 1063a85:	48 83 e7 f8          	and    $0xfffffffffffffff8,%rdi
 1063a89:	48 f7 df             	neg    %rdi
 1063a8c:	b9 04 00 00 00       	mov    $0x4,%ecx
 1063a91:	49 89 d4             	mov    %rdx,%r12
 1063a94:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1063a9b:	00 00 00 00 00 
 1063aa0:	44 0f b6 44 0e fc    	movzbl -0x4(%rsi,%rcx,1),%r8d
 1063aa6:	4c 8d 49 fd          	lea    -0x3(%rcx),%r9
 1063aaa:	4d 0f af c8          	imul   %r8,%r9
 1063aae:	4d 01 e1             	add    %r12,%r9
 1063ab1:	44 0f b6 44 0e fd    	movzbl -0x3(%rsi,%rcx,1),%r8d
 1063ab7:	4c 8d 51 fe          	lea    -0x2(%rcx),%r10
 1063abb:	4d 0f af d0          	imul   %r8,%r10
 1063abf:	44 0f b6 44 0e fe    	movzbl -0x2(%rsi,%rcx,1),%r8d
 1063ac5:	4c 8d 59 ff          	lea    -0x1(%rcx),%r11
 1063ac9:	4d 0f af d8          	imul   %r8,%r11
 1063acd:	4d 01 d3             	add    %r10,%r11
 1063ad0:	4d 01 cb             	add    %r9,%r11
 1063ad3:	44 0f b6 44 0e ff    	movzbl -0x1(%rsi,%rcx,1),%r8d
 1063ad9:	4c 0f af c1          	imul   %rcx,%r8
 1063add:	44 0f b6 0c 0e       	movzbl (%rsi,%rcx,1),%r9d
 1063ae2:	4c 8d 51 01          	lea    0x1(%rcx),%r10
 1063ae6:	4d 0f af d1          	imul   %r9,%r10
 1063aea:	4d 01 c2             	add    %r8,%r10
 1063aed:	44 0f b6 44 0e 01    	movzbl 0x1(%rsi,%rcx,1),%r8d
 1063af3:	4c 8d 49 02          	lea    0x2(%rcx),%r9
 1063af7:	4d 0f af c8          	imul   %r8,%r9
 1063afb:	4d 01 d1             	add    %r10,%r9
 1063afe:	4d 01 d9             	add    %r11,%r9
 1063b01:	44 0f b6 44 0e 02    	movzbl 0x2(%rsi,%rcx,1),%r8d
 1063b07:	4c 8d 51 03          	lea    0x3(%rcx),%r10
 1063b0b:	4d 0f af d0          	imul   %r8,%r10
 1063b0f:	44 0f b6 44 0e 03    	movzbl 0x3(%rsi,%rcx,1),%r8d
 1063b15:	4c 8d 61 04          	lea    0x4(%rcx),%r12
 1063b19:	4d 0f af e0          	imul   %r8,%r12
 1063b1d:	4d 01 d4             	add    %r10,%r12
 1063b20:	4d 01 cc             	add    %r9,%r12
 1063b23:	4c 8d 04 0f          	lea    (%rdi,%rcx,1),%r8
 1063b27:	49 83 c0 08          	add    $0x8,%r8
 1063b2b:	48 83 c1 08          	add    $0x8,%rcx
 1063b2f:	49 83 f8 04          	cmp    $0x4,%r8
 1063b33:	0f 85 67 ff ff ff    	jne    1063aa0 <deflate64_index_probe.encodePass+0x80>
 1063b39:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 1063b3d:	48 85 c0             	test   %rax,%rax
 1063b40:	74 22                	je     1063b64 <deflate64_index_probe.encodePass+0x144>
 1063b42:	48 ff c1             	inc    %rcx
 1063b45:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 1063b4c:	00 00 00 00 
 1063b50:	0f b6 7c 0e ff       	movzbl -0x1(%rsi,%rcx,1),%edi
 1063b55:	48 0f af f9          	imul   %rcx,%rdi
 1063b59:	49 01 fc             	add    %rdi,%r12
 1063b5c:	48 ff c1             	inc    %rcx
 1063b5f:	48 ff c8             	dec    %rax
 1063b62:	75 ec                	jne    1063b50 <deflate64_index_probe.encodePass+0x130>
 1063b64:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1063b68:	4c 89 f7             	mov    %r14,%rdi
 1063b6b:	31 c9                	xor    %ecx,%ecx
 1063b6d:	41 ff 57 18          	call   *0x18(%r15)
 1063b71:	66 c7 43 08 00 00    	movw   $0x0,0x8(%rbx)
 1063b77:	4c 89 23             	mov    %r12,(%rbx)
 1063b7a:	48 83 c4 20          	add    $0x20,%rsp
 1063b7e:	5b                   	pop    %rbx
 1063b7f:	41 5c                	pop    %r12
 1063b81:	41 5e                	pop    %r14
 1063b83:	41 5f                	pop    %r15
 1063b85:	5d                   	pop    %rbp
 1063b86:	c3                   	ret    
 1063b87:	66 89 43 08          	mov    %ax,0x8(%rbx)
 1063b8b:	eb ed                	jmp    1063b7a <deflate64_index_probe.encodePass+0x15a>
