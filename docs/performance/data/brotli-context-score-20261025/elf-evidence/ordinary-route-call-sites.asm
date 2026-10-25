00000000011ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>:
 11ea42b:	48 8d bd 88 f3 ff ff 	lea    -0xc78(%rbp),%rdi
 11ea432:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 11ea438:	4c 89 e6             	mov    %r12,%rsi
 11ea43b:	4c 89 e9             	mov    %r13,%rcx
 11ea43e:	4d 89 f8             	mov    %r15,%r8
 11ea441:	ff 75 18             	push   0x18(%rbp)
 11ea444:	ff 75 10             	push   0x10(%rbp)
 11ea447:	e8 74 59 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea44c:	48 83 c4 10          	add    $0x10,%rsp
 11ea450:	0f b7 85 e8 f4 ff ff 	movzwl -0xb18(%rbp),%eax
 11ea457:	66 85 c0             	test   %ax,%ax
 11ea45a:	0f 85 03 08 00 00    	jne    11eac63 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x893>
 11ea460:	48 8d bd 60 fa ff ff 	lea    -0x5a0(%rbp),%rdi

00000000011ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>:
 11ea4f4:	4c 89 e6             	mov    %r12,%rsi
 11ea4f7:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea4fb:	4c 89 e9             	mov    %r13,%rcx
 11ea4fe:	4d 89 f0             	mov    %r14,%r8
 11ea501:	4d 89 f9             	mov    %r15,%r9
 11ea504:	ff 75 18             	push   0x18(%rbp)
 11ea507:	ff 75 10             	push   0x10(%rbp)
 11ea50a:	e8 b1 58 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea50f:	48 83 c4 10          	add    $0x10,%rsp
 11ea513:	0f b7 9d 80 f3 ff ff 	movzwl -0xc80(%rbp),%ebx
 11ea51a:	66 85 db             	test   %bx,%bx
 11ea51d:	0f 85 a1 07 00 00    	jne    11eacc4 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8f4>
 11ea523:	48 8d 9d f0 f4 ff ff 	lea    -0xb10(%rbp),%rbx

00000000011ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>:
 11ea5f3:	4c 89 e6             	mov    %r12,%rsi
 11ea5f6:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea5fa:	4c 89 e9             	mov    %r13,%rcx
 11ea5fd:	4d 89 f8             	mov    %r15,%r8
 11ea600:	4d 89 f1             	mov    %r14,%r9
 11ea603:	ff 75 18             	push   0x18(%rbp)
 11ea606:	ff 75 10             	push   0x10(%rbp)
 11ea609:	e8 b2 57 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea60e:	48 83 c4 10          	add    $0x10,%rsp
 11ea612:	0f b7 85 88 fe ff ff 	movzwl -0x178(%rbp),%eax
 11ea619:	66 85 c0             	test   %ax,%ax
 11ea61c:	0f 85 41 06 00 00    	jne    11eac63 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x893>
 11ea622:	48 8b 85 28 fd ff ff 	mov    -0x2d8(%rbp),%rax

00000000011ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>:
 11ea79a:	48 8d bd c0 fb ff ff 	lea    -0x440(%rbp),%rdi
 11ea7a1:	4c 89 e6             	mov    %r12,%rsi
 11ea7a4:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 11ea7a8:	4d 89 f0             	mov    %r14,%r8
 11ea7ab:	4d 89 e9             	mov    %r13,%r9
 11ea7ae:	ff 75 18             	push   0x18(%rbp)
 11ea7b1:	ff 75 10             	push   0x10(%rbp)
 11ea7b4:	e8 07 56 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea7b9:	48 83 c4 10          	add    $0x10,%rsp
 11ea7bd:	44 0f b7 a5 20 fd ff 	movzwl -0x2e0(%rbp),%r12d
 11ea7c4:	ff 
 11ea7c5:	66 45 85 e4          	test   %r12w,%r12w
 11ea7c9:	0f 85 a9 03 00 00    	jne    11eab78 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x7a8>

00000000011ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>:
 11ea985:	4c 89 e9             	mov    %r13,%rcx
 11ea988:	4d 89 f0             	mov    %r14,%r8
 11ea98b:	49 89 d9             	mov    %rbx,%r9
 11ea98e:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ea992:	50                   	push   %rax
 11ea993:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ea997:	50                   	push   %rax
 11ea998:	e8 23 54 02 00       	call   120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>
 11ea99d:	48 83 c4 10          	add    $0x10,%rsp
 11ea9a1:	0f b7 85 18 f2 ff ff 	movzwl -0xde8(%rbp),%eax
 11ea9a8:	66 85 c0             	test   %ax,%ax
 11ea9ab:	0f 85 e8 02 00 00    	jne    11eac99 <br.encodeLazyCommandPlanAllocRecorded__anon_43465+0x8c9>
 11ea9b1:	48 8d bd a0 f7 ff ff 	lea    -0x860(%rbp),%rdi

000000000120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>:
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

000000000123ebf0 <br.encoder.literal_context_split.choose>:
 123ebf1:	48 89 e5             	mov    %rsp,%rbp
 123ebf4:	53                   	push   %rbx
 123ebf5:	48 81 ec 18 01 00 00 	sub    $0x118,%rsp
 123ebfc:	48 89 fb             	mov    %rdi,%rbx
 123ebff:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123ec03:	48 89 04 24          	mov    %rax,(%rsp)
 123ec07:	48 8d bd e8 fe ff ff 	lea    -0x118(%rbp),%rdi
 123ec0e:	e8 ed 01 fd ff       	call   120ee00 <br.encoder.literal_context_split.chooseProposals>
 123ec13:	0f b7 45 f0          	movzwl -0x10(%rbp),%eax
 123ec17:	66 85 c0             	test   %ax,%ax
 123ec1a:	75 1d                	jne    123ec39 <br.encoder.literal_context_split.choose+0x49>
 123ec1c:	c5 fc 10 45 98       	vmovups -0x68(%rbp),%ymm0
 123ec21:	c5 fc 10 4d b8       	vmovups -0x48(%rbp),%ymm1

000000000123ec50 <br.encoder.literal_context_split.chooseSuffix>:
 123ec51:	48 89 e5             	mov    %rsp,%rbp
 123ec54:	53                   	push   %rbx
 123ec55:	48 81 ec 18 01 00 00 	sub    $0x118,%rsp
 123ec5c:	48 89 fb             	mov    %rdi,%rbx
 123ec5f:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123ec63:	48 89 04 24          	mov    %rax,(%rsp)
 123ec67:	48 8d bd e8 fe ff ff 	lea    -0x118(%rbp),%rdi
 123ec6e:	e8 8d 01 fd ff       	call   120ee00 <br.encoder.literal_context_split.chooseProposals>
 123ec73:	0f b7 45 f0          	movzwl -0x10(%rbp),%eax
 123ec77:	66 85 c0             	test   %ax,%ax
 123ec7a:	75 26                	jne    123eca2 <br.encoder.literal_context_split.chooseSuffix+0x52>
 123ec7c:	c5 fc 10 85 e8 fe ff 	vmovups -0x118(%rbp),%ymm0
 123ec83:	ff 

0000000001282df0 <br.encodePlannedStreamWithOptionsAlloc>:
 1283bb3:	80 7d 98 00          	cmpb   $0x0,-0x68(%rbp)
 1283bb7:	0f 84 99 02 00 00    	je     1283e56 <br.encodePlannedStreamWithOptionsAlloc+0x1066>
 1283bbd:	48 8d bd 60 fd ff ff 	lea    -0x2a0(%rbp),%rdi
 1283bc4:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1283bc8:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 1283bcc:	4c 89 e9             	mov    %r13,%rcx
 1283bcf:	4d 89 f8             	mov    %r15,%r8
 1283bd2:	e8 79 5e 00 00       	call   1289a50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629>
 1283bd7:	48 8b 85 70 fd ff ff 	mov    -0x290(%rbp),%rax
 1283bde:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1283be2:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1283be6:	c5 f8 10 85 60 fd ff 	vmovups -0x2a0(%rbp),%xmm0
 1283bed:	ff 

0000000001289a50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629>:
 1289e2a:	89 85 ac fb ff ff    	mov    %eax,-0x454(%rbp)
 1289e30:	48 8d bd c8 fd ff ff 	lea    -0x238(%rbp),%rdi
 1289e37:	4c 8d 85 20 fb ff ff 	lea    -0x4e0(%rbp),%r8
 1289e3e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289e42:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289e49:	4c 89 e1             	mov    %r12,%rcx
 1289e4c:	c5 f8 77             	vzeroupper 
 1289e4f:	e8 fc fb ff ff       	call   1289a50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629>
 1289e54:	0f b7 85 d8 fd ff ff 	movzwl -0x228(%rbp),%eax
 1289e5b:	66 85 c0             	test   %ax,%ax
 1289e5e:	0f 85 05 01 00 00    	jne    1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289e64:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 1289e6b:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
