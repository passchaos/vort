0000000001282c90 <br.encodePlannedStreamWithOptionsAlloc>:
 1283a5d:	48 8d bd 60 fd ff ff 	lea    -0x2a0(%rbp),%rdi
 1283a64:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1283a68:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 1283a6c:	4c 89 e9             	mov    %r13,%rcx
 1283a6f:	4d 89 f8             	mov    %r15,%r8
 1283a72:	e8 79 5e 00 00       	call   12898f0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589>
 1283a77:	48 8b 85 70 fd ff ff 	mov    -0x290(%rbp),%rax
 1283a7e:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1283a82:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1283a86:	c5 f8 10 85 60 fd ff 	vmovups -0x2a0(%rbp),%xmm0
 1283a8d:	ff 
 1283a8e:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1283a92:	e9 21 fd ff ff       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>

00000000012898f0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589>:
 1289cd7:	4c 8d 85 20 fb ff ff 	lea    -0x4e0(%rbp),%r8
 1289cde:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289ce2:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289ce9:	4c 89 e1             	mov    %r12,%rcx
 1289cec:	c5 f8 77             	vzeroupper 
 1289cef:	e8 fc fb ff ff       	call   12898f0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589>
 1289cf4:	0f b7 85 d8 fd ff ff 	movzwl -0x228(%rbp),%eax
 1289cfb:	66 85 c0             	test   %ax,%ax
 1289cfe:	0f 85 05 01 00 00    	jne    1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289d04:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 1289d0b:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 1289d0f:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 1289d16:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
