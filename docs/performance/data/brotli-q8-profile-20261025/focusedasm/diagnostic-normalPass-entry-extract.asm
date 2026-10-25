 1146f21:	4d 89 cf             	mov    %r9,%r15
 1146f24:	4d 89 c4             	mov    %r8,%r12
 1146f27:	48 89 cb             	mov    %rcx,%rbx
 1146f2a:	49 89 d5             	mov    %rdx,%r13
 1146f2d:	49 89 f6             	mov    %rsi,%r14
 1146f30:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 1146f34:	48 8b 01             	mov    (%rcx),%rax
 1146f37:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 1146f3b:	48 8b 41 08          	mov    0x8(%rcx),%rax
 1146f3f:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 1146f43:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1146f47:	ba 01 00 00 00       	mov    $0x1,%edx
 1146f4c:	41 ff 95 c0 02 00 00 	call   *0x2c0(%r13)
 1146f53:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1146f57:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 1146f5b:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1146f5f:	48 89 de             	mov    %rbx,%rsi
 1146f62:	4c 89 e2             	mov    %r12,%rdx
 1146f65:	4c 89 f9             	mov    %r15,%rcx
 1146f68:	e8 f3 27 15 00       	call   1299760 <br.encodePlannedStreamWithOptionsAlloc>
 1146f6d:	0f b7 45 a0          	movzwl -0x60(%rbp),%eax
 1146f71:	66 85 c0             	test   %ax,%ax
 1146f74:	0f 85 b6 00 00 00    	jne    1147030 <quality_stage_profile.normalPass+0x120>
 1146f7a:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 1146f7e:	4c 8b 65 90          	mov    -0x70(%rbp),%r12
 1146f82:	4c 8b 7d 98          	mov    -0x68(%rbp),%r15
 1146f86:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1146f8a:	4c 89 f6             	mov    %r14,%rsi
 1146f8d:	ba 01 00 00 00       	mov    $0x1,%edx
 1146f92:	41 ff 95 c0 02 00 00 	call   *0x2c0(%r13)
 1146f99:	4c 8b 75 b0          	mov    -0x50(%rbp),%r14
 1146f9d:	4d 85 ff             	test   %r15,%r15
 1146fa0:	b8 01 00 00 00       	mov    $0x1,%eax
 1146fa5:	4c 89 e7             	mov    %r12,%rdi
 1146fa8:	48 0f 44 f8          	cmove  %rax,%rdi
 1146fac:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 1146fb0:	48 85 c9             	test   %rcx,%rcx
 1146fb3:	48 0f 44 d8          	cmove  %rax,%rbx
 1146fb7:	4c 89 fe             	mov    %r15,%rsi
 1146fba:	48 89 da             	mov    %rbx,%rdx
 1146fbd:	e8 1e f7 0b 00       	call   12066e0 <mem.eqlBytes>
 1146fc2:	a8 01                	test   $0x1,%al
