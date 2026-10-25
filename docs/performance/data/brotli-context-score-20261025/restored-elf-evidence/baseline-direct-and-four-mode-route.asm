 120f457:	66 89 85 2e fb ff ff 	mov    %ax,-0x4d2(%rbp)
 120f45e:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f465:	4c 8d bd 2e fb ff ff 	lea    -0x4d2(%rbp),%r15
 120f46c:	4c 89 f6             	mov    %r14,%rsi
 120f46f:	4c 89 fa             	mov    %r15,%rdx
 120f472:	e8 f9 d1 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120f477:	0f b7 9d 10 fe ff ff 	movzwl -0x1f0(%rbp),%ebx
 120f47e:	66 85 db             	test   %bx,%bx

 120f4e7:	4c 89 3c 24          	mov    %r15,(%rsp)
 120f4eb:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f4f2:	31 f6                	xor    %esi,%esi
 120f4f4:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 120f4f8:	4c 89 f1             	mov    %r14,%rcx
 120f4fb:	4c 89 4d 80          	mov    %r9,-0x80(%rbp)
 120f4ff:	c5 f8 77             	vzeroupper 
 120f502:	e8 79 d7 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>

 120f680:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f687:	be 01 00 00 00       	mov    $0x1,%esi
 120f68c:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 120f693:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120f69a:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 120f69e:	c5 f8 77             	vzeroupper 
 120f6a1:	e8 da d5 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>

 120f8cf:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f8d6:	be 02 00 00 00       	mov    $0x2,%esi
 120f8db:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 120f8e2:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120f8e9:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 120f8ed:	c5 f8 77             	vzeroupper 
 120f8f0:	e8 8b d3 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>

 120fad1:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120fad8:	be 03 00 00 00       	mov    $0x3,%esi
 120fadd:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 120fae4:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120faeb:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 120faef:	c5 f8 77             	vzeroupper 
 120faf2:	e8 89 d1 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>
