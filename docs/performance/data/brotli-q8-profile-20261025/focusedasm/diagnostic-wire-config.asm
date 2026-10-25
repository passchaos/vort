 122f0be:	0f b6 7d c8          	movzbl -0x38(%rbp),%edi
 122f0c2:	44 0f b6 45 9f       	movzbl -0x61(%rbp),%r8d
 122f0c7:	44 0f b6 4d be       	movzbl -0x42(%rbp),%r9d
 122f0cc:	44 0f b6 55 a0       	movzbl -0x60(%rbp),%r10d
 122f0d1:	44 0f b6 5d c0       	movzbl -0x40(%rbp),%r11d
 122f0d6:	0f b6 5d a1          	movzbl -0x5f(%rbp),%ebx
 122f0da:	44 0f b6 7d c4       	movzbl -0x3c(%rbp),%r15d
 122f0df:	44 0f b6 65 a2       	movzbl -0x5e(%rbp),%r12d
 122f0e4:	44 0f b6 6d c2       	movzbl -0x3e(%rbp),%r13d
 122f0e9:	0f b6 45 a3          	movzbl -0x5d(%rbp),%eax
 122f0ed:	0f b6 4d d0          	movzbl -0x30(%rbp),%ecx
 122f0f1:	48 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%rsi
 122f0f8:	48 89 32             	mov    %rsi,(%rdx)
 122f0fb:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 122f0ff:	48 89 72 08          	mov    %rsi,0x8(%rdx)
 122f103:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 122f10a:	48 89 72 10          	mov    %rsi,0x10(%rdx)
 122f10e:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 122f112:	48 89 72 18          	mov    %rsi,0x18(%rdx)
 122f116:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 122f11d:	48 89 72 20          	mov    %rsi,0x20(%rdx)
 122f121:	40 88 7a 28          	mov    %dil,0x28(%rdx)
 122f125:	44 88 42 29          	mov    %r8b,0x29(%rdx)
 122f129:	44 88 4a 2a          	mov    %r9b,0x2a(%rdx)
 122f12d:	0f b6 75 a5          	movzbl -0x5b(%rbp),%esi
 122f131:	40 80 e6 03          	and    $0x3,%sil
 122f135:	40 88 72 2b          	mov    %sil,0x2b(%rdx)
 122f139:	0f b6 75 a4          	movzbl -0x5c(%rbp),%esi
 122f13d:	40 80 e6 0f          	and    $0xf,%sil
 122f141:	40 88 72 2c          	mov    %sil,0x2c(%rdx)
 122f145:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 122f14c:	40 88 72 2d          	mov    %sil,0x2d(%rdx)
 122f150:	48 8b b5 50 ff ff ff 	mov    -0xb0(%rbp),%rsi
 122f157:	40 88 72 2e          	mov    %sil,0x2e(%rdx)
 122f15b:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 122f162:	66 89 72 2f          	mov    %si,0x2f(%rdx)
 122f166:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 122f16d:	ff 
 122f16e:	c5 fc 10 8d 10 fe ff 	vmovups -0x1f0(%rbp),%ymm1
 122f175:	ff 
 122f176:	c5 fc 11 42 31       	vmovups %ymm0,0x31(%rdx)
 122f17b:	c5 fc 11 4a 51       	vmovups %ymm1,0x51(%rdx)
 122f180:	44 88 52 71          	mov    %r10b,0x71(%rdx)
 122f184:	44 88 5a 72          	mov    %r11b,0x72(%rdx)
 122f188:	88 5a 73             	mov    %bl,0x73(%rdx)
 122f18b:	44 88 7a 74          	mov    %r15b,0x74(%rdx)
 122f18f:	44 88 62 75          	mov    %r12b,0x75(%rdx)
 122f193:	44 88 6a 76          	mov    %r13b,0x76(%rdx)
 122f197:	88 42 77             	mov    %al,0x77(%rdx)
 122f19a:	88 4a 78             	mov    %cl,0x78(%rdx)
