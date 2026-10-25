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
