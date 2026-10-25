
/tmp/vort-deflate64-index-capacity-20261025/new-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001091eb0 <deflate64.stream_match.Matcher.ensureForSize>:
 1091eb0:	55                   	push   %rbp
 1091eb1:	48 89 e5             	mov    %rsp,%rbp
 1091eb4:	41 57                	push   %r15
 1091eb6:	41 56                	push   %r14
 1091eb8:	41 55                	push   %r13
 1091eba:	41 54                	push   %r12
 1091ebc:	53                   	push   %rbx
 1091ebd:	48 83 ec 38          	sub    $0x38,%rsp
 1091ec1:	4c 8b 1e             	mov    (%rsi),%r11
 1091ec4:	4c 8b 56 08          	mov    0x8(%rsi),%r10
 1091ec8:	48 81 fa 00 00 01 00 	cmp    $0x10000,%rdx
 1091ecf:	b8 00 00 01 00       	mov    $0x10000,%eax
 1091ed4:	48 0f 42 c2          	cmovb  %rdx,%rax
 1091ed8:	83 f8 02             	cmp    $0x2,%eax
 1091edb:	b9 01 00 00 00       	mov    $0x1,%ecx
 1091ee0:	0f 43 c8             	cmovae %eax,%ecx
 1091ee3:	48 ff c9             	dec    %rcx
 1091ee6:	f3 48 0f bd c1       	lzcnt  %rcx,%rax
 1091eeb:	b1 40                	mov    $0x40,%cl
 1091eed:	28 c1                	sub    %al,%cl
 1091eef:	b8 01 00 00 00       	mov    $0x1,%eax
 1091ef4:	c4 62 f1 f7 e0       	shlx   %rcx,%rax,%r12
 1091ef9:	45 31 f6             	xor    %r14d,%r14d
 1091efc:	f6 c1 40             	test   $0x40,%cl
 1091eff:	4d 0f 45 e6          	cmovne %r14,%r12
 1091f03:	4c 8b 6f 08          	mov    0x8(%rdi),%r13
 1091f07:	41 bf 04 00 00 00    	mov    $0x4,%r15d
 1091f0d:	4d 85 ed             	test   %r13,%r13
 1091f10:	74 56                	je     1091f68 <deflate64.stream_match.Matcher.ensureForSize+0xb8>
 1091f12:	48 8b 5f 18          	mov    0x18(%rdi),%rbx
 1091f16:	4c 39 e3             	cmp    %r12,%rbx
 1091f19:	0f 83 9c 00 00 00    	jae    1091fbb <deflate64.stream_match.Matcher.ensureForSize+0x10b>
 1091f1f:	48 85 db             	test   %rbx,%rbx
 1091f22:	4c 89 55 a8          	mov    %r10,-0x58(%rbp)
 1091f26:	4c 89 5d b0          	mov    %r11,-0x50(%rbp)
 1091f2a:	0f 84 31 01 00 00    	je     1092061 <deflate64.stream_match.Matcher.ensureForSize+0x1b1>
 1091f30:	48 8b 77 10          	mov    0x10(%rdi),%rsi
 1091f34:	c6 45 c0 00          	movb   $0x0,-0x40(%rbp)
 1091f38:	31 c0                	xor    %eax,%eax
 1091f3a:	84 c0                	test   %al,%al
 1091f3c:	0f 84 d7 00 00 00    	je     1092019 <deflate64.stream_match.Matcher.ensureForSize+0x169>
 1091f42:	31 c0                	xor    %eax,%eax
 1091f44:	45 31 c0             	xor    %r8d,%r8d
 1091f47:	48 85 c0             	test   %rax,%rax
 1091f4a:	0f 84 11 01 00 00    	je     1092061 <deflate64.stream_match.Matcher.ensureForSize+0x1b1>
 1091f50:	31 c9                	xor    %ecx,%ecx
 1091f52:	4d 85 ed             	test   %r13,%r13
 1091f55:	75 72                	jne    1091fc9 <deflate64.stream_match.Matcher.ensureForSize+0x119>
 1091f57:	4c 89 3f             	mov    %r15,(%rdi)
 1091f5a:	4c 89 77 08          	mov    %r14,0x8(%rdi)
 1091f5e:	4c 39 e3             	cmp    %r12,%rbx
 1091f61:	72 6b                	jb     1091fce <deflate64.stream_match.Matcher.ensureForSize+0x11e>
 1091f63:	e9 9f 00 00 00       	jmp    1092007 <deflate64.stream_match.Matcher.ensureForSize+0x157>
 1091f68:	c6 45 d0 00          	movb   $0x0,-0x30(%rbp)
 1091f6c:	31 c0                	xor    %eax,%eax
 1091f6e:	84 c0                	test   %al,%al
 1091f70:	0f 85 99 00 00 00    	jne    109200f <deflate64.stream_match.Matcher.ensureForSize+0x15f>
 1091f76:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 1091f7a:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 1091f7e:	be 00 00 02 00       	mov    $0x20000,%esi
 1091f83:	4c 89 5d b0          	mov    %r11,-0x50(%rbp)
 1091f87:	4c 89 df             	mov    %r11,%rdi
 1091f8a:	ba 02 00 00 00       	mov    $0x2,%edx
 1091f8f:	4c 89 d3             	mov    %r10,%rbx
 1091f92:	41 ff 12             	call   *(%r10)
 1091f95:	48 85 c0             	test   %rax,%rax
 1091f98:	74 75                	je     109200f <deflate64.stream_match.Matcher.ensureForSize+0x15f>
 1091f9a:	49 89 c7             	mov    %rax,%r15
 1091f9d:	41 be 00 80 00 00    	mov    $0x8000,%r14d
 1091fa3:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 1091fa7:	49 89 da             	mov    %rbx,%r10
 1091faa:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 1091fae:	48 8b 5f 18          	mov    0x18(%rdi),%rbx
 1091fb2:	4c 39 e3             	cmp    %r12,%rbx
 1091fb5:	0f 82 64 ff ff ff    	jb     1091f1f <deflate64.stream_match.Matcher.ensureForSize+0x6f>
 1091fbb:	48 8b 47 10          	mov    0x10(%rdi),%rax
 1091fbf:	b1 01                	mov    $0x1,%cl
 1091fc1:	49 89 d8             	mov    %rbx,%r8
 1091fc4:	4d 85 ed             	test   %r13,%r13
 1091fc7:	74 8e                	je     1091f57 <deflate64.stream_match.Matcher.ensureForSize+0xa7>
 1091fc9:	4c 39 e3             	cmp    %r12,%rbx
 1091fcc:	73 39                	jae    1092007 <deflate64.stream_match.Matcher.ensureForSize+0x157>
 1091fce:	48 8b 77 10          	mov    0x10(%rdi),%rsi
 1091fd2:	48 8b 57 18          	mov    0x18(%rdi),%rdx
 1091fd6:	48 89 47 10          	mov    %rax,0x10(%rdi)
 1091fda:	4c 89 47 18          	mov    %r8,0x18(%rdi)
 1091fde:	48 85 d2             	test   %rdx,%rdx
 1091fe1:	0f 94 c0             	sete   %al
 1091fe4:	80 f1 01             	xor    $0x1,%cl
 1091fe7:	08 c1                	or     %al,%cl
 1091fe9:	75 1c                	jne    1092007 <deflate64.stream_match.Matcher.ensureForSize+0x157>
 1091feb:	48 c1 e2 02          	shl    $0x2,%rdx
 1091fef:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1091ff3:	4c 89 df             	mov    %r11,%rdi
 1091ff6:	b9 02 00 00 00       	mov    $0x2,%ecx
 1091ffb:	41 ff 52 18          	call   *0x18(%r10)
 1091fff:	45 31 e4             	xor    %r12d,%r12d
 1092002:	e9 cf 00 00 00       	jmp    10920d6 <deflate64.stream_match.Matcher.ensureForSize+0x226>
 1092007:	45 31 e4             	xor    %r12d,%r12d
 109200a:	e9 c7 00 00 00       	jmp    10920d6 <deflate64.stream_match.Matcher.ensureForSize+0x226>
 109200f:	66 41 bc 1a 00       	mov    $0x1a,%r12w
 1092014:	e9 bd 00 00 00       	jmp    10920d6 <deflate64.stream_match.Matcher.ensureForSize+0x226>
 1092019:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 109201d:	4e 8d 04 a5 00 00 00 	lea    0x0(,%r12,4),%r8
 1092024:	00 
 1092025:	48 8d 14 9d 00 00 00 	lea    0x0(,%rbx,4),%rdx
 109202c:	00 
 109202d:	4c 8b 4d 08          	mov    0x8(%rbp),%r9
 1092031:	4c 89 df             	mov    %r11,%rdi
 1092034:	b9 02 00 00 00       	mov    $0x2,%ecx
 1092039:	41 ff 52 10          	call   *0x10(%r10)
 109203d:	48 85 c0             	test   %rax,%rax
 1092040:	74 05                	je     1092047 <deflate64.stream_match.Matcher.ensureForSize+0x197>
 1092042:	4d 89 e0             	mov    %r12,%r8
 1092045:	eb 05                	jmp    109204c <deflate64.stream_match.Matcher.ensureForSize+0x19c>
 1092047:	31 c0                	xor    %eax,%eax
 1092049:	45 31 c0             	xor    %r8d,%r8d
 109204c:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 1092050:	4c 8b 55 a8          	mov    -0x58(%rbp),%r10
 1092054:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 1092058:	48 85 c0             	test   %rax,%rax
 109205b:	0f 85 ef fe ff ff    	jne    1091f50 <deflate64.stream_match.Matcher.ensureForSize+0xa0>
 1092061:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 1092065:	c6 45 c8 00          	movb   $0x0,-0x38(%rbp)
 1092069:	31 c0                	xor    %eax,%eax
 109206b:	84 c0                	test   %al,%al
 109206d:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 1092071:	75 3b                	jne    10920ae <deflate64.stream_match.Matcher.ensureForSize+0x1fe>
 1092073:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 1092077:	4a 8d 34 a5 00 00 00 	lea    0x0(,%r12,4),%rsi
 109207e:	00 
 109207f:	4c 89 df             	mov    %r11,%rdi
 1092082:	ba 02 00 00 00       	mov    $0x2,%edx
 1092087:	41 ff 12             	call   *(%r10)
 109208a:	48 85 c0             	test   %rax,%rax
 109208d:	74 1f                	je     10920ae <deflate64.stream_match.Matcher.ensureForSize+0x1fe>
 109208f:	b1 01                	mov    $0x1,%cl
 1092091:	4d 89 e0             	mov    %r12,%r8
 1092094:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 1092098:	4c 8b 55 a8          	mov    -0x58(%rbp),%r10
 109209c:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 10920a0:	4d 85 ed             	test   %r13,%r13
 10920a3:	0f 85 20 ff ff ff    	jne    1091fc9 <deflate64.stream_match.Matcher.ensureForSize+0x119>
 10920a9:	e9 a9 fe ff ff       	jmp    1091f57 <deflate64.stream_match.Matcher.ensureForSize+0xa7>
 10920ae:	66 41 bc 1a 00       	mov    $0x1a,%r12w
 10920b3:	4d 85 ed             	test   %r13,%r13
 10920b6:	75 1e                	jne    10920d6 <deflate64.stream_match.Matcher.ensureForSize+0x226>
 10920b8:	41 c1 e6 02          	shl    $0x2,%r14d
 10920bc:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 10920c0:	4c 89 fe             	mov    %r15,%rsi
 10920c3:	4c 89 f2             	mov    %r14,%rdx
 10920c6:	b9 02 00 00 00       	mov    $0x2,%ecx
 10920cb:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 10920cf:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 10920d3:	ff 50 18             	call   *0x18(%rax)
 10920d6:	44 89 e0             	mov    %r12d,%eax
 10920d9:	48 83 c4 38          	add    $0x38,%rsp
 10920dd:	5b                   	pop    %rbx
 10920de:	41 5c                	pop    %r12
 10920e0:	41 5d                	pop    %r13
 10920e2:	41 5e                	pop    %r14
 10920e4:	41 5f                	pop    %r15
 10920e6:	5d                   	pop    %rbp
 10920e7:	c3                   	ret    
