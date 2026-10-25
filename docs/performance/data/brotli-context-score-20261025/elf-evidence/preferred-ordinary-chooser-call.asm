 1210523:	48 83 ec 08          	sub    $0x8,%rsp
 1210527:	48 8d bc 24 98 0f 00 	lea    0xf98(%rsp),%rdi
 121052e:	00 
 121052f:	48 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%rcx
 1210536:	00 
 1210537:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 121053e:	00 
 121053f:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1210546:	00 
 1210547:	ff b4 24 d8 00 00 00 	push   0xd8(%rsp)
 121054e:	c5 f8 77             	vzeroupper 
 1210551:	e8 aa e8 ff ff       	call   120ee00 <br.encoder.literal_context_split.chooseProposals>
 1210556:	48 83 c4 10          	add    $0x10,%rsp
 121055a:	44 0f b7 b4 24 98 10 	movzwl 0x1098(%rsp),%r14d
 1210561:	00 00 
 1210563:	66 45 85 f6          	test   %r14w,%r14w
 1210567:	0f 85 0d 11 00 00    	jne    121167a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18ba>
