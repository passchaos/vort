
/tmp/vort-deflate64-index-capacity-20261025/old-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

000000000105fa70 <deflate64.encoder.encodeAlloc>:
 105fa70:	55                   	push   %rbp
 105fa71:	48 89 e5             	mov    %rsp,%rbp
 105fa74:	41 57                	push   %r15
 105fa76:	41 56                	push   %r14
 105fa78:	41 55                	push   %r13
 105fa7a:	41 54                	push   %r12
 105fa7c:	53                   	push   %rbx
 105fa7d:	48 81 ec e8 00 00 00 	sub    $0xe8,%rsp
 105fa84:	49 89 d0             	mov    %rdx,%r8
 105fa87:	4c 8b 2e             	mov    (%rsi),%r13
 105fa8a:	4c 8b 66 08          	mov    0x8(%rsi),%r12
 105fa8e:	48 85 c9             	test   %rcx,%rcx
 105fa91:	74 27                	je     105faba <deflate64.encoder.encodeAlloc+0x4a>
 105fa93:	48 8d 51 ff          	lea    -0x1(%rcx),%rdx
 105fa97:	48 b8 01 80 00 80 00 	movabs $0x8000800080008001,%rax
 105fa9e:	80 00 80 
 105faa1:	c4 e2 fb f6 c0       	mulx   %rax,%rax,%rax
 105faa6:	48 c1 e8 0f          	shr    $0xf,%rax
 105faaa:	48 8d 14 80          	lea    (%rax,%rax,4),%rdx
 105faae:	48 83 c2 05          	add    $0x5,%rdx
 105fab2:	31 c0                	xor    %eax,%eax
 105fab4:	84 c0                	test   %al,%al
 105fab6:	74 0d                	je     105fac5 <deflate64.encoder.encodeAlloc+0x55>
 105fab8:	eb 1c                	jmp    105fad6 <deflate64.encoder.encodeAlloc+0x66>
 105faba:	ba 05 00 00 00       	mov    $0x5,%edx
 105fabf:	31 c0                	xor    %eax,%eax
 105fac1:	84 c0                	test   %al,%al
 105fac3:	75 11                	jne    105fad6 <deflate64.encoder.encodeAlloc+0x66>
 105fac5:	48 01 ca             	add    %rcx,%rdx
 105fac8:	0f 92 c0             	setb   %al
 105facb:	0f 92 85 78 ff ff ff 	setb   -0x88(%rbp)
 105fad2:	84 c0                	test   %al,%al
 105fad4:	74 0b                	je     105fae1 <deflate64.encoder.encodeAlloc+0x71>
 105fad6:	66 c7 47 10 43 00    	movw   $0x43,0x10(%rdi)
 105fadc:	e9 46 02 00 00       	jmp    105fd27 <deflate64.encoder.encodeAlloc+0x2b7>
 105fae1:	c5 fc 10 05 b7 ef fa 	vmovups -0x51049(%rip),%ymm0        # 100eaa0 <__anon_3137>
 105fae8:	ff 
 105fae9:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 105faf0:	ff 
 105faf1:	c5 fc 10 05 c7 ef fa 	vmovups -0x51039(%rip),%ymm0        # 100eac0 <__anon_3137+0x20>
 105faf8:	ff 
 105faf9:	c5 fc 11 85 50 ff ff 	vmovups %ymm0,-0xb0(%rbp)
 105fb00:	ff 
 105fb01:	48 85 c9             	test   %rcx,%rcx
 105fb04:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 105fb08:	0f 84 a6 00 00 00    	je     105fbb4 <deflate64.encoder.encodeAlloc+0x144>
 105fb0e:	c6 45 d0 00          	movb   $0x0,-0x30(%rbp)
 105fb12:	31 c0                	xor    %eax,%eax
 105fb14:	84 c0                	test   %al,%al
 105fb16:	74 0a                	je     105fb22 <deflate64.encoder.encodeAlloc+0xb2>
 105fb18:	66 41 bf 1a 00       	mov    $0x1a,%r15w
 105fb1d:	e9 ed 01 00 00       	jmp    105fd0f <deflate64.encoder.encodeAlloc+0x29f>
 105fb22:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 105fb26:	4c 89 45 a0          	mov    %r8,-0x60(%rbp)
 105fb2a:	49 89 ce             	mov    %rcx,%r14
 105fb2d:	48 89 f3             	mov    %rsi,%rbx
 105fb30:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 105fb34:	be 00 00 02 00       	mov    $0x20000,%esi
 105fb39:	4c 89 ef             	mov    %r13,%rdi
 105fb3c:	ba 02 00 00 00       	mov    $0x2,%edx
 105fb41:	c5 f8 77             	vzeroupper 
 105fb44:	41 ff 14 24          	call   *(%r12)
 105fb48:	66 41 bf 1a 00       	mov    $0x1a,%r15w
 105fb4d:	48 85 c0             	test   %rax,%rax
 105fb50:	74 1c                	je     105fb6e <deflate64.encoder.encodeAlloc+0xfe>
 105fb52:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 105fb59:	48 c7 85 38 ff ff ff 	movq   $0x8000,-0xc8(%rbp)
 105fb60:	00 80 00 00 
 105fb64:	c6 45 d0 00          	movb   $0x0,-0x30(%rbp)
 105fb68:	31 c0                	xor    %eax,%eax
 105fb6a:	84 c0                	test   %al,%al
 105fb6c:	74 08                	je     105fb76 <deflate64.encoder.encodeAlloc+0x106>
 105fb6e:	48 89 de             	mov    %rbx,%rsi
 105fb71:	e9 99 01 00 00       	jmp    105fd0f <deflate64.encoder.encodeAlloc+0x29f>
 105fb76:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 105fb7a:	be 00 00 04 00       	mov    $0x40000,%esi
 105fb7f:	4c 89 ef             	mov    %r13,%rdi
 105fb82:	ba 02 00 00 00       	mov    $0x2,%edx
 105fb87:	41 ff 14 24          	call   *(%r12)
 105fb8b:	48 85 c0             	test   %rax,%rax
 105fb8e:	48 89 de             	mov    %rbx,%rsi
 105fb91:	0f 84 78 01 00 00    	je     105fd0f <deflate64.encoder.encodeAlloc+0x29f>
 105fb97:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 105fb9e:	48 c7 85 48 ff ff ff 	movq   $0x10000,-0xb8(%rbp)
 105fba5:	00 00 01 00 
 105fba9:	4c 89 f1             	mov    %r14,%rcx
 105fbac:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 105fbb0:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 105fbb4:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 105fbb8:	4c 89 6d 98          	mov    %r13,-0x68(%rbp)
 105fbbc:	4c 89 65 a8          	mov    %r12,-0x58(%rbp)
 105fbc0:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 105fbc4:	45 31 ed             	xor    %r13d,%r13d
 105fbc7:	45 31 ff             	xor    %r15d,%r15d
 105fbca:	45 31 e4             	xor    %r12d,%r12d
 105fbcd:	31 db                	xor    %ebx,%ebx
 105fbcf:	48 89 4d c0          	mov    %rcx,-0x40(%rbp)
 105fbd3:	4c 89 45 a0          	mov    %r8,-0x60(%rbp)
 105fbd7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 105fbde:	00 00 
 105fbe0:	49 89 ce             	mov    %rcx,%r14
 105fbe3:	49 29 de             	sub    %rbx,%r14
 105fbe6:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 105fbed:	b8 00 00 02 00       	mov    $0x20000,%eax
 105fbf2:	4c 0f 43 f0          	cmovae %rax,%r14
 105fbf6:	48 81 fb 00 00 01 00 	cmp    $0x10000,%rbx
 105fbfd:	b9 00 00 01 00       	mov    $0x10000,%ecx
 105fc02:	48 0f 42 cb          	cmovb  %rbx,%rcx
 105fc06:	48 89 da             	mov    %rbx,%rdx
 105fc09:	48 29 ca             	sub    %rcx,%rdx
 105fc0c:	4c 01 c2             	add    %r8,%rdx
 105fc0f:	49 01 d8             	add    %rbx,%r8
 105fc12:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 105fc19:	48 8d b5 30 ff ff ff 	lea    -0xd0(%rbp),%rsi
 105fc20:	4d 89 f1             	mov    %r14,%r9
 105fc23:	68 80 00 00 00       	push   $0x80
 105fc28:	68 80 00 00 00       	push   $0x80
 105fc2d:	c5 f8 77             	vzeroupper 
 105fc30:	e8 0b 1f 03 00       	call   1091b40 <deflate64.stream_blocks.fixedPlan>
 105fc35:	48 83 c4 10          	add    $0x10,%rsp
 105fc39:	4c 03 bd 78 ff ff ff 	add    -0x88(%rbp),%r15
 105fc40:	49 83 d4 00          	adc    $0x0,%r12
 105fc44:	0f 82 bc 00 00 00    	jb     105fd06 <deflate64.encoder.encodeAlloc+0x296>
 105fc4a:	4c 03 6d 80          	add    -0x80(%rbp),%r13
 105fc4e:	0f 92 45 d0          	setb   -0x30(%rbp)
 105fc52:	0f 82 ae 00 00 00    	jb     105fd06 <deflate64.encoder.encodeAlloc+0x296>
 105fc58:	4c 01 f3             	add    %r14,%rbx
 105fc5b:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 105fc5f:	48 39 cb             	cmp    %rcx,%rbx
 105fc62:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 105fc66:	0f 85 74 ff ff ff    	jne    105fbe0 <deflate64.encoder.encodeAlloc+0x170>
 105fc6c:	c4 e2 7d 1a 05 7b 0a 	vbroadcastf128 -0x5f585(%rip),%ymm0        # 10006f0 <__anon_15807+0x10>
 105fc73:	fa ff 
 105fc75:	c5 fc 11 85 50 ff ff 	vmovups %ymm0,-0xb0(%rbp)
 105fc7c:	ff 
 105fc7d:	4c 89 f8             	mov    %r15,%rax
 105fc80:	4c 0f ac e0 03       	shrd   $0x3,%r12,%rax
 105fc85:	49 c1 ec 03          	shr    $0x3,%r12
 105fc89:	45 31 f6             	xor    %r14d,%r14d
 105fc8c:	41 f6 c7 07          	test   $0x7,%r15b
 105fc90:	41 0f 95 c6          	setne  %r14b
 105fc94:	49 01 c6             	add    %rax,%r14
 105fc97:	49 83 d4 00          	adc    $0x0,%r12
 105fc9b:	4c 3b 75 b8          	cmp    -0x48(%rbp),%r14
 105fc9f:	49 83 dc 00          	sbb    $0x0,%r12
 105fca3:	0f 83 93 00 00 00    	jae    105fd3c <deflate64.encoder.encodeAlloc+0x2cc>
 105fca9:	31 c0                	xor    %eax,%eax
 105fcab:	84 c0                	test   %al,%al
 105fcad:	4c 8b 7d b0          	mov    -0x50(%rbp),%r15
 105fcb1:	75 35                	jne    105fce8 <deflate64.encoder.encodeAlloc+0x278>
 105fcb3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 105fcb7:	4d 85 f6             	test   %r14,%r14
 105fcba:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 105fcbe:	48 8b 7d 98          	mov    -0x68(%rbp),%rdi
 105fcc2:	4c 89 45 b8          	mov    %r8,-0x48(%rbp)
 105fcc6:	0f 84 13 01 00 00    	je     105fddf <deflate64.encoder.encodeAlloc+0x36f>
 105fccc:	4c 89 f6             	mov    %r14,%rsi
 105fccf:	31 d2                	xor    %edx,%edx
 105fcd1:	48 89 cb             	mov    %rcx,%rbx
 105fcd4:	4c 89 c1             	mov    %r8,%rcx
 105fcd7:	c5 f8 77             	vzeroupper 
 105fcda:	ff 10                	call   *(%rax)
 105fcdc:	48 89 d9             	mov    %rbx,%rcx
 105fcdf:	48 85 c0             	test   %rax,%rax
 105fce2:	0f 85 fe 00 00 00    	jne    105fde6 <deflate64.encoder.encodeAlloc+0x376>
 105fce8:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 105fcef:	4c 89 fe             	mov    %r15,%rsi
 105fcf2:	c5 f8 77             	vzeroupper 
 105fcf5:	e8 66 be 06 00       	call   10cbb60 <deflate64.stream_match.Matcher.deinit>
 105fcfa:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 105fcfe:	66 c7 40 10 1a 00    	movw   $0x1a,0x10(%rax)
 105fd04:	eb 21                	jmp    105fd27 <deflate64.encoder.encodeAlloc+0x2b7>
 105fd06:	66 41 bf 43 00       	mov    $0x43,%r15w
 105fd0b:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 105fd0f:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 105fd16:	c5 f8 77             	vzeroupper 
 105fd19:	e8 42 be 06 00       	call   10cbb60 <deflate64.stream_match.Matcher.deinit>
 105fd1e:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 105fd22:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 105fd27:	48 81 c4 e8 00 00 00 	add    $0xe8,%rsp
 105fd2e:	5b                   	pop    %rbx
 105fd2f:	41 5c                	pop    %r12
 105fd31:	41 5d                	pop    %r13
 105fd33:	41 5e                	pop    %r14
 105fd35:	41 5f                	pop    %r15
 105fd37:	5d                   	pop    %rbp
 105fd38:	c5 f8 77             	vzeroupper 
 105fd3b:	c3                   	ret    
 105fd3c:	4c 8b 7d b0          	mov    -0x50(%rbp),%r15
 105fd40:	49 8b 3f             	mov    (%r15),%rdi
 105fd43:	4d 8b 77 08          	mov    0x8(%r15),%r14
 105fd47:	48 85 c9             	test   %rcx,%rcx
 105fd4a:	74 21                	je     105fd6d <deflate64.encoder.encodeAlloc+0x2fd>
 105fd4c:	48 8d 51 ff          	lea    -0x1(%rcx),%rdx
 105fd50:	48 b8 01 80 00 80 00 	movabs $0x8000800080008001,%rax
 105fd57:	80 00 80 
 105fd5a:	c4 e2 fb f6 c0       	mulx   %rax,%rax,%rax
 105fd5f:	48 c1 e8 0f          	shr    $0xf,%rax
 105fd63:	48 8d 1c 80          	lea    (%rax,%rax,4),%rbx
 105fd67:	48 83 c3 05          	add    $0x5,%rbx
 105fd6b:	eb 05                	jmp    105fd72 <deflate64.encoder.encodeAlloc+0x302>
 105fd6d:	bb 05 00 00 00       	mov    $0x5,%ebx
 105fd72:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 105fd76:	66 41 bc 43 00       	mov    $0x43,%r12w
 105fd7b:	31 c0                	xor    %eax,%eax
 105fd7d:	84 c0                	test   %al,%al
 105fd7f:	0f 85 23 02 00 00    	jne    105ffa8 <deflate64.encoder.encodeAlloc+0x538>
 105fd85:	48 03 5d c0          	add    -0x40(%rbp),%rbx
 105fd89:	0f 92 c0             	setb   %al
 105fd8c:	0f 92 85 78 ff ff ff 	setb   -0x88(%rbp)
 105fd93:	84 c0                	test   %al,%al
 105fd95:	0f 85 0d 02 00 00    	jne    105ffa8 <deflate64.encoder.encodeAlloc+0x538>
 105fd9b:	66 41 bc 1a 00       	mov    $0x1a,%r12w
 105fda0:	31 c0                	xor    %eax,%eax
 105fda2:	84 c0                	test   %al,%al
 105fda4:	0f 85 fe 01 00 00    	jne    105ffa8 <deflate64.encoder.encodeAlloc+0x538>
 105fdaa:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 105fdae:	48 85 db             	test   %rbx,%rbx
 105fdb1:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 105fdb5:	48 89 4d a8          	mov    %rcx,-0x58(%rbp)
 105fdb9:	0f 84 68 01 00 00    	je     105ff27 <deflate64.encoder.encodeAlloc+0x4b7>
 105fdbf:	48 89 de             	mov    %rbx,%rsi
 105fdc2:	31 d2                	xor    %edx,%edx
 105fdc4:	c5 f8 77             	vzeroupper 
 105fdc7:	41 ff 16             	call   *(%r14)
 105fdca:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 105fdce:	49 89 c5             	mov    %rax,%r13
 105fdd1:	48 85 c0             	test   %rax,%rax
 105fdd4:	0f 85 54 01 00 00    	jne    105ff2e <deflate64.encoder.encodeAlloc+0x4be>
 105fdda:	e9 c9 01 00 00       	jmp    105ffa8 <deflate64.encoder.encodeAlloc+0x538>
 105fddf:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 105fde6:	48 8b 15 7b f4 fd ff 	mov    -0x20b85(%rip),%rdx        # 103f268 <__anon_10821>
 105fded:	48 89 55 90          	mov    %rdx,-0x70(%rbp)
 105fdf1:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 105fdf5:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 105fdfc:	4c 89 75 a8          	mov    %r14,-0x58(%rbp)
 105fe00:	4c 89 75 80          	mov    %r14,-0x80(%rbp)
 105fe04:	48 c7 45 88 00 00 00 	movq   $0x0,-0x78(%rbp)
 105fe0b:	00 
 105fe0c:	31 d2                	xor    %edx,%edx
 105fe0e:	bb 00 00 02 00       	mov    $0x20000,%ebx
 105fe13:	4c 8d a5 78 ff ff ff 	lea    -0x88(%rbp),%r12
 105fe1a:	4c 8d ad 30 ff ff ff 	lea    -0xd0(%rbp),%r13
 105fe21:	4c 8b 7d a0          	mov    -0x60(%rbp),%r15
 105fe25:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 105fe2c:	00 00 00 00 
 105fe30:	49 89 c9             	mov    %rcx,%r9
 105fe33:	49 29 d1             	sub    %rdx,%r9
 105fe36:	49 81 f9 00 00 02 00 	cmp    $0x20000,%r9
 105fe3d:	4c 0f 43 cb          	cmovae %rbx,%r9
 105fe41:	4d 8d 34 11          	lea    (%r9,%rdx,1),%r14
 105fe45:	48 81 fa 00 00 01 00 	cmp    $0x10000,%rdx
 105fe4c:	b9 00 00 01 00       	mov    $0x10000,%ecx
 105fe51:	48 0f 42 ca          	cmovb  %rdx,%rcx
 105fe55:	4d 8d 04 17          	lea    (%r15,%rdx,1),%r8
 105fe59:	48 29 ca             	sub    %rcx,%rdx
 105fe5c:	4c 01 fa             	add    %r15,%rdx
 105fe5f:	31 c0                	xor    %eax,%eax
 105fe61:	4c 3b 75 c0          	cmp    -0x40(%rbp),%r14
 105fe65:	0f 94 c0             	sete   %al
 105fe68:	48 83 ec 08          	sub    $0x8,%rsp
 105fe6c:	4c 89 e7             	mov    %r12,%rdi
 105fe6f:	4c 89 ee             	mov    %r13,%rsi
 105fe72:	50                   	push   %rax
 105fe73:	68 80 00 00 00       	push   $0x80
 105fe78:	68 80 00 00 00       	push   $0x80
 105fe7d:	c5 f8 77             	vzeroupper 
 105fe80:	e8 db 13 03 00       	call   1091260 <deflate64.stream_blocks.writeFixed>
 105fe85:	48 83 c4 20          	add    $0x20,%rsp
 105fe89:	4c 89 f2             	mov    %r14,%rdx
 105fe8c:	4c 3b 75 c0          	cmp    -0x40(%rbp),%r14
 105fe90:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 105fe94:	75 9a                	jne    105fe30 <deflate64.encoder.encodeAlloc+0x3c0>
 105fe96:	f6 45 94 07          	testb  $0x7,-0x6c(%rbp)
 105fe9a:	74 12                	je     105feae <deflate64.encoder.encodeAlloc+0x43e>
 105fe9c:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 105fea0:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 105fea7:	0f b6 55 90          	movzbl -0x70(%rbp),%edx
 105feab:	88 14 01             	mov    %dl,(%rcx,%rax,1)
 105feae:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 105feb2:	48 8b 18             	mov    (%rax),%rbx
 105feb5:	4c 8b 70 08          	mov    0x8(%rax),%r14
 105feb9:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 105fec0:	48 85 d2             	test   %rdx,%rdx
 105fec3:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 105fec7:	74 1a                	je     105fee3 <deflate64.encoder.encodeAlloc+0x473>
 105fec9:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 105fed0:	48 c1 e2 02          	shl    $0x2,%rdx
 105fed4:	48 89 df             	mov    %rbx,%rdi
 105fed7:	b9 02 00 00 00       	mov    $0x2,%ecx
 105fedc:	4d 89 f8             	mov    %r15,%r8
 105fedf:	41 ff 56 18          	call   *0x18(%r14)
 105fee3:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 105feea:	48 85 d2             	test   %rdx,%rdx
 105feed:	74 1a                	je     105ff09 <deflate64.encoder.encodeAlloc+0x499>
 105feef:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 105fef6:	48 c1 e2 02          	shl    $0x2,%rdx
 105fefa:	48 89 df             	mov    %rbx,%rdi
 105fefd:	b9 02 00 00 00       	mov    $0x2,%ecx
 105ff02:	4d 89 f8             	mov    %r15,%r8
 105ff05:	41 ff 56 18          	call   *0x18(%r14)
 105ff09:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 105ff0d:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 105ff13:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 105ff17:	48 89 08             	mov    %rcx,(%rax)
 105ff1a:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 105ff1e:	48 89 48 08          	mov    %rcx,0x8(%rax)
 105ff22:	e9 00 fe ff ff       	jmp    105fd27 <deflate64.encoder.encodeAlloc+0x2b7>
 105ff27:	49 c7 c5 ff ff ff ff 	mov    $0xffffffffffffffff,%r13
 105ff2e:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 105ff32:	48 85 c0             	test   %rax,%rax
 105ff35:	74 21                	je     105ff58 <deflate64.encoder.encodeAlloc+0x4e8>
 105ff37:	48 8d 50 ff          	lea    -0x1(%rax),%rdx
 105ff3b:	48 b8 01 80 00 80 00 	movabs $0x8000800080008001,%rax
 105ff42:	80 00 80 
 105ff45:	c4 e2 fb f6 c0       	mulx   %rax,%rax,%rax
 105ff4a:	48 c1 e8 0f          	shr    $0xf,%rax
 105ff4e:	48 8d 04 80          	lea    (%rax,%rax,4),%rax
 105ff52:	48 83 c0 05          	add    $0x5,%rax
 105ff56:	eb 05                	jmp    105ff5d <deflate64.encoder.encodeAlloc+0x4ed>
 105ff58:	b8 05 00 00 00       	mov    $0x5,%eax
 105ff5d:	66 41 bc 43 00       	mov    $0x43,%r12w
 105ff62:	31 d2                	xor    %edx,%edx
 105ff64:	84 d2                	test   %dl,%dl
 105ff66:	75 20                	jne    105ff88 <deflate64.encoder.encodeAlloc+0x518>
 105ff68:	48 03 45 c0          	add    -0x40(%rbp),%rax
 105ff6c:	0f 92 c2             	setb   %dl
 105ff6f:	0f 92 85 78 ff ff ff 	setb   -0x88(%rbp)
 105ff76:	84 d2                	test   %dl,%dl
 105ff78:	75 0e                	jne    105ff88 <deflate64.encoder.encodeAlloc+0x518>
 105ff7a:	66 41 bc 3b 00       	mov    $0x3b,%r12w
 105ff7f:	48 39 c3             	cmp    %rax,%rbx
 105ff82:	0f 83 98 00 00 00    	jae    1060020 <deflate64.encoder.encodeAlloc+0x5b0>
 105ff88:	48 85 db             	test   %rbx,%rbx
 105ff8b:	74 1b                	je     105ffa8 <deflate64.encoder.encodeAlloc+0x538>
 105ff8d:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 105ff91:	4c 89 ee             	mov    %r13,%rsi
 105ff94:	48 89 da             	mov    %rbx,%rdx
 105ff97:	31 c9                	xor    %ecx,%ecx
 105ff99:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 105ff9d:	c5 f8 77             	vzeroupper 
 105ffa0:	41 ff 56 18          	call   *0x18(%r14)
 105ffa4:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 105ffa8:	49 8b 1f             	mov    (%r15),%rbx
 105ffab:	4d 8b 77 08          	mov    0x8(%r15),%r14
 105ffaf:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 105ffb6:	48 85 d2             	test   %rdx,%rdx
 105ffb9:	74 22                	je     105ffdd <deflate64.encoder.encodeAlloc+0x56d>
 105ffbb:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 105ffc2:	48 c1 e2 02          	shl    $0x2,%rdx
 105ffc6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 105ffca:	48 89 df             	mov    %rbx,%rdi
 105ffcd:	b9 02 00 00 00       	mov    $0x2,%ecx
 105ffd2:	c5 f8 77             	vzeroupper 
 105ffd5:	41 ff 56 18          	call   *0x18(%r14)
 105ffd9:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 105ffdd:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 105ffe4:	48 85 d2             	test   %rdx,%rdx
 105ffe7:	74 22                	je     106000b <deflate64.encoder.encodeAlloc+0x59b>
 105ffe9:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 105fff0:	48 c1 e2 02          	shl    $0x2,%rdx
 105fff4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 105fff8:	48 89 df             	mov    %rbx,%rdi
 105fffb:	b9 02 00 00 00       	mov    $0x2,%ecx
 1060000:	c5 f8 77             	vzeroupper 
 1060003:	41 ff 56 18          	call   *0x18(%r14)
 1060007:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 106000b:	4c 89 2e             	mov    %r13,(%rsi)
 106000e:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1060012:	48 89 46 08          	mov    %rax,0x8(%rsi)
 1060016:	66 44 89 66 10       	mov    %r12w,0x10(%rsi)
 106001b:	e9 07 fd ff ff       	jmp    105fd27 <deflate64.encoder.encodeAlloc+0x2b7>
 1060020:	48 89 5d b8          	mov    %rbx,-0x48(%rbp)
 1060024:	31 db                	xor    %ebx,%ebx
 1060026:	31 f6                	xor    %esi,%esi
 1060028:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 106002c:	49 29 f6             	sub    %rsi,%r14
 106002f:	49 81 fe ff ff 00 00 	cmp    $0xffff,%r14
 1060036:	b8 ff ff 00 00       	mov    $0xffff,%eax
 106003b:	4c 0f 43 f0          	cmovae %rax,%r14
 106003f:	4d 8d 3c 36          	lea    (%r14,%rsi,1),%r15
 1060043:	4c 3b 7d c0          	cmp    -0x40(%rbp),%r15
 1060047:	41 0f 94 44 1d 00    	sete   0x0(%r13,%rbx,1)
 106004d:	66 45 89 74 1d 01    	mov    %r14w,0x1(%r13,%rbx,1)
 1060053:	44 89 f0             	mov    %r14d,%eax
 1060056:	f7 d0                	not    %eax
 1060058:	66 41 89 44 1d 03    	mov    %ax,0x3(%r13,%rbx,1)
 106005e:	4a 8d 3c 2b          	lea    (%rbx,%r13,1),%rdi
 1060062:	48 83 c7 05          	add    $0x5,%rdi
 1060066:	48 03 75 a0          	add    -0x60(%rbp),%rsi
 106006a:	4c 89 f2             	mov    %r14,%rdx
 106006d:	c5 f8 77             	vzeroupper 
 1060070:	e8 6b 44 07 00       	call   10d44e0 <compiler_rt.memcpy.memcpyFast>
 1060075:	45 31 e4             	xor    %r12d,%r12d
 1060078:	4c 01 f3             	add    %r14,%rbx
 106007b:	48 83 c3 05          	add    $0x5,%rbx
 106007f:	4c 89 fe             	mov    %r15,%rsi
 1060082:	4c 3b 7d c0          	cmp    -0x40(%rbp),%r15
 1060086:	72 a0                	jb     1060028 <deflate64.encoder.encodeAlloc+0x5b8>
 1060088:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 106008c:	4c 8b 7d b0          	mov    -0x50(%rbp),%r15
 1060090:	e9 13 ff ff ff       	jmp    105ffa8 <deflate64.encoder.encodeAlloc+0x538>
