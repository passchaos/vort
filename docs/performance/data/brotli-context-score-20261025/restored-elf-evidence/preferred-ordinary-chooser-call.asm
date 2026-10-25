 1210573:	48 83 ec 08          	sub    $0x8,%rsp
 1210577:	48 8d bc 24 98 0f 00 	lea    0xf98(%rsp),%rdi
 121057e:	00 
 121057f:	48 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%rcx
 1210586:	00 
 1210587:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 121058e:	00 
 121058f:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1210596:	00 
 1210597:	ff b4 24 d8 00 00 00 	push   0xd8(%rsp)
 121059e:	c5 f8 77             	vzeroupper 
 12105a1:	e8 aa e8 ff ff       	call   120ee50 <br.encoder.literal_context_split.chooseProposals>
 12105a6:	48 83 c4 10          	add    $0x10,%rsp
 12105aa:	44 0f b7 b4 24 98 10 	movzwl 0x1098(%rsp),%r14d
 12105b1:	00 00 
 12105b3:	66 45 85 f6          	test   %r14w,%r14w
 12105b7:	0f 85 0d 11 00 00    	jne    12116ca <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18ba>
 12105bd:	4c 8d a4 24 e0 0e 00 	lea    0xee0(%rsp),%r12
 12105c4:	00 
 12105c5:	4c 8d bc 24 38 0f 00 	lea    0xf38(%rsp),%r15
