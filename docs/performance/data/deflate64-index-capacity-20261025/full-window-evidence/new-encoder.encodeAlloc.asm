
/tmp/vort-deflate64-index-capacity-20261025/new-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

000000000105fab0 <deflate64.encoder.encodeAlloc>:
 105fab0:	55                   	push   %rbp
 105fab1:	48 89 e5             	mov    %rsp,%rbp
 105fab4:	41 57                	push   %r15
 105fab6:	41 56                	push   %r14
 105fab8:	41 55                	push   %r13
 105faba:	41 54                	push   %r12
 105fabc:	53                   	push   %rbx
 105fabd:	48 81 ec 08 01 00 00 	sub    $0x108,%rsp
 105fac4:	49 89 d0             	mov    %rdx,%r8
 105fac7:	4c 8b 0e             	mov    (%rsi),%r9
 105faca:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 105face:	48 8b 76 08          	mov    0x8(%rsi),%rsi
 105fad2:	48 85 c9             	test   %rcx,%rcx
 105fad5:	74 27                	je     105fafe <deflate64.encoder.encodeAlloc+0x4e>
 105fad7:	48 8d 51 ff          	lea    -0x1(%rcx),%rdx
 105fadb:	48 b8 01 80 00 80 00 	movabs $0x8000800080008001,%rax
 105fae2:	80 00 80 
 105fae5:	c4 e2 fb f6 c0       	mulx   %rax,%rax,%rax
 105faea:	48 c1 e8 0f          	shr    $0xf,%rax
 105faee:	48 8d 14 80          	lea    (%rax,%rax,4),%rdx
 105faf2:	48 83 c2 05          	add    $0x5,%rdx
 105faf6:	31 c0                	xor    %eax,%eax
 105faf8:	84 c0                	test   %al,%al
 105fafa:	74 0d                	je     105fb09 <deflate64.encoder.encodeAlloc+0x59>
 105fafc:	eb 1c                	jmp    105fb1a <deflate64.encoder.encodeAlloc+0x6a>
 105fafe:	ba 05 00 00 00       	mov    $0x5,%edx
 105fb03:	31 c0                	xor    %eax,%eax
 105fb05:	84 c0                	test   %al,%al
 105fb07:	75 11                	jne    105fb1a <deflate64.encoder.encodeAlloc+0x6a>
 105fb09:	48 01 ca             	add    %rcx,%rdx
 105fb0c:	0f 92 c0             	setb   %al
 105fb0f:	0f 92 85 78 ff ff ff 	setb   -0x88(%rbp)
 105fb16:	84 c0                	test   %al,%al
 105fb18:	74 1b                	je     105fb35 <deflate64.encoder.encodeAlloc+0x85>
 105fb1a:	66 c7 47 10 43 00    	movw   $0x43,0x10(%rdi)
 105fb20:	48 81 c4 08 01 00 00 	add    $0x108,%rsp
 105fb27:	5b                   	pop    %rbx
 105fb28:	41 5c                	pop    %r12
 105fb2a:	41 5d                	pop    %r13
 105fb2c:	41 5e                	pop    %r14
 105fb2e:	41 5f                	pop    %r15
 105fb30:	5d                   	pop    %rbp
 105fb31:	c5 f8 77             	vzeroupper 
 105fb34:	c3                   	ret    
 105fb35:	48 89 95 18 ff ff ff 	mov    %rdx,-0xe8(%rbp)
 105fb3c:	4c 89 8d 20 ff ff ff 	mov    %r9,-0xe0(%rbp)
 105fb43:	48 89 b5 28 ff ff ff 	mov    %rsi,-0xd8(%rbp)
 105fb4a:	4c 89 45 a0          	mov    %r8,-0x60(%rbp)
 105fb4e:	48 89 7d a8          	mov    %rdi,-0x58(%rbp)
 105fb52:	c5 fc 10 05 46 ef fa 	vmovups -0x510ba(%rip),%ymm0        # 100eaa0 <__anon_3137>
 105fb59:	ff 
 105fb5a:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 105fb61:	ff 
 105fb62:	c5 fc 10 05 56 ef fa 	vmovups -0x510aa(%rip),%ymm0        # 100eac0 <__anon_3137+0x20>
 105fb69:	ff 
 105fb6a:	c5 fc 11 85 50 ff ff 	vmovups %ymm0,-0xb0(%rbp)
 105fb71:	ff 
 105fb72:	31 c0                	xor    %eax,%eax
 105fb74:	31 f6                	xor    %esi,%esi
 105fb76:	31 d2                	xor    %edx,%edx
 105fb78:	45 31 f6             	xor    %r14d,%r14d
 105fb7b:	48 89 4d c8          	mov    %rcx,-0x38(%rbp)
 105fb7f:	90                   	nop
 105fb80:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 105fb84:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 105fb88:	48 89 55 d0          	mov    %rdx,-0x30(%rbp)
 105fb8c:	49 89 cf             	mov    %rcx,%r15
 105fb8f:	4d 29 f7             	sub    %r14,%r15
 105fb92:	49 81 ff 00 00 02 00 	cmp    $0x20000,%r15
 105fb99:	b8 00 00 02 00       	mov    $0x20000,%eax
 105fb9e:	4c 0f 43 f8          	cmovae %rax,%r15
 105fba2:	4b 8d 14 37          	lea    (%r15,%r14,1),%rdx
 105fba6:	49 81 fe 00 00 01 00 	cmp    $0x10000,%r14
 105fbad:	41 bd 00 00 01 00    	mov    $0x10000,%r13d
 105fbb3:	4d 0f 42 ee          	cmovb  %r14,%r13
 105fbb7:	4c 89 f3             	mov    %r14,%rbx
 105fbba:	4c 29 eb             	sub    %r13,%rbx
 105fbbd:	4c 39 f1             	cmp    %r14,%rcx
 105fbc0:	74 25                	je     105fbe7 <deflate64.encoder.encodeAlloc+0x137>
 105fbc2:	49 89 d4             	mov    %rdx,%r12
 105fbc5:	48 29 da             	sub    %rbx,%rdx
 105fbc8:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 105fbcf:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 105fbd3:	c5 f8 77             	vzeroupper 
 105fbd6:	e8 d5 22 03 00       	call   1091eb0 <deflate64.stream_match.Matcher.ensureForSize>
 105fbdb:	4c 89 e2             	mov    %r12,%rdx
 105fbde:	66 85 c0             	test   %ax,%ax
 105fbe1:	0f 85 03 04 00 00    	jne    105ffea <deflate64.encoder.encodeAlloc+0x53a>
 105fbe7:	48 89 95 10 ff ff ff 	mov    %rdx,-0xf0(%rbp)
 105fbee:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 105fbf2:	48 01 c3             	add    %rax,%rbx
 105fbf5:	49 01 c6             	add    %rax,%r14
 105fbf8:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 105fbff:	48 8d b5 30 ff ff ff 	lea    -0xd0(%rbp),%rsi
 105fc06:	48 89 da             	mov    %rbx,%rdx
 105fc09:	4c 89 e9             	mov    %r13,%rcx
 105fc0c:	4d 89 f0             	mov    %r14,%r8
 105fc0f:	4d 89 f9             	mov    %r15,%r9
 105fc12:	68 80 00 00 00       	push   $0x80
 105fc17:	68 80 00 00 00       	push   $0x80
 105fc1c:	c5 f8 77             	vzeroupper 
 105fc1f:	e8 ac 1e 03 00       	call   1091ad0 <deflate64.stream_blocks.fixedPlan>
 105fc24:	48 83 c4 10          	add    $0x10,%rsp
 105fc28:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 105fc2c:	48 03 b5 78 ff ff ff 	add    -0x88(%rbp),%rsi
 105fc33:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 105fc37:	48 83 d2 00          	adc    $0x0,%rdx
 105fc3b:	66 41 bc 43 00       	mov    $0x43,%r12w
 105fc40:	0f 82 a7 03 00 00    	jb     105ffed <deflate64.encoder.encodeAlloc+0x53d>
 105fc46:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 105fc4a:	48 03 45 80          	add    -0x80(%rbp),%rax
 105fc4e:	0f 92 45 c0          	setb   -0x40(%rbp)
 105fc52:	0f 82 95 03 00 00    	jb     105ffed <deflate64.encoder.encodeAlloc+0x53d>
 105fc58:	c4 e2 7d 1a 05 8f 0a 	vbroadcastf128 -0x5f571(%rip),%ymm0        # 10006f0 <__anon_15807+0x10>
 105fc5f:	fa ff 
 105fc61:	c5 fc 11 85 50 ff ff 	vmovups %ymm0,-0xb0(%rbp)
 105fc68:	ff 
 105fc69:	48 8b bd 10 ff ff ff 	mov    -0xf0(%rbp),%rdi
 105fc70:	49 89 fe             	mov    %rdi,%r14
 105fc73:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 105fc77:	48 39 cf             	cmp    %rcx,%rdi
 105fc7a:	0f 85 00 ff ff ff    	jne    105fb80 <deflate64.encoder.encodeAlloc+0xd0>
 105fc80:	48 89 f0             	mov    %rsi,%rax
 105fc83:	48 0f ac d0 03       	shrd   $0x3,%rdx,%rax
 105fc88:	48 c1 ea 03          	shr    $0x3,%rdx
 105fc8c:	45 31 f6             	xor    %r14d,%r14d
 105fc8f:	40 f6 c6 07          	test   $0x7,%sil
 105fc93:	41 0f 95 c6          	setne  %r14b
 105fc97:	49 01 c6             	add    %rax,%r14
 105fc9a:	48 83 d2 00          	adc    $0x0,%rdx
 105fc9e:	4c 3b b5 18 ff ff ff 	cmp    -0xe8(%rbp),%r14
 105fca5:	48 83 da 00          	sbb    $0x0,%rdx
 105fca9:	73 63                	jae    105fd0e <deflate64.encoder.encodeAlloc+0x25e>
 105fcab:	31 c0                	xor    %eax,%eax
 105fcad:	84 c0                	test   %al,%al
 105fcaf:	75 3b                	jne    105fcec <deflate64.encoder.encodeAlloc+0x23c>
 105fcb1:	48 8b 45 08          	mov    0x8(%rbp),%rax
 105fcb5:	4d 85 f6             	test   %r14,%r14
 105fcb8:	48 8b bd 20 ff ff ff 	mov    -0xe0(%rbp),%rdi
 105fcbf:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 105fcc3:	0f 84 ef 00 00 00    	je     105fdb8 <deflate64.encoder.encodeAlloc+0x308>
 105fcc9:	4c 89 f6             	mov    %r14,%rsi
 105fccc:	31 d2                	xor    %edx,%edx
 105fcce:	48 89 cb             	mov    %rcx,%rbx
 105fcd1:	48 89 c1             	mov    %rax,%rcx
 105fcd4:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 105fcdb:	c5 f8 77             	vzeroupper 
 105fcde:	ff 10                	call   *(%rax)
 105fce0:	48 89 d9             	mov    %rbx,%rcx
 105fce3:	48 85 c0             	test   %rax,%rax
 105fce6:	0f 85 d3 00 00 00    	jne    105fdbf <deflate64.encoder.encodeAlloc+0x30f>
 105fcec:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 105fcf3:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 105fcf7:	c5 f8 77             	vzeroupper 
 105fcfa:	e8 51 c0 06 00       	call   10cbd50 <deflate64.stream_match.Matcher.deinit>
 105fcff:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 105fd03:	66 c7 40 10 1a 00    	movw   $0x1a,0x10(%rax)
 105fd09:	e9 12 fe ff ff       	jmp    105fb20 <deflate64.encoder.encodeAlloc+0x70>
 105fd0e:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 105fd12:	48 8b 38             	mov    (%rax),%rdi
 105fd15:	48 8b 58 08          	mov    0x8(%rax),%rbx
 105fd19:	48 85 c9             	test   %rcx,%rcx
 105fd1c:	74 2f                	je     105fd4d <deflate64.encoder.encodeAlloc+0x29d>
 105fd1e:	48 8d 51 ff          	lea    -0x1(%rcx),%rdx
 105fd22:	48 b8 01 80 00 80 00 	movabs $0x8000800080008001,%rax
 105fd29:	80 00 80 
 105fd2c:	c4 e2 fb f6 c0       	mulx   %rax,%rax,%rax
 105fd31:	48 c1 e8 0f          	shr    $0xf,%rax
 105fd35:	48 8d 34 80          	lea    (%rax,%rax,4),%rsi
 105fd39:	48 83 c6 05          	add    $0x5,%rsi
 105fd3d:	66 41 bf 43 00       	mov    $0x43,%r15w
 105fd42:	31 c0                	xor    %eax,%eax
 105fd44:	84 c0                	test   %al,%al
 105fd46:	74 19                	je     105fd61 <deflate64.encoder.encodeAlloc+0x2b1>
 105fd48:	e9 25 02 00 00       	jmp    105ff72 <deflate64.encoder.encodeAlloc+0x4c2>
 105fd4d:	be 05 00 00 00       	mov    $0x5,%esi
 105fd52:	66 41 bf 43 00       	mov    $0x43,%r15w
 105fd57:	31 c0                	xor    %eax,%eax
 105fd59:	84 c0                	test   %al,%al
 105fd5b:	0f 85 11 02 00 00    	jne    105ff72 <deflate64.encoder.encodeAlloc+0x4c2>
 105fd61:	48 01 ce             	add    %rcx,%rsi
 105fd64:	0f 92 c0             	setb   %al
 105fd67:	0f 92 85 78 ff ff ff 	setb   -0x88(%rbp)
 105fd6e:	84 c0                	test   %al,%al
 105fd70:	0f 85 fc 01 00 00    	jne    105ff72 <deflate64.encoder.encodeAlloc+0x4c2>
 105fd76:	66 41 bf 1a 00       	mov    $0x1a,%r15w
 105fd7b:	31 c0                	xor    %eax,%eax
 105fd7d:	84 c0                	test   %al,%al
 105fd7f:	0f 85 ed 01 00 00    	jne    105ff72 <deflate64.encoder.encodeAlloc+0x4c2>
 105fd85:	49 89 cc             	mov    %rcx,%r12
 105fd88:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 105fd8c:	48 85 f6             	test   %rsi,%rsi
 105fd8f:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 105fd93:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 105fd97:	0f 84 5a 01 00 00    	je     105fef7 <deflate64.encoder.encodeAlloc+0x447>
 105fd9d:	49 89 f6             	mov    %rsi,%r14
 105fda0:	31 d2                	xor    %edx,%edx
 105fda2:	c5 f8 77             	vzeroupper 
 105fda5:	ff 13                	call   *(%rbx)
 105fda7:	49 89 c5             	mov    %rax,%r13
 105fdaa:	48 85 c0             	test   %rax,%rax
 105fdad:	0f 85 4e 01 00 00    	jne    105ff01 <deflate64.encoder.encodeAlloc+0x451>
 105fdb3:	e9 ba 01 00 00       	jmp    105ff72 <deflate64.encoder.encodeAlloc+0x4c2>
 105fdb8:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 105fdbf:	48 8b 15 a2 f4 fd ff 	mov    -0x20b5e(%rip),%rdx        # 103f268 <__anon_10821>
 105fdc6:	48 89 55 90          	mov    %rdx,-0x70(%rbp)
 105fdca:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 105fdce:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 105fdd5:	4c 89 75 b0          	mov    %r14,-0x50(%rbp)
 105fdd9:	4c 89 75 80          	mov    %r14,-0x80(%rbp)
 105fddd:	48 c7 45 88 00 00 00 	movq   $0x0,-0x78(%rbp)
 105fde4:	00 
 105fde5:	31 d2                	xor    %edx,%edx
 105fde7:	bb 00 00 02 00       	mov    $0x20000,%ebx
 105fdec:	4c 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%r15
 105fdf3:	4c 8d b5 30 ff ff ff 	lea    -0xd0(%rbp),%r14
 105fdfa:	4c 8b 6d a0          	mov    -0x60(%rbp),%r13
 105fdfe:	66 90                	xchg   %ax,%ax
 105fe00:	49 89 c9             	mov    %rcx,%r9
 105fe03:	49 29 d1             	sub    %rdx,%r9
 105fe06:	49 81 f9 00 00 02 00 	cmp    $0x20000,%r9
 105fe0d:	4c 0f 43 cb          	cmovae %rbx,%r9
 105fe11:	4d 8d 24 11          	lea    (%r9,%rdx,1),%r12
 105fe15:	48 81 fa 00 00 01 00 	cmp    $0x10000,%rdx
 105fe1c:	b9 00 00 01 00       	mov    $0x10000,%ecx
 105fe21:	48 0f 42 ca          	cmovb  %rdx,%rcx
 105fe25:	4e 8d 04 2a          	lea    (%rdx,%r13,1),%r8
 105fe29:	48 29 ca             	sub    %rcx,%rdx
 105fe2c:	4c 01 ea             	add    %r13,%rdx
 105fe2f:	31 c0                	xor    %eax,%eax
 105fe31:	4c 3b 65 c8          	cmp    -0x38(%rbp),%r12
 105fe35:	0f 94 c0             	sete   %al
 105fe38:	48 83 ec 08          	sub    $0x8,%rsp
 105fe3c:	4c 89 ff             	mov    %r15,%rdi
 105fe3f:	4c 89 f6             	mov    %r14,%rsi
 105fe42:	50                   	push   %rax
 105fe43:	68 80 00 00 00       	push   $0x80
 105fe48:	68 80 00 00 00       	push   $0x80
 105fe4d:	c5 f8 77             	vzeroupper 
 105fe50:	e8 6b 13 03 00       	call   10911c0 <deflate64.stream_blocks.writeFixed>
 105fe55:	48 83 c4 20          	add    $0x20,%rsp
 105fe59:	4c 89 e2             	mov    %r12,%rdx
 105fe5c:	4c 3b 65 c8          	cmp    -0x38(%rbp),%r12
 105fe60:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 105fe64:	75 9a                	jne    105fe00 <deflate64.encoder.encodeAlloc+0x350>
 105fe66:	f6 45 94 07          	testb  $0x7,-0x6c(%rbp)
 105fe6a:	74 12                	je     105fe7e <deflate64.encoder.encodeAlloc+0x3ce>
 105fe6c:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 105fe70:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 105fe77:	0f b6 55 90          	movzbl -0x70(%rbp),%edx
 105fe7b:	88 14 01             	mov    %dl,(%rcx,%rax,1)
 105fe7e:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 105fe82:	48 8b 18             	mov    (%rax),%rbx
 105fe85:	4c 8b 70 08          	mov    0x8(%rax),%r14
 105fe89:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 105fe90:	48 85 d2             	test   %rdx,%rdx
 105fe93:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 105fe97:	74 1a                	je     105feb3 <deflate64.encoder.encodeAlloc+0x403>
 105fe99:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 105fea0:	48 c1 e2 02          	shl    $0x2,%rdx
 105fea4:	48 89 df             	mov    %rbx,%rdi
 105fea7:	b9 02 00 00 00       	mov    $0x2,%ecx
 105feac:	4d 89 f8             	mov    %r15,%r8
 105feaf:	41 ff 56 18          	call   *0x18(%r14)
 105feb3:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 105feba:	48 85 d2             	test   %rdx,%rdx
 105febd:	74 1a                	je     105fed9 <deflate64.encoder.encodeAlloc+0x429>
 105febf:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 105fec6:	48 c1 e2 02          	shl    $0x2,%rdx
 105feca:	48 89 df             	mov    %rbx,%rdi
 105fecd:	b9 02 00 00 00       	mov    $0x2,%ecx
 105fed2:	4d 89 f8             	mov    %r15,%r8
 105fed5:	41 ff 56 18          	call   *0x18(%r14)
 105fed9:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 105fedd:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 105fee3:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 105fee7:	48 89 08             	mov    %rcx,(%rax)
 105feea:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 105feee:	48 89 48 08          	mov    %rcx,0x8(%rax)
 105fef2:	e9 29 fc ff ff       	jmp    105fb20 <deflate64.encoder.encodeAlloc+0x70>
 105fef7:	49 89 f6             	mov    %rsi,%r14
 105fefa:	49 c7 c5 ff ff ff ff 	mov    $0xffffffffffffffff,%r13
 105ff01:	4d 85 e4             	test   %r12,%r12
 105ff04:	74 22                	je     105ff28 <deflate64.encoder.encodeAlloc+0x478>
 105ff06:	49 8d 54 24 ff       	lea    -0x1(%r12),%rdx
 105ff0b:	48 b8 01 80 00 80 00 	movabs $0x8000800080008001,%rax
 105ff12:	80 00 80 
 105ff15:	c4 e2 fb f6 c0       	mulx   %rax,%rax,%rax
 105ff1a:	48 c1 e8 0f          	shr    $0xf,%rax
 105ff1e:	48 8d 04 80          	lea    (%rax,%rax,4),%rax
 105ff22:	48 83 c0 05          	add    $0x5,%rax
 105ff26:	eb 05                	jmp    105ff2d <deflate64.encoder.encodeAlloc+0x47d>
 105ff28:	b8 05 00 00 00       	mov    $0x5,%eax
 105ff2d:	66 41 bf 43 00       	mov    $0x43,%r15w
 105ff32:	31 c9                	xor    %ecx,%ecx
 105ff34:	84 c9                	test   %cl,%cl
 105ff36:	75 1f                	jne    105ff57 <deflate64.encoder.encodeAlloc+0x4a7>
 105ff38:	4c 01 e0             	add    %r12,%rax
 105ff3b:	0f 92 c1             	setb   %cl
 105ff3e:	0f 92 85 78 ff ff ff 	setb   -0x88(%rbp)
 105ff45:	84 c9                	test   %cl,%cl
 105ff47:	75 0e                	jne    105ff57 <deflate64.encoder.encodeAlloc+0x4a7>
 105ff49:	66 41 bf 3b 00       	mov    $0x3b,%r15w
 105ff4e:	49 39 c6             	cmp    %rax,%r14
 105ff51:	0f 83 b4 00 00 00    	jae    106000b <deflate64.encoder.encodeAlloc+0x55b>
 105ff57:	4d 85 f6             	test   %r14,%r14
 105ff5a:	74 16                	je     105ff72 <deflate64.encoder.encodeAlloc+0x4c2>
 105ff5c:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 105ff60:	4c 89 ee             	mov    %r13,%rsi
 105ff63:	4c 89 f2             	mov    %r14,%rdx
 105ff66:	31 c9                	xor    %ecx,%ecx
 105ff68:	4c 8b 45 b0          	mov    -0x50(%rbp),%r8
 105ff6c:	c5 f8 77             	vzeroupper 
 105ff6f:	ff 53 18             	call   *0x18(%rbx)
 105ff72:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 105ff76:	48 8b 18             	mov    (%rax),%rbx
 105ff79:	4c 8b 70 08          	mov    0x8(%rax),%r14
 105ff7d:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 105ff84:	48 85 d2             	test   %rdx,%rdx
 105ff87:	74 1e                	je     105ffa7 <deflate64.encoder.encodeAlloc+0x4f7>
 105ff89:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 105ff90:	48 c1 e2 02          	shl    $0x2,%rdx
 105ff94:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 105ff98:	48 89 df             	mov    %rbx,%rdi
 105ff9b:	b9 02 00 00 00       	mov    $0x2,%ecx
 105ffa0:	c5 f8 77             	vzeroupper 
 105ffa3:	41 ff 56 18          	call   *0x18(%r14)
 105ffa7:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 105ffae:	48 85 d2             	test   %rdx,%rdx
 105ffb1:	74 1e                	je     105ffd1 <deflate64.encoder.encodeAlloc+0x521>
 105ffb3:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 105ffba:	48 c1 e2 02          	shl    $0x2,%rdx
 105ffbe:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 105ffc2:	48 89 df             	mov    %rbx,%rdi
 105ffc5:	b9 02 00 00 00       	mov    $0x2,%ecx
 105ffca:	c5 f8 77             	vzeroupper 
 105ffcd:	41 ff 56 18          	call   *0x18(%r14)
 105ffd1:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 105ffd5:	4c 89 28             	mov    %r13,(%rax)
 105ffd8:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 105ffdc:	48 89 48 08          	mov    %rcx,0x8(%rax)
 105ffe0:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 105ffe5:	e9 36 fb ff ff       	jmp    105fb20 <deflate64.encoder.encodeAlloc+0x70>
 105ffea:	41 89 c4             	mov    %eax,%r12d
 105ffed:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 105fff4:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 105fff8:	e8 53 bd 06 00       	call   10cbd50 <deflate64.stream_match.Matcher.deinit>
 105fffd:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 1060001:	66 44 89 60 10       	mov    %r12w,0x10(%rax)
 1060006:	e9 15 fb ff ff       	jmp    105fb20 <deflate64.encoder.encodeAlloc+0x70>
 106000b:	4c 89 75 d0          	mov    %r14,-0x30(%rbp)
 106000f:	45 31 f6             	xor    %r14d,%r14d
 1060012:	31 f6                	xor    %esi,%esi
 1060014:	4c 89 e3             	mov    %r12,%rbx
 1060017:	48 29 f3             	sub    %rsi,%rbx
 106001a:	48 81 fb ff ff 00 00 	cmp    $0xffff,%rbx
 1060021:	b8 ff ff 00 00       	mov    $0xffff,%eax
 1060026:	48 0f 43 d8          	cmovae %rax,%rbx
 106002a:	4c 8d 24 33          	lea    (%rbx,%rsi,1),%r12
 106002e:	4c 3b 65 c8          	cmp    -0x38(%rbp),%r12
 1060032:	43 0f 94 44 35 00    	sete   0x0(%r13,%r14,1)
 1060038:	66 43 89 5c 35 01    	mov    %bx,0x1(%r13,%r14,1)
 106003e:	89 d8                	mov    %ebx,%eax
 1060040:	f7 d0                	not    %eax
 1060042:	66 43 89 44 35 03    	mov    %ax,0x3(%r13,%r14,1)
 1060048:	4b 8d 3c 2e          	lea    (%r14,%r13,1),%rdi
 106004c:	48 83 c7 05          	add    $0x5,%rdi
 1060050:	48 03 75 a0          	add    -0x60(%rbp),%rsi
 1060054:	48 89 da             	mov    %rbx,%rdx
 1060057:	c5 f8 77             	vzeroupper 
 106005a:	e8 71 46 07 00       	call   10d46d0 <compiler_rt.memcpy.memcpyFast>
 106005f:	45 31 ff             	xor    %r15d,%r15d
 1060062:	49 01 de             	add    %rbx,%r14
 1060065:	49 83 c6 05          	add    $0x5,%r14
 1060069:	4c 89 e6             	mov    %r12,%rsi
 106006c:	4c 3b 65 c8          	cmp    -0x38(%rbp),%r12
 1060070:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 1060074:	72 a1                	jb     1060017 <deflate64.encoder.encodeAlloc+0x567>
 1060076:	e9 f7 fe ff ff       	jmp    105ff72 <deflate64.encoder.encodeAlloc+0x4c2>
