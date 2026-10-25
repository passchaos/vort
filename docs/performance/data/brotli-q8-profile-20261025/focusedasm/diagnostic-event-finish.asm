 127717f:	48 89 fb             	mov    %rdi,%rbx
 1277182:	4c 8b 77 20          	mov    0x20(%rdi),%r14
 1277186:	4c 8b 3f             	mov    (%rdi),%r15
 1277189:	4c 8b 67 08          	mov    0x8(%rdi),%r12
 127718d:	48 8b 77 10          	mov    0x10(%rdi),%rsi
 1277191:	48 8b 47 18          	mov    0x18(%rdi),%rax
 1277195:	48 8d 7d d0          	lea    -0x30(%rbp),%rdi
 1277199:	ba 01 00 00 00       	mov    $0x1,%edx
 127719e:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 12771a4:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12771a8:	48 8b 4d d8          	mov    -0x28(%rbp),%rcx
 12771ac:	4c 29 f8             	sub    %r15,%rax
 12771af:	4c 19 e1             	sbb    %r12,%rcx
 12771b2:	48 63 d1             	movslq %ecx,%rdx
 12771b5:	48 85 d2             	test   %rdx,%rdx
 12771b8:	78 41                	js     12771fb <br.encoder.quality_profile.Scope.finish+0x8b>
 12771ba:	48 c1 e1 20          	shl    $0x20,%rcx
 12771be:	74 0f                	je     12771cf <br.encoder.quality_profile.Scope.finish+0x5f>
 12771c0:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12771c7:	00 
 12771c8:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 12771cf:	80 7b 48 00          	cmpb   $0x0,0x48(%rbx)
 12771d3:	74 36                	je     127720b <br.encoder.quality_profile.Scope.finish+0x9b>
 12771d5:	48 8b 4b 40          	mov    0x40(%rbx),%rcx
 12771d9:	48 c1 e1 04          	shl    $0x4,%rcx
 12771dd:	49 8b 94 0e d0 30 02 	mov    0x230d0(%r14,%rcx,1),%rdx
 12771e4:	00 
 12771e5:	49 ff 8e c8 32 02 00 	decq   0x232c8(%r14)
 12771ec:	48 39 c2             	cmp    %rax,%rdx
 12771ef:	76 1c                	jbe    127720d <br.encoder.quality_profile.Scope.finish+0x9d>
 12771f1:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12771f8:	00 
 12771f9:	eb 12                	jmp    127720d <br.encoder.quality_profile.Scope.finish+0x9d>
 12771fb:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277202:	00 
 1277203:	31 c0                	xor    %eax,%eax
 1277205:	80 7b 48 00          	cmpb   $0x0,0x48(%rbx)
 1277209:	75 ca                	jne    12771d5 <br.encoder.quality_profile.Scope.finish+0x65>
 127720b:	31 d2                	xor    %edx,%edx
 127720d:	31 c9                	xor    %ecx,%ecx
 127720f:	48 89 c6             	mov    %rax,%rsi
 1277212:	48 29 d6             	sub    %rdx,%rsi
 1277215:	48 0f 43 ce          	cmovae %rsi,%rcx
 1277219:	80 7b 38 00          	cmpb   $0x0,0x38(%rbx)
 127721d:	74 12                	je     1277231 <br.encoder.quality_profile.Scope.finish+0xc1>
 127721f:	48 69 53 30 18 01 00 	imul   $0x118,0x30(%rbx),%rdx
 1277226:	00 
 1277227:	49 89 44 16 38       	mov    %rax,0x38(%r14,%rdx,1)
 127722c:	49 89 4c 16 40       	mov    %rcx,0x40(%r14,%rdx,1)
 1277231:	49 8b 96 c8 32 02 00 	mov    0x232c8(%r14),%rdx
 1277238:	48 85 d2             	test   %rdx,%rdx
 127723b:	74 3a                	je     1277277 <br.encoder.quality_profile.Scope.finish+0x107>
 127723d:	48 c1 e2 04          	shl    $0x4,%rdx
 1277241:	49 8b b4 16 c0 30 02 	mov    0x230c0(%r14,%rdx,1),%rsi
 1277248:	00 
 1277249:	48 01 c6             	add    %rax,%rsi
 127724c:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277250:	73 33                	jae    1277285 <br.encoder.quality_profile.Scope.finish+0x115>
 1277252:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277259:	00 
 127725a:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 1277261:	49 89 b4 16 c0 30 02 	mov    %rsi,0x230c0(%r14,%rdx,1)
 1277268:	00 
 1277269:	0f b6 53 50          	movzbl 0x50(%rbx),%edx
 127726d:	83 e2 0f             	and    $0xf,%edx
 1277270:	ff 24 d5 60 0e 01 01 	jmp    *0x1010e60(,%rdx,8)
 1277277:	0f b6 53 50          	movzbl 0x50(%rbx),%edx
 127727b:	83 e2 0f             	and    $0xf,%edx
 127727e:	ff 24 d5 60 0e 01 01 	jmp    *0x1010e60(,%rdx,8)
 1277285:	49 89 b4 16 c0 30 02 	mov    %rsi,0x230c0(%r14,%rdx,1)
 127728c:	00 
 127728d:	0f b6 53 50          	movzbl 0x50(%rbx),%edx
 1277291:	83 e2 0f             	and    $0xf,%edx
 1277294:	ff 24 d5 60 0e 01 01 	jmp    *0x1010e60(,%rdx,8)
 127729b:	49 89 86 38 30 02 00 	mov    %rax,0x23038(%r14)
