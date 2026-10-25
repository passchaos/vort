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

 105fc19:	48 8d b5 30 ff ff ff 	lea    -0xd0(%rbp),%rsi
 105fc20:	4d 89 f1             	mov    %r14,%r9
 105fc23:	68 80 00 00 00       	push   $0x80
 105fc28:	68 80 00 00 00       	push   $0x80
 105fc2d:	c5 f8 77             	vzeroupper 
 105fc30:	e8 0b 1f 03 00       	call   1091b40 <deflate64.stream_blocks.fixedPlan>
 105fc35:	48 83 c4 10          	add    $0x10,%rsp
 105fc39:	4c 03 bd 78 ff ff ff 	add    -0x88(%rbp),%r15
 105fc40:	49 83 d4 00          	adc    $0x0,%r12

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
