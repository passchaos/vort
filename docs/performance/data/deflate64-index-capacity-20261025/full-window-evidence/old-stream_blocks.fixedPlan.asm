
/tmp/vort-deflate64-index-capacity-20261025/old-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001091b40 <deflate64.stream_blocks.fixedPlan>:
 1091b40:	4d 85 c9             	test   %r9,%r9
 1091b43:	0f 84 97 03 00 00    	je     1091ee0 <deflate64.stream_blocks.fixedPlan+0x3a0>
 1091b49:	55                   	push   %rbp
 1091b4a:	48 89 e5             	mov    %rsp,%rbp
 1091b4d:	41 57                	push   %r15
 1091b4f:	41 56                	push   %r14
 1091b51:	41 55                	push   %r13
 1091b53:	41 54                	push   %r12
 1091b55:	53                   	push   %rbx
 1091b56:	48 83 ec 48          	sub    $0x48,%rsp
 1091b5a:	4d 89 cc             	mov    %r9,%r12
 1091b5d:	48 89 cb             	mov    %rcx,%rbx
 1091b60:	49 89 f5             	mov    %rsi,%r13
 1091b63:	48 89 7d b0          	mov    %rdi,-0x50(%rbp)
 1091b67:	48 89 56 20          	mov    %rdx,0x20(%rsi)
 1091b6b:	48 89 4e 28          	mov    %rcx,0x28(%rsi)
 1091b6f:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 1091b73:	4c 89 46 30          	mov    %r8,0x30(%rsi)
 1091b77:	4c 89 4e 38          	mov    %r9,0x38(%rsi)
 1091b7b:	48 8b 3e             	mov    (%rsi),%rdi
 1091b7e:	ba 00 00 02 00       	mov    $0x20000,%edx
 1091b83:	be ff 00 00 00       	mov    $0xff,%esi
 1091b88:	e8 33 25 04 00       	call   10d40c0 <compiler_rt.memset>
 1091b8d:	48 85 db             	test   %rbx,%rbx
 1091b90:	0f 84 bf 00 00 00    	je     1091c55 <deflate64.stream_blocks.fixedPlan+0x115>
 1091b96:	31 c0                	xor    %eax,%eax
 1091b98:	eb 43                	jmp    1091bdd <deflate64.stream_blocks.fixedPlan+0x9d>
 1091b9a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1091ba0:	49 03 7d 30          	add    0x30(%r13),%rdi
 1091ba4:	0f b6 09             	movzbl (%rcx),%ecx
 1091ba7:	0f b6 16             	movzbl (%rsi),%edx
 1091baa:	c1 e1 10             	shl    $0x10,%ecx
 1091bad:	c1 e2 08             	shl    $0x8,%edx
 1091bb0:	09 ca                	or     %ecx,%edx
 1091bb2:	0f b6 0f             	movzbl (%rdi),%ecx
 1091bb5:	09 d1                	or     %edx,%ecx
 1091bb7:	69 c9 bd a7 35 1e    	imul   $0x1e35a7bd,%ecx,%ecx
 1091bbd:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091bc1:	49 8b 75 10          	mov    0x10(%r13),%rsi
 1091bc5:	c1 e9 11             	shr    $0x11,%ecx
 1091bc8:	8b 14 8a             	mov    (%rdx,%rcx,4),%edx
 1091bcb:	89 14 86             	mov    %edx,(%rsi,%rax,4)
 1091bce:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091bd2:	89 04 8a             	mov    %eax,(%rdx,%rcx,4)
 1091bd5:	48 ff c0             	inc    %rax
 1091bd8:	48 39 c3             	cmp    %rax,%rbx
 1091bdb:	74 78                	je     1091c55 <deflate64.stream_blocks.fixedPlan+0x115>
 1091bdd:	48 8d 48 03          	lea    0x3(%rax),%rcx
 1091be1:	49 8b 55 28          	mov    0x28(%r13),%rdx
 1091be5:	49 8b 75 38          	mov    0x38(%r13),%rsi
 1091be9:	48 01 d6             	add    %rdx,%rsi
 1091bec:	48 39 f1             	cmp    %rsi,%rcx
 1091bef:	77 e4                	ja     1091bd5 <deflate64.stream_blocks.fixedPlan+0x95>
 1091bf1:	48 89 c1             	mov    %rax,%rcx
 1091bf4:	48 29 d1             	sub    %rdx,%rcx
 1091bf7:	73 27                	jae    1091c20 <deflate64.stream_blocks.fixedPlan+0xe0>
 1091bf9:	49 8b 4d 20          	mov    0x20(%r13),%rcx
 1091bfd:	48 01 c1             	add    %rax,%rcx
 1091c00:	48 8d 70 01          	lea    0x1(%rax),%rsi
 1091c04:	48 29 d6             	sub    %rdx,%rsi
 1091c07:	72 24                	jb     1091c2d <deflate64.stream_blocks.fixedPlan+0xed>
 1091c09:	49 03 75 30          	add    0x30(%r13),%rsi
 1091c0d:	48 8d 78 02          	lea    0x2(%rax),%rdi
 1091c11:	48 29 d7             	sub    %rdx,%rdi
 1091c14:	73 8a                	jae    1091ba0 <deflate64.stream_blocks.fixedPlan+0x60>
 1091c16:	eb 2c                	jmp    1091c44 <deflate64.stream_blocks.fixedPlan+0x104>
 1091c18:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1091c1f:	00 
 1091c20:	49 03 4d 30          	add    0x30(%r13),%rcx
 1091c24:	48 8d 70 01          	lea    0x1(%rax),%rsi
 1091c28:	48 29 d6             	sub    %rdx,%rsi
 1091c2b:	73 dc                	jae    1091c09 <deflate64.stream_blocks.fixedPlan+0xc9>
 1091c2d:	49 8b 75 20          	mov    0x20(%r13),%rsi
 1091c31:	48 01 c6             	add    %rax,%rsi
 1091c34:	48 ff c6             	inc    %rsi
 1091c37:	48 8d 78 02          	lea    0x2(%rax),%rdi
 1091c3b:	48 29 d7             	sub    %rdx,%rdi
 1091c3e:	0f 83 5c ff ff ff    	jae    1091ba0 <deflate64.stream_blocks.fixedPlan+0x60>
 1091c44:	49 8b 55 20          	mov    0x20(%r13),%rdx
 1091c48:	48 8d 3c 02          	lea    (%rdx,%rax,1),%rdi
 1091c4c:	48 83 c7 02          	add    $0x2,%rdi
 1091c50:	e9 4f ff ff ff       	jmp    1091ba4 <deflate64.stream_blocks.fixedPlan+0x64>
 1091c55:	48 89 5d a0          	mov    %rbx,-0x60(%rbp)
 1091c59:	bb 0a 00 00 00       	mov    $0xa,%ebx
 1091c5e:	45 31 f6             	xor    %r14d,%r14d
 1091c61:	48 c7 45 c0 00 00 00 	movq   $0x0,-0x40(%rbp)
 1091c68:	00 
 1091c69:	48 c7 45 c8 00 00 00 	movq   $0x0,-0x38(%rbp)
 1091c70:	00 
 1091c71:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 1091c78:	00 
 1091c79:	eb 17                	jmp    1091c92 <deflate64.stream_blocks.fixedPlan+0x152>
 1091c7b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1091c80:	0f b6 c9             	movzbl %cl,%ecx
 1091c83:	48 01 cb             	add    %rcx,%rbx
 1091c86:	49 01 c6             	add    %rax,%r14
 1091c89:	4d 39 e6             	cmp    %r12,%r14
 1091c8c:	0f 83 20 02 00 00    	jae    1091eb2 <deflate64.stream_blocks.fixedPlan+0x372>
 1091c92:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 1091c96:	4d 8d 3c 06          	lea    (%r14,%rax,1),%r15
 1091c9a:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1091c9e:	4c 89 ee             	mov    %r13,%rsi
 1091ca1:	4c 89 fa             	mov    %r15,%rdx
 1091ca4:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 1091ca8:	4c 8b 45 18          	mov    0x18(%rbp),%r8
 1091cac:	e8 bf fc ff ff       	call   1091970 <deflate64.stream_match.Matcher.find>
 1091cb1:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 1091cb5:	48 83 fa 03          	cmp    $0x3,%rdx
 1091cb9:	b8 01 00 00 00       	mov    $0x1,%eax
 1091cbe:	48 0f 43 c2          	cmovae %rdx,%rax
 1091cc2:	72 1c                	jb     1091ce0 <deflate64.stream_blocks.fixedPlan+0x1a0>
 1091cc4:	48 81 fa 02 01 00 00 	cmp    $0x102,%rdx
 1091ccb:	76 33                	jbe    1091d00 <deflate64.stream_blocks.fixedPlan+0x1c0>
 1091ccd:	bf 1d 01 00 00       	mov    $0x11d,%edi
 1091cd2:	b1 10                	mov    $0x10,%cl
 1091cd4:	eb 6e                	jmp    1091d44 <deflate64.stream_blocks.fixedPlan+0x204>
 1091cd6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1091cdd:	00 00 00 
 1091ce0:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 1091ce4:	42 0f b6 0c 31       	movzbl (%rcx,%r14,1),%ecx
 1091ce9:	0f b6 89 8a 1a 01 01 	movzbl 0x1011a8a(%rcx),%ecx
 1091cf0:	80 e1 0f             	and    $0xf,%cl
 1091cf3:	e9 ba 00 00 00       	jmp    1091db2 <deflate64.stream_blocks.fixedPlan+0x272>
 1091cf8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1091cff:	00 
 1091d00:	48 83 fa 0a          	cmp    $0xa,%rdx
 1091d04:	77 0b                	ja     1091d11 <deflate64.stream_blocks.fixedPlan+0x1d1>
 1091d06:	48 8d ba fe 00 00 00 	lea    0xfe(%rdx),%rdi
 1091d0d:	31 c9                	xor    %ecx,%ecx
 1091d0f:	eb 33                	jmp    1091d44 <deflate64.stream_blocks.fixedPlan+0x204>
 1091d11:	48 8d 72 fd          	lea    -0x3(%rdx),%rsi
 1091d15:	f3 48 0f bd ce       	lzcnt  %rsi,%rcx
 1091d1a:	f6 d1                	not    %cl
 1091d1c:	48 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%rdi
 1091d23:	c4 e2 f1 f7 ff       	shlx   %rcx,%rdi,%rdi
 1091d28:	80 c1 3e             	add    $0x3e,%cl
 1091d2b:	48 01 f7             	add    %rsi,%rdi
 1091d2e:	0f b6 f1             	movzbl %cl,%esi
 1091d31:	c4 e2 cb f7 ff       	shrx   %rsi,%rdi,%rdi
 1091d36:	83 e6 3f             	and    $0x3f,%esi
 1091d39:	48 8d 3c b7          	lea    (%rdi,%rsi,4),%rdi
 1091d3d:	48 81 c7 05 01 00 00 	add    $0x105,%rdi
 1091d44:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 1091d48:	80 e1 1f             	and    $0x1f,%cl
 1091d4b:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 1091d4e:	48 83 fe 05          	cmp    $0x5,%rsi
 1091d52:	73 0c                	jae    1091d60 <deflate64.stream_blocks.fixedPlan+0x220>
 1091d54:	45 31 c0             	xor    %r8d,%r8d
 1091d57:	eb 18                	jmp    1091d71 <deflate64.stream_blocks.fixedPlan+0x231>
 1091d59:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1091d60:	4c 8d 46 ff          	lea    -0x1(%rsi),%r8
 1091d64:	f3 4d 0f bd c0       	lzcnt  %r8,%r8
 1091d69:	41 80 f0 3f          	xor    $0x3f,%r8b
 1091d6d:	41 80 c0 3f          	add    $0x3f,%r8b
 1091d71:	41 80 e0 1f          	and    $0x1f,%r8b
 1091d75:	44 88 45 d4          	mov    %r8b,-0x2c(%rbp)
 1091d79:	0f b7 ff             	movzwl %di,%edi
 1091d7c:	0f b6 bf 8a 1a 01 01 	movzbl 0x1011a8a(%rdi),%edi
 1091d83:	40 80 e7 0f          	and    $0xf,%dil
 1091d87:	44 00 c1             	add    %r8b,%cl
 1091d8a:	40 00 f9             	add    %dil,%cl
 1091d8d:	80 c1 05             	add    $0x5,%cl
 1091d90:	48 ff 45 b8          	incq   -0x48(%rbp)
 1091d94:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 1091d98:	48 39 d7             	cmp    %rdx,%rdi
 1091d9b:	48 0f 46 fa          	cmovbe %rdx,%rdi
 1091d9f:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 1091da3:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 1091da7:	48 39 f2             	cmp    %rsi,%rdx
 1091daa:	48 0f 46 d6          	cmovbe %rsi,%rdx
 1091dae:	48 89 55 c0          	mov    %rdx,-0x40(%rbp)
 1091db2:	31 d2                	xor    %edx,%edx
 1091db4:	eb 61                	jmp    1091e17 <deflate64.stream_blocks.fixedPlan+0x2d7>
 1091db6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1091dbd:	00 00 00 
 1091dc0:	4c 8d 56 02          	lea    0x2(%rsi),%r10
 1091dc4:	4d 29 c2             	sub    %r8,%r10
 1091dc7:	4d 03 55 30          	add    0x30(%r13),%r10
 1091dcb:	0f b6 3f             	movzbl (%rdi),%edi
 1091dce:	45 0f b6 01          	movzbl (%r9),%r8d
 1091dd2:	c1 e7 10             	shl    $0x10,%edi
 1091dd5:	41 c1 e0 08          	shl    $0x8,%r8d
 1091dd9:	41 09 f8             	or     %edi,%r8d
 1091ddc:	41 0f b6 3a          	movzbl (%r10),%edi
 1091de0:	44 09 c7             	or     %r8d,%edi
 1091de3:	69 ff bd a7 35 1e    	imul   $0x1e35a7bd,%edi,%edi
 1091de9:	0f b7 f6             	movzwl %si,%esi
 1091dec:	4d 8b 45 00          	mov    0x0(%r13),%r8
 1091df0:	4d 8b 4d 10          	mov    0x10(%r13),%r9
 1091df4:	c1 ef 11             	shr    $0x11,%edi
 1091df7:	45 8b 04 b8          	mov    (%r8,%rdi,4),%r8d
 1091dfb:	45 89 04 b1          	mov    %r8d,(%r9,%rsi,4)
 1091dff:	49 8b 75 00          	mov    0x0(%r13),%rsi
 1091e03:	45 8d 04 17          	lea    (%r15,%rdx,1),%r8d
 1091e07:	44 89 04 be          	mov    %r8d,(%rsi,%rdi,4)
 1091e0b:	48 ff c2             	inc    %rdx
 1091e0e:	48 39 d0             	cmp    %rdx,%rax
 1091e11:	0f 84 69 fe ff ff    	je     1091c80 <deflate64.stream_blocks.fixedPlan+0x140>
 1091e17:	4a 8d 34 3a          	lea    (%rdx,%r15,1),%rsi
 1091e1b:	48 83 c6 03          	add    $0x3,%rsi
 1091e1f:	4d 8b 45 28          	mov    0x28(%r13),%r8
 1091e23:	49 8b 7d 38          	mov    0x38(%r13),%rdi
 1091e27:	4c 01 c7             	add    %r8,%rdi
 1091e2a:	48 39 fe             	cmp    %rdi,%rsi
 1091e2d:	77 dc                	ja     1091e0b <deflate64.stream_blocks.fixedPlan+0x2cb>
 1091e2f:	4a 8d 34 3a          	lea    (%rdx,%r15,1),%rsi
 1091e33:	48 89 f7             	mov    %rsi,%rdi
 1091e36:	4c 29 c7             	sub    %r8,%rdi
 1091e39:	73 35                	jae    1091e70 <deflate64.stream_blocks.fixedPlan+0x330>
 1091e3b:	49 8b 7d 20          	mov    0x20(%r13),%rdi
 1091e3f:	4c 01 ff             	add    %r15,%rdi
 1091e42:	48 01 d7             	add    %rdx,%rdi
 1091e45:	4d 8d 0c 17          	lea    (%r15,%rdx,1),%r9
 1091e49:	49 ff c1             	inc    %r9
 1091e4c:	4d 39 c1             	cmp    %r8,%r9
 1091e4f:	72 2f                	jb     1091e80 <deflate64.stream_blocks.fixedPlan+0x340>
 1091e51:	4c 8d 4e 01          	lea    0x1(%rsi),%r9
 1091e55:	4d 29 c1             	sub    %r8,%r9
 1091e58:	4d 03 4d 30          	add    0x30(%r13),%r9
 1091e5c:	4d 8d 14 17          	lea    (%r15,%rdx,1),%r10
 1091e60:	49 83 c2 02          	add    $0x2,%r10
 1091e64:	4d 39 c2             	cmp    %r8,%r10
 1091e67:	0f 83 53 ff ff ff    	jae    1091dc0 <deflate64.stream_blocks.fixedPlan+0x280>
 1091e6d:	eb 2f                	jmp    1091e9e <deflate64.stream_blocks.fixedPlan+0x35e>
 1091e6f:	90                   	nop
 1091e70:	49 03 7d 30          	add    0x30(%r13),%rdi
 1091e74:	4d 8d 0c 17          	lea    (%r15,%rdx,1),%r9
 1091e78:	49 ff c1             	inc    %r9
 1091e7b:	4d 39 c1             	cmp    %r8,%r9
 1091e7e:	73 d1                	jae    1091e51 <deflate64.stream_blocks.fixedPlan+0x311>
 1091e80:	4d 8b 4d 20          	mov    0x20(%r13),%r9
 1091e84:	4d 01 f9             	add    %r15,%r9
 1091e87:	49 01 d1             	add    %rdx,%r9
 1091e8a:	49 ff c1             	inc    %r9
 1091e8d:	4d 8d 14 17          	lea    (%r15,%rdx,1),%r10
 1091e91:	49 83 c2 02          	add    $0x2,%r10
 1091e95:	4d 39 c2             	cmp    %r8,%r10
 1091e98:	0f 83 22 ff ff ff    	jae    1091dc0 <deflate64.stream_blocks.fixedPlan+0x280>
 1091e9e:	4d 8b 45 20          	mov    0x20(%r13),%r8
 1091ea2:	4d 01 f8             	add    %r15,%r8
 1091ea5:	4e 8d 14 02          	lea    (%rdx,%r8,1),%r10
 1091ea9:	49 83 c2 02          	add    $0x2,%r10
 1091ead:	e9 19 ff ff ff       	jmp    1091dcb <deflate64.stream_blocks.fixedPlan+0x28b>
 1091eb2:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1091eb6:	48 89 18             	mov    %rbx,(%rax)
 1091eb9:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 1091ebd:	48 89 48 08          	mov    %rcx,0x8(%rax)
 1091ec1:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1091ec5:	48 89 48 10          	mov    %rcx,0x10(%rax)
 1091ec9:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 1091ecd:	48 89 48 18          	mov    %rcx,0x18(%rax)
 1091ed1:	48 83 c4 48          	add    $0x48,%rsp
 1091ed5:	5b                   	pop    %rbx
 1091ed6:	41 5c                	pop    %r12
 1091ed8:	41 5d                	pop    %r13
 1091eda:	41 5e                	pop    %r14
 1091edc:	41 5f                	pop    %r15
 1091ede:	5d                   	pop    %rbp
 1091edf:	c3                   	ret    
 1091ee0:	48 c7 07 0a 00 00 00 	movq   $0xa,(%rdi)
 1091ee7:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1091eeb:	c5 f8 11 47 08       	vmovups %xmm0,0x8(%rdi)
 1091ef0:	48 c7 47 18 00 00 00 	movq   $0x0,0x18(%rdi)
 1091ef7:	00 
 1091ef8:	c3                   	ret    
