0000000001282e10 <br.encodePlannedStreamWithOptionsAlloc>:
 1283bdd:	48 8d bd 60 fd ff ff 	lea    -0x2a0(%rbp),%rdi
 1283be4:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1283be8:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 1283bec:	4c 89 e9             	mov    %r13,%rcx
 1283bef:	4d 89 f8             	mov    %r15,%r8
 1283bf2:	e8 29 5f 00 00       	call   1289b20 <br.encodePlannedStreamQualityWithOptionsAlloc>
 1283bf7:	48 8b 85 70 fd ff ff 	mov    -0x290(%rbp),%rax
 1283bfe:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1283c02:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1283c06:	c5 f8 10 85 60 fd ff 	vmovups -0x2a0(%rbp),%xmm0
 1283c0d:	ff 
 1283c0e:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1283c12:	e9 21 fd ff ff       	jmp    1283938 <br.encodePlannedStreamWithOptionsAlloc+0xb28>

0000000001289b20 <br.encodePlannedStreamQualityWithOptionsAlloc>:
 1289f41:	4c 8d 85 d0 fa ff ff 	lea    -0x530(%rbp),%r8
 1289f48:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1289f4c:	4c 89 fa             	mov    %r15,%rdx
 1289f4f:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 1289f56:	c5 f8 77             	vzeroupper 
 1289f59:	e8 c2 fb ff ff       	call   1289b20 <br.encodePlannedStreamQualityWithOptionsAlloc>
 1289f5e:	0f b7 85 a8 fd ff ff 	movzwl -0x258(%rbp),%eax
 1289f65:	66 85 c0             	test   %ax,%ax
 1289f68:	0f 85 02 01 00 00    	jne    128a070 <br.encodePlannedStreamQualityWithOptionsAlloc+0x550>
 1289f6e:	48 8b 8d 98 fd ff ff 	mov    -0x268(%rbp),%rcx
 1289f75:	48 8b 85 a0 fd ff ff 	mov    -0x260(%rbp),%rax
 1289f7c:	48 89 4d c8          	mov    %rcx,-0x38(%rbp)
 1289f80:	48 89 45 80          	mov    %rax,-0x80(%rbp)
