 115ce08:	ba 00 04 00 00       	mov    $0x400,%edx
 115ce0d:	48 8b bc 24 08 01 00 	mov    0x108(%rsp),%rdi
 115ce14:	00 
 115ce15:	48 8b b4 24 b8 00 00 	mov    0xb8(%rsp),%rsi
 115ce1c:	00 
 115ce1d:	e8 7e 15 04 00       	call   119e3a0 <compiler_rt.memcpy.memcpyFast>
 115ce22:	4c 8b 9c 24 30 01 00 	mov    0x130(%rsp),%r11
 115ce29:	00 
 115ce2a:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115ce2f:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115ce34:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115ce3b:	79 37 9e 
 115ce3e:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115ce43:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115ce48:	44 89 b4 24 b8 22 00 	mov    %r14d,0x22b8(%rsp)
 115ce4f:	00 
 115ce50:	c6 84 24 c0 22 00 00 	movb   $0x1,0x22c0(%rsp)
 115ce57:	01 
 115ce58:	48 c7 84 24 c8 22 00 	movq   $0x0,0x22c8(%rsp)
 115ce5f:	00 00 00 00 00 
 115ce64:	48 8b b4 24 00 01 00 	mov    0x100(%rsp),%rsi
 115ce6b:	00 
