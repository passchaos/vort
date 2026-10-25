0000000001147040 <quality_stage_profile.profilePass>:
 11473a2:	48 8d b5 70 fe ff ff 	lea    -0x190(%rbp),%rsi
 11473a9:	48 8d 95 40 fe ff ff 	lea    -0x1c0(%rbp),%rdx
 11473b0:	41 b9 38 14 01 01    	mov    $0x1011438,%r9d
 11473b6:	4d 89 f0             	mov    %r14,%r8
 11473b9:	c5 f8 77             	vzeroupper 
 11473bc:	e8 1f ca 06 00       	call   11b3de0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584>
 11473c1:	44 0f b7 b5 e8 fe ff 	movzwl -0x118(%rbp),%r14d
 11473c8:	ff 
 11473c9:	41 83 fe 1a          	cmp    $0x1a,%r14d
 11473cd:	74 48                	je     1147417 <quality_stage_profile.profilePass+0x3d7>
 11473cf:	45 85 f6             	test   %r14d,%r14d
 11473d2:	0f 85 c2 00 00 00    	jne    114749a <quality_stage_profile.profilePass+0x45a>
 11473d8:	48 8b b5 d8 fe ff ff 	mov    -0x128(%rbp),%rsi

00000000011b3de0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584>:
 11b428d:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11b4291:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 11b4295:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b4299:	4d 89 f8             	mov    %r15,%r8
 11b429c:	c5 f8 77             	vzeroupper 
 11b429f:	e8 3c fb ff ff       	call   11b3de0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584>
 11b42a4:	44 0f b7 b5 48 fc ff 	movzwl -0x3b8(%rbp),%r14d
 11b42ab:	ff 
 11b42ac:	4d 85 f6             	test   %r14,%r14
 11b42af:	0f 85 5c 17 00 00    	jne    11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b42b5:	48 8b 8d 38 fc ff ff 	mov    -0x3c8(%rbp),%rcx
 11b42bc:	48 8b 95 40 fc ff ff 	mov    -0x3c0(%rbp),%rdx
 11b42c3:	48 89 95 30 ff ff ff 	mov    %rdx,-0xd0(%rbp)

0000000001299760 <br.encodePlannedStreamWithOptionsAlloc>:
 1299998:	4c 89 f6             	mov    %r14,%rsi
 129999b:	48 8d 45 88          	lea    -0x78(%rbp),%rax
 129999f:	41 b8 38 14 01 01    	mov    $0x1011438,%r8d
 12999a5:	48 89 fb             	mov    %rdi,%rbx
 12999a8:	48 89 c7             	mov    %rax,%rdi
 12999ab:	e8 70 0e 00 00       	call   129a820 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831>
 12999b0:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 12999b4:	48 89 43 10          	mov    %rax,0x10(%rbx)
 12999b8:	c5 f8 10 45 88       	vmovups -0x78(%rbp),%xmm0
 12999bd:	c5 f8 11 03          	vmovups %xmm0,(%rbx)
 12999c1:	e9 d1 fd ff ff       	jmp    1299797 <br.encodePlannedStreamWithOptionsAlloc+0x37>
 12999c6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 12999cd:	00 00 00 

000000000129a820 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831>:
 129ac1b:	4c 8d 85 40 fb ff ff 	lea    -0x4c0(%rbp),%r8
 129ac22:	4c 89 e6             	mov    %r12,%rsi
 129ac25:	4c 89 ea             	mov    %r13,%rdx
 129ac28:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129ac2c:	c5 f8 77             	vzeroupper 
 129ac2f:	e8 ec fb ff ff       	call   129a820 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831>
 129ac34:	0f b7 85 c8 fd ff ff 	movzwl -0x238(%rbp),%eax
 129ac3b:	66 85 c0             	test   %ax,%ax
 129ac3e:	0f 85 29 01 00 00    	jne    129ad6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831+0x54d>
 129ac44:	48 8b 85 b8 fd ff ff 	mov    -0x248(%rbp),%rax
 129ac4b:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 129ac4f:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 129ac56:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
