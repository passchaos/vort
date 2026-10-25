 1213706:	48 8d 8d c0 f1 ff ff 	lea    -0xe40(%rbp),%rcx
 121370d:	0f 1f 00             	nopl   (%rax)
 1213710:	c4 e2 93 f7 31       	shrx   %r13,(%rcx),%rsi
 1213715:	40 0f b6 f6          	movzbl %sil,%esi
 1213719:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213720:	ff 
 1213721:	c4 e2 93 f7 71 08    	shrx   %r13,0x8(%rcx),%rsi
 1213727:	40 0f b6 f6          	movzbl %sil,%esi
 121372b:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213732:	ff 

 1213789:	48 8d bd c0 f9 ff ff 	lea    -0x640(%rbp),%rdi
 1213790:	48 8d b5 c0 fd ff ff 	lea    -0x240(%rbp),%rsi
 1213797:	ba 00 02 00 00       	mov    $0x200,%edx
 121379c:	c5 f8 77             	vzeroupper 
 121379f:	e8 8c 56 08 00       	call   1298e30 <compiler_rt.memcpy.memcpyFast>
 12137a4:	31 c0                	xor    %eax,%eax
 12137a6:	31 c9                	xor    %ecx,%ecx
 12137a8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 12137af:	00 
 12137b0:	66 89 8c 45 c0 fb ff 	mov    %cx,-0x440(%rbp,%rax,2)
 12137b7:	ff 
 12137b8:	66 03 8c 45 c0 f9 ff 	add    -0x640(%rbp,%rax,2),%cx
 12137bf:	ff 
 12137c0:	66 89 8c 45 c2 fb ff 	mov    %cx,-0x43e(%rbp,%rax,2)
 12137c7:	ff 
 12137c8:	66 03 8c 45 c2 f9 ff 	add    -0x63e(%rbp,%rax,2),%cx
 12137cf:	ff 

 121384a:	44 89 da             	mov    %r11d,%edx
 121384d:	81 e2 fc 01 00 00    	and    $0x1fc,%edx
 1213853:	48 8d 8d c0 f1 ff ff 	lea    -0xe40(%rbp),%rcx
 121385a:	4d 89 e1             	mov    %r12,%r9
 121385d:	0f 1f 00             	nopl   (%rax)
 1213860:	48 8b 31             	mov    (%rcx),%rsi
 1213863:	c4 e2 93 f7 fe       	shrx   %r13,%rsi,%rdi
 1213868:	40 0f b6 ff          	movzbl %dil,%edi
 121386c:	44 0f b7 84 7d c0 fb 	movzwl -0x440(%rbp,%rdi,2),%r8d
 1213873:	ff ff 
 1213875:	4a 89 b4 c5 c0 e9 ff 	mov    %rsi,-0x1640(%rbp,%r8,8)
 121387c:	ff 
 121387d:	41 ff c0             	inc    %r8d
 1213880:	66 44 89 84 7d c0 fb 	mov    %r8w,-0x440(%rbp,%rdi,2)
 1213887:	ff ff 

 121421a:	45 84 e4             	test   %r12b,%r12b
 121421d:	74 1f                	je     121423e <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x105e>
 121421f:	42 8d 14 dd 00 00 00 	lea    0x0(,%r11,8),%edx
 1214226:	00 
 1214227:	48 8d bd c0 f1 ff ff 	lea    -0xe40(%rbp),%rdi
 121422e:	48 8d b5 c0 e9 ff ff 	lea    -0x1640(%rbp),%rsi
 1214235:	e8 f6 4b 08 00       	call   1298e30 <compiler_rt.memcpy.memcpyFast>
 121423a:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11

 1214250:	0f b6 b4 8d c0 f1 ff 	movzbl -0xe40(%rbp,%rcx,4),%esi
 1214257:	ff 
 1214258:	66 89 74 0b 08       	mov    %si,0x8(%rbx,%rcx,1)
 121425d:	0f b6 b4 8d c8 f1 ff 	movzbl -0xe38(%rbp,%rcx,4),%esi
 1214264:	ff 
 1214265:	66 89 74 0b 0a       	mov    %si,0xa(%rbx,%rcx,1)
 121426a:	0f b6 b4 8d d0 f1 ff 	movzbl -0xe30(%rbp,%rcx,4),%esi
 1214271:	ff 
 1214272:	66 89 74 0b 0c       	mov    %si,0xc(%rbx,%rcx,1)

 12142e6:	4c 89 1b             	mov    %r11,(%rbx)
 12142e9:	31 c0                	xor    %eax,%eax
 12142eb:	48 81 c4 18 16 00 00 	add    $0x1618,%rsp
 12142f2:	5b                   	pop    %rbx
 12142f3:	41 5c                	pop    %r12
 12142f5:	41 5d                	pop    %r13
 12142f7:	41 5e                	pop    %r14
 12142f9:	41 5f                	pop    %r15
 12142fb:	5d                   	pop    %rbp
 12142fc:	c3                   	ret    
