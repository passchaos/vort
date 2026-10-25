
/tmp/vort-deflate64-index-capacity-20261025/new-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001091ad0 <deflate64.stream_blocks.fixedPlan>:
 1091ad0:	4d 85 c9             	test   %r9,%r9
 1091ad3:	0f 84 b7 03 00 00    	je     1091e90 <deflate64.stream_blocks.fixedPlan+0x3c0>
 1091ad9:	55                   	push   %rbp
 1091ada:	48 89 e5             	mov    %rsp,%rbp
 1091add:	41 57                	push   %r15
 1091adf:	41 56                	push   %r14
 1091ae1:	41 55                	push   %r13
 1091ae3:	41 54                	push   %r12
 1091ae5:	53                   	push   %rbx
 1091ae6:	48 83 ec 58          	sub    $0x58,%rsp
 1091aea:	4d 89 cf             	mov    %r9,%r15
 1091aed:	49 89 ce             	mov    %rcx,%r14
 1091af0:	49 89 f5             	mov    %rsi,%r13
 1091af3:	48 89 7d b0          	mov    %rdi,-0x50(%rbp)
 1091af7:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
 1091afc:	48 89 56 20          	mov    %rdx,0x20(%rsi)
 1091b00:	48 89 4e 28          	mov    %rcx,0x28(%rsi)
 1091b04:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 1091b08:	4c 89 46 30          	mov    %r8,0x30(%rsi)
 1091b0c:	4c 89 4e 38          	mov    %r9,0x38(%rsi)
 1091b10:	48 8b 3e             	mov    (%rsi),%rdi
 1091b13:	ba 00 00 02 00       	mov    $0x20000,%edx
 1091b18:	be ff 00 00 00       	mov    $0xff,%esi
 1091b1d:	e8 8e 27 04 00       	call   10d42b0 <compiler_rt.memset>
 1091b22:	4d 85 f6             	test   %r14,%r14
 1091b25:	0f 84 ca 00 00 00    	je     1091bf5 <deflate64.stream_blocks.fixedPlan+0x125>
 1091b2b:	31 c0                	xor    %eax,%eax
 1091b2d:	eb 48                	jmp    1091b77 <deflate64.stream_blocks.fixedPlan+0xa7>
 1091b2f:	90                   	nop
 1091b30:	49 03 7d 30          	add    0x30(%r13),%rdi
 1091b34:	0f b6 09             	movzbl (%rcx),%ecx
 1091b37:	0f b6 16             	movzbl (%rsi),%edx
 1091b3a:	c1 e1 10             	shl    $0x10,%ecx
 1091b3d:	c1 e2 08             	shl    $0x8,%edx
 1091b40:	09 ca                	or     %ecx,%edx
 1091b42:	0f b6 0f             	movzbl (%rdi),%ecx
 1091b45:	09 d1                	or     %edx,%ecx
 1091b47:	69 c9 bd a7 35 1e    	imul   $0x1e35a7bd,%ecx,%ecx
 1091b4d:	49 8b 55 18          	mov    0x18(%r13),%rdx
 1091b51:	48 01 da             	add    %rbx,%rdx
 1091b54:	48 21 c2             	and    %rax,%rdx
 1091b57:	49 8b 75 00          	mov    0x0(%r13),%rsi
 1091b5b:	49 8b 7d 10          	mov    0x10(%r13),%rdi
 1091b5f:	c1 e9 11             	shr    $0x11,%ecx
 1091b62:	8b 34 8e             	mov    (%rsi,%rcx,4),%esi
 1091b65:	89 34 97             	mov    %esi,(%rdi,%rdx,4)
 1091b68:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091b6c:	89 04 8a             	mov    %eax,(%rdx,%rcx,4)
 1091b6f:	48 ff c0             	inc    %rax
 1091b72:	49 39 c6             	cmp    %rax,%r14
 1091b75:	74 7e                	je     1091bf5 <deflate64.stream_blocks.fixedPlan+0x125>
 1091b77:	48 8d 48 03          	lea    0x3(%rax),%rcx
 1091b7b:	49 8b 55 28          	mov    0x28(%r13),%rdx
 1091b7f:	49 8b 75 38          	mov    0x38(%r13),%rsi
 1091b83:	48 01 d6             	add    %rdx,%rsi
 1091b86:	48 39 f1             	cmp    %rsi,%rcx
 1091b89:	77 e4                	ja     1091b6f <deflate64.stream_blocks.fixedPlan+0x9f>
 1091b8b:	48 89 c1             	mov    %rax,%rcx
 1091b8e:	48 29 d1             	sub    %rdx,%rcx
 1091b91:	73 2d                	jae    1091bc0 <deflate64.stream_blocks.fixedPlan+0xf0>
 1091b93:	49 8b 4d 20          	mov    0x20(%r13),%rcx
 1091b97:	48 01 c1             	add    %rax,%rcx
 1091b9a:	48 8d 70 01          	lea    0x1(%rax),%rsi
 1091b9e:	48 29 d6             	sub    %rdx,%rsi
 1091ba1:	72 2a                	jb     1091bcd <deflate64.stream_blocks.fixedPlan+0xfd>
 1091ba3:	49 03 75 30          	add    0x30(%r13),%rsi
 1091ba7:	48 8d 78 02          	lea    0x2(%rax),%rdi
 1091bab:	48 29 d7             	sub    %rdx,%rdi
 1091bae:	73 80                	jae    1091b30 <deflate64.stream_blocks.fixedPlan+0x60>
 1091bb0:	eb 32                	jmp    1091be4 <deflate64.stream_blocks.fixedPlan+0x114>
 1091bb2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1091bb9:	1f 84 00 00 00 00 00 
 1091bc0:	49 03 4d 30          	add    0x30(%r13),%rcx
 1091bc4:	48 8d 70 01          	lea    0x1(%rax),%rsi
 1091bc8:	48 29 d6             	sub    %rdx,%rsi
 1091bcb:	73 d6                	jae    1091ba3 <deflate64.stream_blocks.fixedPlan+0xd3>
 1091bcd:	49 8b 75 20          	mov    0x20(%r13),%rsi
 1091bd1:	48 01 c6             	add    %rax,%rsi
 1091bd4:	48 ff c6             	inc    %rsi
 1091bd7:	48 8d 78 02          	lea    0x2(%rax),%rdi
 1091bdb:	48 29 d7             	sub    %rdx,%rdi
 1091bde:	0f 83 4c ff ff ff    	jae    1091b30 <deflate64.stream_blocks.fixedPlan+0x60>
 1091be4:	49 8b 55 20          	mov    0x20(%r13),%rdx
 1091be8:	48 8d 3c 02          	lea    (%rdx,%rax,1),%rdi
 1091bec:	48 83 c7 02          	add    $0x2,%rdi
 1091bf0:	e9 3f ff ff ff       	jmp    1091b34 <deflate64.stream_blocks.fixedPlan+0x64>
 1091bf5:	4c 89 75 a0          	mov    %r14,-0x60(%rbp)
 1091bf9:	41 be 0a 00 00 00    	mov    $0xa,%r14d
 1091bff:	45 31 e4             	xor    %r12d,%r12d
 1091c02:	48 c7 45 c0 00 00 00 	movq   $0x0,-0x40(%rbp)
 1091c09:	00 
 1091c0a:	48 c7 45 c8 00 00 00 	movq   $0x0,-0x38(%rbp)
 1091c11:	00 
 1091c12:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 1091c19:	00 
 1091c1a:	4c 89 7d 98          	mov    %r15,-0x68(%rbp)
 1091c1e:	eb 16                	jmp    1091c36 <deflate64.stream_blocks.fixedPlan+0x166>
 1091c20:	0f b6 c9             	movzbl %cl,%ecx
 1091c23:	49 01 ce             	add    %rcx,%r14
 1091c26:	49 01 c4             	add    %rax,%r12
 1091c29:	4c 8b 7d 98          	mov    -0x68(%rbp),%r15
 1091c2d:	4d 39 fc             	cmp    %r15,%r12
 1091c30:	0f 83 2c 02 00 00    	jae    1091e62 <deflate64.stream_blocks.fixedPlan+0x392>
 1091c36:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 1091c3a:	4d 8d 3c 04          	lea    (%r12,%rax,1),%r15
 1091c3e:	48 8d 7d 88          	lea    -0x78(%rbp),%rdi
 1091c42:	4c 89 ee             	mov    %r13,%rsi
 1091c45:	4c 89 fa             	mov    %r15,%rdx
 1091c48:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 1091c4c:	4c 8b 45 18          	mov    0x18(%rbp),%r8
 1091c50:	e8 ab fc ff ff       	call   1091900 <deflate64.stream_match.Matcher.find>
 1091c55:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 1091c59:	48 83 fa 03          	cmp    $0x3,%rdx
 1091c5d:	b8 01 00 00 00       	mov    $0x1,%eax
 1091c62:	48 0f 43 c2          	cmovae %rdx,%rax
 1091c66:	72 18                	jb     1091c80 <deflate64.stream_blocks.fixedPlan+0x1b0>
 1091c68:	48 81 fa 02 01 00 00 	cmp    $0x102,%rdx
 1091c6f:	76 2f                	jbe    1091ca0 <deflate64.stream_blocks.fixedPlan+0x1d0>
 1091c71:	bf 1d 01 00 00       	mov    $0x11d,%edi
 1091c76:	b1 10                	mov    $0x10,%cl
 1091c78:	eb 6a                	jmp    1091ce4 <deflate64.stream_blocks.fixedPlan+0x214>
 1091c7a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1091c80:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 1091c84:	42 0f b6 0c 21       	movzbl (%rcx,%r12,1),%ecx
 1091c89:	0f b6 89 8a 1a 01 01 	movzbl 0x1011a8a(%rcx),%ecx
 1091c90:	80 e1 0f             	and    $0xf,%cl
 1091c93:	e9 ba 00 00 00       	jmp    1091d52 <deflate64.stream_blocks.fixedPlan+0x282>
 1091c98:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1091c9f:	00 
 1091ca0:	48 83 fa 0a          	cmp    $0xa,%rdx
 1091ca4:	77 0b                	ja     1091cb1 <deflate64.stream_blocks.fixedPlan+0x1e1>
 1091ca6:	48 8d ba fe 00 00 00 	lea    0xfe(%rdx),%rdi
 1091cad:	31 c9                	xor    %ecx,%ecx
 1091caf:	eb 33                	jmp    1091ce4 <deflate64.stream_blocks.fixedPlan+0x214>
 1091cb1:	48 8d 72 fd          	lea    -0x3(%rdx),%rsi
 1091cb5:	f3 48 0f bd ce       	lzcnt  %rsi,%rcx
 1091cba:	f6 d1                	not    %cl
 1091cbc:	48 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%rdi
 1091cc3:	c4 e2 f1 f7 ff       	shlx   %rcx,%rdi,%rdi
 1091cc8:	80 c1 3e             	add    $0x3e,%cl
 1091ccb:	48 01 f7             	add    %rsi,%rdi
 1091cce:	0f b6 f1             	movzbl %cl,%esi
 1091cd1:	c4 e2 cb f7 ff       	shrx   %rsi,%rdi,%rdi
 1091cd6:	83 e6 3f             	and    $0x3f,%esi
 1091cd9:	48 8d 3c b7          	lea    (%rdi,%rsi,4),%rdi
 1091cdd:	48 81 c7 05 01 00 00 	add    $0x105,%rdi
 1091ce4:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1091ce8:	80 e1 1f             	and    $0x1f,%cl
 1091ceb:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 1091cee:	48 83 fe 05          	cmp    $0x5,%rsi
 1091cf2:	73 0c                	jae    1091d00 <deflate64.stream_blocks.fixedPlan+0x230>
 1091cf4:	45 31 c0             	xor    %r8d,%r8d
 1091cf7:	eb 18                	jmp    1091d11 <deflate64.stream_blocks.fixedPlan+0x241>
 1091cf9:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1091d00:	4c 8d 46 ff          	lea    -0x1(%rsi),%r8
 1091d04:	f3 4d 0f bd c0       	lzcnt  %r8,%r8
 1091d09:	41 80 f0 3f          	xor    $0x3f,%r8b
 1091d0d:	41 80 c0 3f          	add    $0x3f,%r8b
 1091d11:	41 80 e0 1f          	and    $0x1f,%r8b
 1091d15:	44 88 45 d4          	mov    %r8b,-0x2c(%rbp)
 1091d19:	0f b7 ff             	movzwl %di,%edi
 1091d1c:	0f b6 bf 8a 1a 01 01 	movzbl 0x1011a8a(%rdi),%edi
 1091d23:	40 80 e7 0f          	and    $0xf,%dil
 1091d27:	44 00 c1             	add    %r8b,%cl
 1091d2a:	40 00 f9             	add    %dil,%cl
 1091d2d:	80 c1 05             	add    $0x5,%cl
 1091d30:	48 ff 45 b8          	incq   -0x48(%rbp)
 1091d34:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 1091d38:	48 39 d7             	cmp    %rdx,%rdi
 1091d3b:	48 0f 46 fa          	cmovbe %rdx,%rdi
 1091d3f:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 1091d43:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 1091d47:	48 39 f2             	cmp    %rsi,%rdx
 1091d4a:	48 0f 46 d6          	cmovbe %rsi,%rdx
 1091d4e:	48 89 55 c0          	mov    %rdx,-0x40(%rbp)
 1091d52:	31 d2                	xor    %edx,%edx
 1091d54:	eb 67                	jmp    1091dbd <deflate64.stream_blocks.fixedPlan+0x2ed>
 1091d56:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1091d5d:	00 00 00 
 1091d60:	4c 8d 56 02          	lea    0x2(%rsi),%r10
 1091d64:	4d 29 c2             	sub    %r8,%r10
 1091d67:	4d 03 55 30          	add    0x30(%r13),%r10
 1091d6b:	0f b6 3f             	movzbl (%rdi),%edi
 1091d6e:	45 0f b6 01          	movzbl (%r9),%r8d
 1091d72:	c1 e7 10             	shl    $0x10,%edi
 1091d75:	41 c1 e0 08          	shl    $0x8,%r8d
 1091d79:	41 09 f8             	or     %edi,%r8d
 1091d7c:	41 0f b6 3a          	movzbl (%r10),%edi
 1091d80:	44 09 c7             	or     %r8d,%edi
 1091d83:	69 ff bd a7 35 1e    	imul   $0x1e35a7bd,%edi,%edi
 1091d89:	4d 8b 45 18          	mov    0x18(%r13),%r8
 1091d8d:	49 01 d8             	add    %rbx,%r8
 1091d90:	49 21 f0             	and    %rsi,%r8
 1091d93:	49 8b 75 00          	mov    0x0(%r13),%rsi
 1091d97:	4d 8b 4d 10          	mov    0x10(%r13),%r9
 1091d9b:	c1 ef 11             	shr    $0x11,%edi
 1091d9e:	8b 34 be             	mov    (%rsi,%rdi,4),%esi
 1091da1:	43 89 34 81          	mov    %esi,(%r9,%r8,4)
 1091da5:	49 8b 75 00          	mov    0x0(%r13),%rsi
 1091da9:	45 8d 04 17          	lea    (%r15,%rdx,1),%r8d
 1091dad:	44 89 04 be          	mov    %r8d,(%rsi,%rdi,4)
 1091db1:	48 ff c2             	inc    %rdx
 1091db4:	48 39 d0             	cmp    %rdx,%rax
 1091db7:	0f 84 63 fe ff ff    	je     1091c20 <deflate64.stream_blocks.fixedPlan+0x150>
 1091dbd:	4a 8d 34 3a          	lea    (%rdx,%r15,1),%rsi
 1091dc1:	48 83 c6 03          	add    $0x3,%rsi
 1091dc5:	4d 8b 45 28          	mov    0x28(%r13),%r8
 1091dc9:	49 8b 7d 38          	mov    0x38(%r13),%rdi
 1091dcd:	4c 01 c7             	add    %r8,%rdi
 1091dd0:	48 39 fe             	cmp    %rdi,%rsi
 1091dd3:	77 dc                	ja     1091db1 <deflate64.stream_blocks.fixedPlan+0x2e1>
 1091dd5:	4a 8d 34 3a          	lea    (%rdx,%r15,1),%rsi
 1091dd9:	48 89 f7             	mov    %rsi,%rdi
 1091ddc:	4c 29 c7             	sub    %r8,%rdi
 1091ddf:	73 3f                	jae    1091e20 <deflate64.stream_blocks.fixedPlan+0x350>
 1091de1:	49 8b 7d 20          	mov    0x20(%r13),%rdi
 1091de5:	4c 01 ff             	add    %r15,%rdi
 1091de8:	48 01 d7             	add    %rdx,%rdi
 1091deb:	4d 8d 0c 17          	lea    (%r15,%rdx,1),%r9
 1091def:	49 ff c1             	inc    %r9
 1091df2:	4d 39 c1             	cmp    %r8,%r9
 1091df5:	72 39                	jb     1091e30 <deflate64.stream_blocks.fixedPlan+0x360>
 1091df7:	4c 8d 4e 01          	lea    0x1(%rsi),%r9
 1091dfb:	4d 29 c1             	sub    %r8,%r9
 1091dfe:	4d 03 4d 30          	add    0x30(%r13),%r9
 1091e02:	4d 8d 14 17          	lea    (%r15,%rdx,1),%r10
 1091e06:	49 83 c2 02          	add    $0x2,%r10
 1091e0a:	4d 39 c2             	cmp    %r8,%r10
 1091e0d:	0f 83 4d ff ff ff    	jae    1091d60 <deflate64.stream_blocks.fixedPlan+0x290>
 1091e13:	eb 39                	jmp    1091e4e <deflate64.stream_blocks.fixedPlan+0x37e>
 1091e15:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 1091e1c:	00 00 00 00 
 1091e20:	49 03 7d 30          	add    0x30(%r13),%rdi
 1091e24:	4d 8d 0c 17          	lea    (%r15,%rdx,1),%r9
 1091e28:	49 ff c1             	inc    %r9
 1091e2b:	4d 39 c1             	cmp    %r8,%r9
 1091e2e:	73 c7                	jae    1091df7 <deflate64.stream_blocks.fixedPlan+0x327>
 1091e30:	4d 8b 4d 20          	mov    0x20(%r13),%r9
 1091e34:	4d 01 f9             	add    %r15,%r9
 1091e37:	49 01 d1             	add    %rdx,%r9
 1091e3a:	49 ff c1             	inc    %r9
 1091e3d:	4d 8d 14 17          	lea    (%r15,%rdx,1),%r10
 1091e41:	49 83 c2 02          	add    $0x2,%r10
 1091e45:	4d 39 c2             	cmp    %r8,%r10
 1091e48:	0f 83 12 ff ff ff    	jae    1091d60 <deflate64.stream_blocks.fixedPlan+0x290>
 1091e4e:	4d 8b 45 20          	mov    0x20(%r13),%r8
 1091e52:	4d 01 f8             	add    %r15,%r8
 1091e55:	4e 8d 14 02          	lea    (%rdx,%r8,1),%r10
 1091e59:	49 83 c2 02          	add    $0x2,%r10
 1091e5d:	e9 09 ff ff ff       	jmp    1091d6b <deflate64.stream_blocks.fixedPlan+0x29b>
 1091e62:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1091e66:	4c 89 30             	mov    %r14,(%rax)
 1091e69:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 1091e6d:	48 89 48 08          	mov    %rcx,0x8(%rax)
 1091e71:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1091e75:	48 89 48 10          	mov    %rcx,0x10(%rax)
 1091e79:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 1091e7d:	48 89 48 18          	mov    %rcx,0x18(%rax)
 1091e81:	48 83 c4 58          	add    $0x58,%rsp
 1091e85:	5b                   	pop    %rbx
 1091e86:	41 5c                	pop    %r12
 1091e88:	41 5d                	pop    %r13
 1091e8a:	41 5e                	pop    %r14
 1091e8c:	41 5f                	pop    %r15
 1091e8e:	5d                   	pop    %rbp
 1091e8f:	c3                   	ret    
 1091e90:	48 c7 07 0a 00 00 00 	movq   $0xa,(%rdi)
 1091e97:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1091e9b:	c5 f8 11 47 08       	vmovups %xmm0,0x8(%rdi)
 1091ea0:	48 c7 47 18 00 00 00 	movq   $0x0,0x18(%rdi)
 1091ea7:	00 
 1091ea8:	c3                   	ret    
