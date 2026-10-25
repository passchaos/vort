
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011eb020 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527>:
 11eb020:	55                   	push   %rbp
 11eb021:	48 89 e5             	mov    %rsp,%rbp
 11eb024:	41 57                	push   %r15
 11eb026:	41 56                	push   %r14
 11eb028:	41 55                	push   %r13
 11eb02a:	41 54                	push   %r12
 11eb02c:	53                   	push   %rbx
 11eb02d:	48 81 ec c8 40 00 00 	sub    $0x40c8,%rsp
 11eb034:	4d 89 ca             	mov    %r9,%r10
 11eb037:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 11eb03b:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 11eb03f:	48 8b 7d 20          	mov    0x20(%rbp),%rdi
 11eb043:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 11eb047:	c5 f8 10 46 10       	vmovups 0x10(%rsi),%xmm0
 11eb04c:	c5 f8 29 85 80 fd ff 	vmovaps %xmm0,-0x280(%rbp)
 11eb053:	ff 
 11eb054:	c5 fc 10 46 20       	vmovups 0x20(%rsi),%ymm0
 11eb059:	c5 fc 11 85 00 ea ff 	vmovups %ymm0,-0x1600(%rbp)
 11eb060:	ff 
 11eb061:	0f b6 46 40          	movzbl 0x40(%rsi),%eax
 11eb065:	88 45 8d             	mov    %al,-0x73(%rbp)
 11eb068:	0f b6 46 45          	movzbl 0x45(%rsi),%eax
 11eb06c:	88 45 8f             	mov    %al,-0x71(%rbp)
 11eb06f:	44 0f b6 4e 49       	movzbl 0x49(%rsi),%r9d
 11eb074:	0f b6 46 4a          	movzbl 0x4a(%rsi),%eax
 11eb078:	88 85 70 ff ff ff    	mov    %al,-0x90(%rbp)
 11eb07e:	0f b6 46 4b          	movzbl 0x4b(%rsi),%eax
 11eb082:	88 85 28 ff ff ff    	mov    %al,-0xd8(%rbp)
 11eb088:	0f b6 46 4c          	movzbl 0x4c(%rsi),%eax
 11eb08c:	88 45 c6             	mov    %al,-0x3a(%rbp)
 11eb08f:	0f b6 46 4d          	movzbl 0x4d(%rsi),%eax
 11eb093:	88 45 8c             	mov    %al,-0x74(%rbp)
 11eb096:	0f b6 46 4e          	movzbl 0x4e(%rsi),%eax
 11eb09a:	88 45 8e             	mov    %al,-0x72(%rbp)
 11eb09d:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11eb0a1:	48 89 85 78 fd ff ff 	mov    %rax,-0x288(%rbp)
 11eb0a8:	f6 46 48 01          	testb  $0x1,0x48(%rsi)
 11eb0ac:	0f b6 87 58 01 00 00 	movzbl 0x158(%rdi),%eax
 11eb0b3:	88 45 8b             	mov    %al,-0x75(%rbp)
 11eb0b6:	4c 89 55 80          	mov    %r10,-0x80(%rbp)
 11eb0ba:	4c 89 45 90          	mov    %r8,-0x70(%rbp)
 11eb0be:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 11eb0c2:	48 89 55 d0          	mov    %rdx,-0x30(%rbp)
 11eb0c6:	74 79                	je     11eb141 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x121>
 11eb0c8:	4c 8d a5 98 c1 ff ff 	lea    -0x3e68(%rbp),%r12
 11eb0cf:	4c 8d b5 28 c1 ff ff 	lea    -0x3ed8(%rbp),%r14
 11eb0d6:	4c 8d bd b8 c0 ff ff 	lea    -0x3f48(%rbp),%r15
 11eb0dd:	4c 8d ad 48 c0 ff ff 	lea    -0x3fb8(%rbp),%r13
 11eb0e4:	0f b7 87 5b 01 00 00 	movzwl 0x15b(%rdi),%eax
 11eb0eb:	66 89 85 2e fe ff ff 	mov    %ax,-0x1d2(%rbp)
 11eb0f2:	48 8d 9d 68 bf ff ff 	lea    -0x4098(%rbp),%rbx
 11eb0f9:	44 88 8d 78 ff ff ff 	mov    %r9b,-0x88(%rbp)
 11eb100:	4c 8d 8d 2e fe ff ff 	lea    -0x1d2(%rbp),%r9
 11eb107:	48 89 df             	mov    %rbx,%rdi
 11eb10a:	48 89 d6             	mov    %rdx,%rsi
 11eb10d:	48 89 ca             	mov    %rcx,%rdx
 11eb110:	4c 89 c1             	mov    %r8,%rcx
 11eb113:	4d 89 d0             	mov    %r10,%r8
 11eb116:	c5 f8 77             	vzeroupper 
 11eb119:	e8 72 dd 01 00       	call   1208e90 <br.encoder.literal_block_split.chooseProposals>
 11eb11e:	4c 8d 95 08 c2 ff ff 	lea    -0x3df8(%rbp),%r10
 11eb125:	4c 8d 85 d8 bf ff ff 	lea    -0x4028(%rbp),%r8
 11eb12c:	48 8d bd d1 bf ff ff 	lea    -0x402f(%rbp),%rdi
 11eb133:	44 0f b6 8d 78 ff ff 	movzbl -0x88(%rbp),%r9d
 11eb13a:	ff 
 11eb13b:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eb13f:	eb 38                	jmp    11eb179 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x159>
 11eb141:	48 8d 1d 08 f9 e4 ff 	lea    -0x1b06f8(%rip),%rbx        # 103aa50 <__anon_43566>
 11eb148:	4c 8d 05 71 f9 e4 ff 	lea    -0x1b068f(%rip),%r8        # 103aac0 <__anon_43566+0x70>
 11eb14f:	48 8d 3d 63 f9 e4 ff 	lea    -0x1b069d(%rip),%rdi        # 103aab9 <__anon_43566+0x69>
 11eb156:	4c 8d 15 93 fb e4 ff 	lea    -0x1b046d(%rip),%r10        # 103acf0 <__anon_43566+0x2a0>
 11eb15d:	4c 8d 25 1c fb e4 ff 	lea    -0x1b04e4(%rip),%r12        # 103ac80 <__anon_43566+0x230>
 11eb164:	4c 8d 35 a5 fa e4 ff 	lea    -0x1b055b(%rip),%r14        # 103ac10 <__anon_43566+0x1c0>
 11eb16b:	4c 8d 3d 2e fa e4 ff 	lea    -0x1b05d2(%rip),%r15        # 103aba0 <__anon_43566+0x150>
 11eb172:	4c 8d 2d b7 f9 e4 ff 	lea    -0x1b0649(%rip),%r13        # 103ab30 <__anon_43566+0xe0>
 11eb179:	48 8b 43 60          	mov    0x60(%rbx),%rax
 11eb17d:	48 89 85 60 fa ff ff 	mov    %rax,-0x5a0(%rbp)
 11eb184:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 11eb188:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 11eb18d:	c5 fc 10 53 40       	vmovups 0x40(%rbx),%ymm2
 11eb192:	c5 fc 11 95 40 fa ff 	vmovups %ymm2,-0x5c0(%rbp)
 11eb199:	ff 
 11eb19a:	c5 fc 11 8d 20 fa ff 	vmovups %ymm1,-0x5e0(%rbp)
 11eb1a1:	ff 
 11eb1a2:	c5 fc 11 85 00 fa ff 	vmovups %ymm0,-0x600(%rbp)
 11eb1a9:	ff 
 11eb1aa:	0f b6 4b 68          	movzbl 0x68(%rbx),%ecx
 11eb1ae:	0f b6 b3 d8 00 00 00 	movzbl 0xd8(%rbx),%esi
 11eb1b5:	49 8b 45 60          	mov    0x60(%r13),%rax
 11eb1b9:	48 89 85 d0 fa ff ff 	mov    %rax,-0x530(%rbp)
 11eb1c0:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 11eb1c6:	c4 c1 7c 10 4d 40    	vmovups 0x40(%r13),%ymm1
 11eb1cc:	c5 fc 11 8d b0 fa ff 	vmovups %ymm1,-0x550(%rbp)
 11eb1d3:	ff 
 11eb1d4:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 11eb1da:	c5 fc 11 8d 90 fa ff 	vmovups %ymm1,-0x570(%rbp)
 11eb1e1:	ff 
 11eb1e2:	c5 fc 11 85 70 fa ff 	vmovups %ymm0,-0x590(%rbp)
 11eb1e9:	ff 
 11eb1ea:	0f b6 83 48 01 00 00 	movzbl 0x148(%rbx),%eax
 11eb1f1:	88 85 22 ff ff ff    	mov    %al,-0xde(%rbp)
 11eb1f7:	c4 c1 7c 10 47 20    	vmovups 0x20(%r15),%ymm0
 11eb1fd:	c4 c1 7c 10 4f 40    	vmovups 0x40(%r15),%ymm1
 11eb203:	c5 fc 11 85 00 fb ff 	vmovups %ymm0,-0x500(%rbp)
 11eb20a:	ff 
 11eb20b:	c5 fc 11 8d 20 fb ff 	vmovups %ymm1,-0x4e0(%rbp)
 11eb212:	ff 
 11eb213:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 11eb218:	49 8b 47 60          	mov    0x60(%r15),%rax
 11eb21c:	48 89 85 40 fb ff ff 	mov    %rax,-0x4c0(%rbp)
 11eb223:	c5 fc 11 85 e0 fa ff 	vmovups %ymm0,-0x520(%rbp)
 11eb22a:	ff 
 11eb22b:	0f b6 83 b8 01 00 00 	movzbl 0x1b8(%rbx),%eax
 11eb232:	88 85 23 ff ff ff    	mov    %al,-0xdd(%rbp)
 11eb238:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 11eb23d:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 11eb243:	c5 fc 11 85 50 fb ff 	vmovups %ymm0,-0x4b0(%rbp)
 11eb24a:	ff 
 11eb24b:	c5 fc 11 8d 70 fb ff 	vmovups %ymm1,-0x490(%rbp)
 11eb252:	ff 
 11eb253:	c4 c1 7c 10 46 40    	vmovups 0x40(%r14),%ymm0
 11eb259:	c5 fc 11 85 90 fb ff 	vmovups %ymm0,-0x470(%rbp)
 11eb260:	ff 
 11eb261:	49 8b 46 60          	mov    0x60(%r14),%rax
 11eb265:	48 89 85 b0 fb ff ff 	mov    %rax,-0x450(%rbp)
 11eb26c:	0f b6 83 28 02 00 00 	movzbl 0x228(%rbx),%eax
 11eb273:	88 85 24 ff ff ff    	mov    %al,-0xdc(%rbp)
 11eb279:	49 8b 44 24 60       	mov    0x60(%r12),%rax
 11eb27e:	48 89 85 20 fc ff ff 	mov    %rax,-0x3e0(%rbp)
 11eb285:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 11eb28b:	c4 c1 7c 10 4c 24 40 	vmovups 0x40(%r12),%ymm1
 11eb292:	c5 fc 11 8d 00 fc ff 	vmovups %ymm1,-0x400(%rbp)
 11eb299:	ff 
 11eb29a:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 11eb2a1:	c5 fc 11 8d e0 fb ff 	vmovups %ymm1,-0x420(%rbp)
 11eb2a8:	ff 
 11eb2a9:	c5 fc 11 85 c0 fb ff 	vmovups %ymm0,-0x440(%rbp)
 11eb2b0:	ff 
 11eb2b1:	0f b6 83 98 02 00 00 	movzbl 0x298(%rbx),%eax
 11eb2b8:	88 85 25 ff ff ff    	mov    %al,-0xdb(%rbp)
 11eb2be:	49 8b 42 60          	mov    0x60(%r10),%rax
 11eb2c2:	48 89 85 90 fc ff ff 	mov    %rax,-0x370(%rbp)
 11eb2c9:	c4 c1 7c 10 02       	vmovups (%r10),%ymm0
 11eb2ce:	c4 c1 7c 10 4a 40    	vmovups 0x40(%r10),%ymm1
 11eb2d4:	c5 fc 11 8d 70 fc ff 	vmovups %ymm1,-0x390(%rbp)
 11eb2db:	ff 
 11eb2dc:	c4 c1 7c 10 4a 20    	vmovups 0x20(%r10),%ymm1
 11eb2e2:	c5 fc 11 8d 50 fc ff 	vmovups %ymm1,-0x3b0(%rbp)
 11eb2e9:	ff 
 11eb2ea:	c5 fc 11 85 30 fc ff 	vmovups %ymm0,-0x3d0(%rbp)
 11eb2f1:	ff 
 11eb2f2:	40 88 b5 21 ff ff ff 	mov    %sil,-0xdf(%rbp)
 11eb2f9:	40 84 f6             	test   %sil,%sil
 11eb2fc:	88 4d c7             	mov    %cl,-0x39(%rbp)
 11eb2ff:	74 44                	je     11eb345 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x325>
 11eb301:	49 8b 40 60          	mov    0x60(%r8),%rax
 11eb305:	48 89 85 50 dd ff ff 	mov    %rax,-0x22b0(%rbp)
 11eb30c:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 11eb311:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 11eb317:	c4 c1 7c 10 50 40    	vmovups 0x40(%r8),%ymm2
 11eb31d:	c5 fc 11 95 30 dd ff 	vmovups %ymm2,-0x22d0(%rbp)
 11eb324:	ff 
 11eb325:	c5 fc 11 8d 10 dd ff 	vmovups %ymm1,-0x22f0(%rbp)
 11eb32c:	ff 
 11eb32d:	c5 fc 11 85 f0 dc ff 	vmovups %ymm0,-0x2310(%rbp)
 11eb334:	ff 
 11eb335:	c6 85 58 dd ff ff 01 	movb   $0x1,-0x22a8(%rbp)
 11eb33c:	48 8d 85 f0 dc ff ff 	lea    -0x2310(%rbp),%rax
 11eb343:	eb 4f                	jmp    11eb394 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x374>
 11eb345:	48 8b 43 60          	mov    0x60(%rbx),%rax
 11eb349:	48 89 85 f0 ea ff ff 	mov    %rax,-0x1510(%rbp)
 11eb350:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 11eb354:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 11eb359:	c5 fc 10 53 40       	vmovups 0x40(%rbx),%ymm2
 11eb35e:	c5 fc 11 95 d0 ea ff 	vmovups %ymm2,-0x1530(%rbp)
 11eb365:	ff 
 11eb366:	c5 fc 11 8d b0 ea ff 	vmovups %ymm1,-0x1550(%rbp)
 11eb36d:	ff 
 11eb36e:	c5 fc 11 85 90 ea ff 	vmovups %ymm0,-0x1570(%rbp)
 11eb375:	ff 
 11eb376:	88 8d f8 ea ff ff    	mov    %cl,-0x1508(%rbp)
 11eb37c:	8b 07                	mov    (%rdi),%eax
 11eb37e:	8b 4f 03             	mov    0x3(%rdi),%ecx
 11eb381:	89 85 f9 ea ff ff    	mov    %eax,-0x1507(%rbp)
 11eb387:	89 8d fc ea ff ff    	mov    %ecx,-0x1504(%rbp)
 11eb38d:	48 8d 85 90 ea ff ff 	lea    -0x1570(%rbp),%rax
 11eb394:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 11eb39b:	4c 8b 6d c8          	mov    -0x38(%rbp),%r13
 11eb39f:	4c 8b 75 80          	mov    -0x80(%rbp),%r14
 11eb3a3:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 11eb3a7:	4c 8b 65 98          	mov    -0x68(%rbp),%r12
 11eb3ab:	0f b6 9b 08 03 00 00 	movzbl 0x308(%rbx),%ebx
 11eb3b2:	41 f6 c1 01          	test   $0x1,%r9b
 11eb3b6:	74 58                	je     11eb410 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3f0>
 11eb3b8:	48 8d bd f0 e3 ff ff 	lea    -0x1c10(%rbp),%rdi
 11eb3bf:	4c 89 ee             	mov    %r13,%rsi
 11eb3c2:	4c 89 e1             	mov    %r12,%rcx
 11eb3c5:	4d 89 f8             	mov    %r15,%r8
 11eb3c8:	4d 89 f1             	mov    %r14,%r9
 11eb3cb:	c5 f8 77             	vzeroupper 
 11eb3ce:	e8 ad b3 01 00       	call   1206780 <br.chooseAdaptiveLiteralSplitAlloc>
 11eb3d3:	0f b7 85 28 e4 ff ff 	movzwl -0x1bd8(%rbp),%eax
 11eb3da:	66 85 c0             	test   %ax,%ax
 11eb3dd:	0f 85 8f 39 00 00    	jne    11eed72 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3d52>
 11eb3e3:	c5 fc 10 85 f0 e3 ff 	vmovups -0x1c10(%rbp),%ymm0
 11eb3ea:	ff 
 11eb3eb:	c5 fc 10 8d 08 e4 ff 	vmovups -0x1bf8(%rbp),%ymm1
 11eb3f2:	ff 
 11eb3f3:	c5 fc 11 8d c8 dc ff 	vmovups %ymm1,-0x2338(%rbp)
 11eb3fa:	ff 
 11eb3fb:	c5 fc 11 85 b0 dc ff 	vmovups %ymm0,-0x2350(%rbp)
 11eb402:	ff 
 11eb403:	48 8d 85 b0 dc ff ff 	lea    -0x2350(%rbp),%rax
 11eb40a:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eb40e:	eb 07                	jmp    11eb417 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3f7>
 11eb410:	48 8d 05 49 f9 e4 ff 	lea    -0x1b06b7(%rip),%rax        # 103ad60 <__anon_43575>
 11eb417:	c5 fc 10 40 18       	vmovups 0x18(%rax),%ymm0
 11eb41c:	c5 fc 11 85 48 ff ff 	vmovups %ymm0,-0xb8(%rbp)
 11eb423:	ff 
 11eb424:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11eb428:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 11eb42f:	ff 
 11eb430:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eb437:	48 8d 0d 5a f9 e4 ff 	lea    -0x1b06a6(%rip),%rcx        # 103ad98 <__anon_43609>
 11eb43e:	0f 84 8f 00 00 00    	je     11eb4d3 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4b3>
 11eb444:	f6 45 8f 01          	testb  $0x1,-0x71(%rbp)
 11eb448:	0f 84 85 00 00 00    	je     11eb4d3 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4b3>
 11eb44e:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11eb452:	c5 fc 10 48 10       	vmovups 0x10(%rax),%ymm1
 11eb457:	c5 fc 11 8d e0 e9 ff 	vmovups %ymm1,-0x1620(%rbp)
 11eb45e:	ff 
 11eb45f:	c5 fc 11 85 d0 e9 ff 	vmovups %ymm0,-0x1630(%rbp)
 11eb466:	ff 
 11eb467:	48 8d 85 d0 e9 ff ff 	lea    -0x1630(%rbp),%rax
 11eb46e:	48 89 04 24          	mov    %rax,(%rsp)
 11eb472:	48 8d bd f8 d3 ff ff 	lea    -0x2c08(%rbp),%rdi
 11eb479:	4c 89 ee             	mov    %r13,%rsi
 11eb47c:	4c 89 e1             	mov    %r12,%rcx
 11eb47f:	4d 89 f8             	mov    %r15,%r8
 11eb482:	4d 89 f1             	mov    %r14,%r9
 11eb485:	c5 f8 77             	vzeroupper 
 11eb488:	e8 a3 88 01 00       	call   1203d30 <br.encoder.literal_joint_context_split.chooseAlloc>
 11eb48d:	0f b7 85 58 d4 ff ff 	movzwl -0x2ba8(%rbp),%eax
 11eb494:	85 c0                	test   %eax,%eax
 11eb496:	0f 85 e3 38 00 00    	jne    11eed7f <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3d5f>
 11eb49c:	c5 fc 10 85 f8 d3 ff 	vmovups -0x2c08(%rbp),%ymm0
 11eb4a3:	ff 
 11eb4a4:	c5 fc 10 8d 38 d4 ff 	vmovups -0x2bc8(%rbp),%ymm1
 11eb4ab:	ff 
 11eb4ac:	c5 fc 11 8d 50 c9 ff 	vmovups %ymm1,-0x36b0(%rbp)
 11eb4b3:	ff 
 11eb4b4:	c5 fc 10 8d 18 d4 ff 	vmovups -0x2be8(%rbp),%ymm1
 11eb4bb:	ff 
 11eb4bc:	c5 fc 11 8d 30 c9 ff 	vmovups %ymm1,-0x36d0(%rbp)
 11eb4c3:	ff 
 11eb4c4:	c5 fc 11 85 10 c9 ff 	vmovups %ymm0,-0x36f0(%rbp)
 11eb4cb:	ff 
 11eb4cc:	48 8d 8d 10 c9 ff ff 	lea    -0x36f0(%rbp),%rcx
 11eb4d3:	88 5d 8f             	mov    %bl,-0x71(%rbp)
 11eb4d6:	c5 fc 10 41 20       	vmovups 0x20(%rcx),%ymm0
 11eb4db:	c5 fc 10 49 40       	vmovups 0x40(%rcx),%ymm1
 11eb4e0:	c5 fc 11 8d 70 fe ff 	vmovups %ymm1,-0x190(%rbp)
 11eb4e7:	ff 
 11eb4e8:	c5 fc 11 85 50 fe ff 	vmovups %ymm0,-0x1b0(%rbp)
 11eb4ef:	ff 
 11eb4f0:	c5 fc 10 01          	vmovups (%rcx),%ymm0
 11eb4f4:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 11eb4fb:	ff 
 11eb4fc:	c5 fc 10 85 00 ea ff 	vmovups -0x1600(%rbp),%ymm0
 11eb503:	ff 
 11eb504:	c5 fc 11 85 b0 fc ff 	vmovups %ymm0,-0x350(%rbp)
 11eb50b:	ff 
 11eb50c:	0f b6 45 8d          	movzbl -0x73(%rbp),%eax
 11eb510:	24 01                	and    $0x1,%al
 11eb512:	88 85 d0 fc ff ff    	mov    %al,-0x330(%rbp)
 11eb518:	0f b6 45 8e          	movzbl -0x72(%rbp),%eax
 11eb51c:	24 1f                	and    $0x1f,%al
 11eb51e:	88 85 d1 fc ff ff    	mov    %al,-0x32f(%rbp)
 11eb524:	c5 f8 28 85 80 fd ff 	vmovaps -0x280(%rbp),%xmm0
 11eb52b:	ff 
 11eb52c:	c5 f8 29 85 a0 fc ff 	vmovaps %xmm0,-0x360(%rbp)
 11eb533:	ff 
 11eb534:	48 8d 85 a0 fc ff ff 	lea    -0x360(%rbp),%rax
 11eb53b:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11eb540:	0f b6 45 8c          	movzbl -0x74(%rbp),%eax
 11eb544:	89 44 24 10          	mov    %eax,0x10(%rsp)
 11eb548:	0f b6 45 c6          	movzbl -0x3a(%rbp),%eax
 11eb54c:	89 44 24 08          	mov    %eax,0x8(%rsp)
 11eb550:	0f b6 85 28 ff ff ff 	movzbl -0xd8(%rbp),%eax
 11eb557:	89 04 24             	mov    %eax,(%rsp)
 11eb55a:	44 0f b6 45 8b       	movzbl -0x75(%rbp),%r8d
 11eb55f:	44 0f b6 8d 70 ff ff 	movzbl -0x90(%rbp),%r9d
 11eb566:	ff 
 11eb567:	48 8d bd 78 c2 ff ff 	lea    -0x3d88(%rbp),%rdi
 11eb56e:	4c 89 ee             	mov    %r13,%rsi
 11eb571:	4c 89 fa             	mov    %r15,%rdx
 11eb574:	4c 89 f1             	mov    %r14,%rcx
 11eb577:	c5 f8 77             	vzeroupper 
 11eb57a:	e8 a1 5c 00 00       	call   11f1220 <br.chooseCommandAndDistanceSplitsAlloc>
 11eb57f:	0f b7 9d 08 c9 ff ff 	movzwl -0x36f8(%rbp),%ebx
 11eb586:	66 85 db             	test   %bx,%bx
 11eb589:	0f 85 5f 37 00 00    	jne    11eecee <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cce>
 11eb58f:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11eb596:	48 8d b5 78 c2 ff ff 	lea    -0x3d88(%rbp),%rsi
 11eb59d:	ba 90 06 00 00       	mov    $0x690,%edx
 11eb5a2:	e8 79 ac 0a 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 11eb5a7:	c5 fc 10 85 c0 c5 ff 	vmovups -0x3a40(%rbp),%ymm0
 11eb5ae:	ff 
 11eb5af:	c5 fc 10 8d e0 c5 ff 	vmovups -0x3a20(%rbp),%ymm1
 11eb5b6:	ff 
 11eb5b7:	c5 fc 10 95 00 c6 ff 	vmovups -0x3a00(%rbp),%ymm2
 11eb5be:	ff 
 11eb5bf:	c5 fc 11 85 60 f7 ff 	vmovups %ymm0,-0x8a0(%rbp)
 11eb5c6:	ff 
 11eb5c7:	c5 fc 11 8d 80 f7 ff 	vmovups %ymm1,-0x880(%rbp)
 11eb5ce:	ff 
 11eb5cf:	c5 fc 11 95 a0 f7 ff 	vmovups %ymm2,-0x860(%rbp)
 11eb5d6:	ff 
 11eb5d7:	48 8b 85 20 c6 ff ff 	mov    -0x39e0(%rbp),%rax
 11eb5de:	48 89 85 c0 f7 ff ff 	mov    %rax,-0x840(%rbp)
 11eb5e5:	0f b6 95 10 e1 ff ff 	movzbl -0x1ef0(%rbp),%edx
 11eb5ec:	0f b6 8d 80 e1 ff ff 	movzbl -0x1e80(%rbp),%ecx
 11eb5f3:	c5 fc 10 85 a0 c6 ff 	vmovups -0x3960(%rbp),%ymm0
 11eb5fa:	ff 
 11eb5fb:	c5 fc 11 85 d0 f7 ff 	vmovups %ymm0,-0x830(%rbp)
 11eb602:	ff 
 11eb603:	c5 fc 10 85 c0 c6 ff 	vmovups -0x3940(%rbp),%ymm0
 11eb60a:	ff 
 11eb60b:	c5 fc 11 85 f0 f7 ff 	vmovups %ymm0,-0x810(%rbp)
 11eb612:	ff 
 11eb613:	c5 fc 10 85 e0 c6 ff 	vmovups -0x3920(%rbp),%ymm0
 11eb61a:	ff 
 11eb61b:	c5 fc 11 85 10 f8 ff 	vmovups %ymm0,-0x7f0(%rbp)
 11eb622:	ff 
 11eb623:	48 8b 85 00 c7 ff ff 	mov    -0x3900(%rbp),%rax
 11eb62a:	48 89 85 30 f8 ff ff 	mov    %rax,-0x7d0(%rbp)
 11eb631:	0f b6 9d f0 e1 ff ff 	movzbl -0x1e10(%rbp),%ebx
 11eb638:	44 0f b6 9d 60 e2 ff 	movzbl -0x1da0(%rbp),%r11d
 11eb63f:	ff 
 11eb640:	c5 fc 10 85 10 c7 ff 	vmovups -0x38f0(%rbp),%ymm0
 11eb647:	ff 
 11eb648:	c5 fc 10 8d 30 c7 ff 	vmovups -0x38d0(%rbp),%ymm1
 11eb64f:	ff 
 11eb650:	c5 fc 10 95 50 c7 ff 	vmovups -0x38b0(%rbp),%ymm2
 11eb657:	ff 
 11eb658:	c5 fc 11 85 40 f8 ff 	vmovups %ymm0,-0x7c0(%rbp)
 11eb65f:	ff 
 11eb660:	c5 fc 11 8d 60 f8 ff 	vmovups %ymm1,-0x7a0(%rbp)
 11eb667:	ff 
 11eb668:	c5 fc 11 95 80 f8 ff 	vmovups %ymm2,-0x780(%rbp)
 11eb66f:	ff 
 11eb670:	48 8b 85 70 c7 ff ff 	mov    -0x3890(%rbp),%rax
 11eb677:	48 89 85 a0 f8 ff ff 	mov    %rax,-0x760(%rbp)
 11eb67e:	c5 fc 10 85 80 c7 ff 	vmovups -0x3880(%rbp),%ymm0
 11eb685:	ff 
 11eb686:	c5 fc 11 85 b0 f8 ff 	vmovups %ymm0,-0x750(%rbp)
 11eb68d:	ff 
 11eb68e:	c5 fc 10 85 a0 c7 ff 	vmovups -0x3860(%rbp),%ymm0
 11eb695:	ff 
 11eb696:	c5 fc 11 85 d0 f8 ff 	vmovups %ymm0,-0x730(%rbp)
 11eb69d:	ff 
 11eb69e:	c5 fc 10 85 c0 c7 ff 	vmovups -0x3840(%rbp),%ymm0
 11eb6a5:	ff 
 11eb6a6:	c5 fc 11 85 f0 f8 ff 	vmovups %ymm0,-0x710(%rbp)
 11eb6ad:	ff 
 11eb6ae:	48 8b 85 e0 c7 ff ff 	mov    -0x3820(%rbp),%rax
 11eb6b5:	48 89 85 10 f9 ff ff 	mov    %rax,-0x6f0(%rbp)
 11eb6bc:	44 0f b6 95 d0 e2 ff 	movzbl -0x1d30(%rbp),%r10d
 11eb6c3:	ff 
 11eb6c4:	44 0f b6 8d 40 e3 ff 	movzbl -0x1cc0(%rbp),%r9d
 11eb6cb:	ff 
 11eb6cc:	48 8b 85 50 c8 ff ff 	mov    -0x37b0(%rbp),%rax
 11eb6d3:	48 89 85 80 f9 ff ff 	mov    %rax,-0x680(%rbp)
 11eb6da:	c5 fc 10 85 f0 c7 ff 	vmovups -0x3810(%rbp),%ymm0
 11eb6e1:	ff 
 11eb6e2:	c5 fc 10 8d 10 c8 ff 	vmovups -0x37f0(%rbp),%ymm1
 11eb6e9:	ff 
 11eb6ea:	c5 fc 10 95 30 c8 ff 	vmovups -0x37d0(%rbp),%ymm2
 11eb6f1:	ff 
 11eb6f2:	c5 fc 11 95 60 f9 ff 	vmovups %ymm2,-0x6a0(%rbp)
 11eb6f9:	ff 
 11eb6fa:	c5 fc 11 8d 40 f9 ff 	vmovups %ymm1,-0x6c0(%rbp)
 11eb701:	ff 
 11eb702:	c5 fc 11 85 20 f9 ff 	vmovups %ymm0,-0x6e0(%rbp)
 11eb709:	ff 
 11eb70a:	48 8b 85 c0 c8 ff ff 	mov    -0x3740(%rbp),%rax
 11eb711:	48 89 85 f0 f9 ff ff 	mov    %rax,-0x610(%rbp)
 11eb718:	c5 fc 10 85 a0 c8 ff 	vmovups -0x3760(%rbp),%ymm0
 11eb71f:	ff 
 11eb720:	c5 fc 11 85 d0 f9 ff 	vmovups %ymm0,-0x630(%rbp)
 11eb727:	ff 
 11eb728:	c5 fc 10 85 80 c8 ff 	vmovups -0x3780(%rbp),%ymm0
 11eb72f:	ff 
 11eb730:	c5 fc 11 85 b0 f9 ff 	vmovups %ymm0,-0x650(%rbp)
 11eb737:	ff 
 11eb738:	c5 fc 10 85 60 c8 ff 	vmovups -0x37a0(%rbp),%ymm0
 11eb73f:	ff 
 11eb740:	c5 fc 11 85 90 f9 ff 	vmovups %ymm0,-0x670(%rbp)
 11eb747:	ff 
 11eb748:	88 8d 80 fd ff ff    	mov    %cl,-0x280(%rbp)
 11eb74e:	84 c9                	test   %cl,%cl
 11eb750:	0f 84 b7 00 00 00    	je     11eb80d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x7ed>
 11eb756:	48 8b 85 90 c6 ff ff 	mov    -0x3970(%rbp),%rax
 11eb75d:	48 89 85 a0 dc ff ff 	mov    %rax,-0x2360(%rbp)
 11eb764:	c5 fc 10 85 50 c6 ff 	vmovups -0x39b0(%rbp),%ymm0
 11eb76b:	ff 
 11eb76c:	c5 fc 10 8d 70 c6 ff 	vmovups -0x3990(%rbp),%ymm1
 11eb773:	ff 
 11eb774:	c5 fc 11 8d 80 dc ff 	vmovups %ymm1,-0x2380(%rbp)
 11eb77b:	ff 
 11eb77c:	c5 fc 11 85 60 dc ff 	vmovups %ymm0,-0x23a0(%rbp)
 11eb783:	ff 
 11eb784:	c5 fc 10 85 30 c6 ff 	vmovups -0x39d0(%rbp),%ymm0
 11eb78b:	ff 
 11eb78c:	c5 fc 11 85 40 dc ff 	vmovups %ymm0,-0x23c0(%rbp)
 11eb793:	ff 
 11eb794:	c6 85 a8 dc ff ff 01 	movb   $0x1,-0x2358(%rbp)
 11eb79b:	48 8d 85 40 dc ff ff 	lea    -0x23c0(%rbp),%rax
 11eb7a2:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 11eb7a9:	b0 01                	mov    $0x1,%al
 11eb7ab:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11eb7af:	80 bd 38 de ff ff 00 	cmpb   $0x0,-0x21c8(%rbp)
 11eb7b6:	0f 84 cb 00 00 00    	je     11eb887 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x867>
 11eb7bc:	48 8b 8d 48 c3 ff ff 	mov    -0x3cb8(%rbp),%rcx
 11eb7c3:	48 89 8d 30 dc ff ff 	mov    %rcx,-0x23d0(%rbp)
 11eb7ca:	c5 fc 10 85 e8 c2 ff 	vmovups -0x3d18(%rbp),%ymm0
 11eb7d1:	ff 
 11eb7d2:	c5 fc 10 8d 08 c3 ff 	vmovups -0x3cf8(%rbp),%ymm1
 11eb7d9:	ff 
 11eb7da:	c5 fc 10 95 28 c3 ff 	vmovups -0x3cd8(%rbp),%ymm2
 11eb7e1:	ff 
 11eb7e2:	c5 fc 11 95 10 dc ff 	vmovups %ymm2,-0x23f0(%rbp)
 11eb7e9:	ff 
 11eb7ea:	c5 fc 11 8d f0 db ff 	vmovups %ymm1,-0x2410(%rbp)
 11eb7f1:	ff 
 11eb7f2:	c5 fc 11 85 d0 db ff 	vmovups %ymm0,-0x2430(%rbp)
 11eb7f9:	ff 
 11eb7fa:	c6 85 38 dc ff ff 01 	movb   $0x1,-0x23c8(%rbp)
 11eb801:	48 8d 8d d0 db ff ff 	lea    -0x2430(%rbp),%rcx
 11eb808:	e9 c1 00 00 00       	jmp    11eb8ce <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x8ae>
 11eb80d:	48 8d 85 c0 c5 ff ff 	lea    -0x3a40(%rbp),%rax
 11eb814:	48 8b 48 60          	mov    0x60(%rax),%rcx
 11eb818:	48 89 8d 80 ea ff ff 	mov    %rcx,-0x1580(%rbp)
 11eb81f:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11eb823:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11eb828:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11eb82d:	c5 fc 11 95 60 ea ff 	vmovups %ymm2,-0x15a0(%rbp)
 11eb834:	ff 
 11eb835:	c5 fc 11 8d 40 ea ff 	vmovups %ymm1,-0x15c0(%rbp)
 11eb83c:	ff 
 11eb83d:	c5 fc 11 85 20 ea ff 	vmovups %ymm0,-0x15e0(%rbp)
 11eb844:	ff 
 11eb845:	88 95 88 ea ff ff    	mov    %dl,-0x1578(%rbp)
 11eb84b:	8b 85 29 c6 ff ff    	mov    -0x39d7(%rbp),%eax
 11eb851:	8b 8d 2c c6 ff ff    	mov    -0x39d4(%rbp),%ecx
 11eb857:	89 85 89 ea ff ff    	mov    %eax,-0x1577(%rbp)
 11eb85d:	89 8d 8c ea ff ff    	mov    %ecx,-0x1574(%rbp)
 11eb863:	84 d2                	test   %dl,%dl
 11eb865:	0f 95 c0             	setne  %al
 11eb868:	48 8d 8d 20 ea ff ff 	lea    -0x15e0(%rbp),%rcx
 11eb86f:	48 89 8d 28 ff ff ff 	mov    %rcx,-0xd8(%rbp)
 11eb876:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11eb87a:	80 bd 38 de ff ff 00 	cmpb   $0x0,-0x21c8(%rbp)
 11eb881:	0f 85 35 ff ff ff    	jne    11eb7bc <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x79c>
 11eb887:	c5 fc 10 85 78 c2 ff 	vmovups -0x3d88(%rbp),%ymm0
 11eb88e:	ff 
 11eb88f:	c5 fc 10 8d b8 c2 ff 	vmovups -0x3d48(%rbp),%ymm1
 11eb896:	ff 
 11eb897:	c5 fc 10 95 c8 c2 ff 	vmovups -0x3d38(%rbp),%ymm2
 11eb89e:	ff 
 11eb89f:	c5 fc 11 95 c0 c9 ff 	vmovups %ymm2,-0x3640(%rbp)
 11eb8a6:	ff 
 11eb8a7:	c5 fc 11 8d b0 c9 ff 	vmovups %ymm1,-0x3650(%rbp)
 11eb8ae:	ff 
 11eb8af:	c5 fc 10 8d 98 c2 ff 	vmovups -0x3d68(%rbp),%ymm1
 11eb8b6:	ff 
 11eb8b7:	c5 fc 11 8d 90 c9 ff 	vmovups %ymm1,-0x3670(%rbp)
 11eb8be:	ff 
 11eb8bf:	c5 fc 11 85 70 c9 ff 	vmovups %ymm0,-0x3690(%rbp)
 11eb8c6:	ff 
 11eb8c7:	48 8d 8d 70 c9 ff ff 	lea    -0x3690(%rbp),%rcx
 11eb8ce:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 11eb8d5:	40 b7 01             	mov    $0x1,%dil
 11eb8d8:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 11eb8df:	80 79 68 00          	cmpb   $0x0,0x68(%rcx)
 11eb8e3:	75 12                	jne    11eb8f7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x8d7>
 11eb8e5:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11eb8ec:	80 79 68 00          	cmpb   $0x0,0x68(%rcx)
 11eb8f0:	40 0f 95 c7          	setne  %dil
 11eb8f4:	40 08 c7             	or     %al,%dil
 11eb8f7:	44 0f b6 85 b0 e3 ff 	movzbl -0x1c50(%rbp),%r8d
 11eb8fe:	ff 
 11eb8ff:	0f b6 8d 60 ff ff ff 	movzbl -0xa0(%rbp),%ecx
 11eb906:	0f b6 85 a0 e0 ff ff 	movzbl -0x1f60(%rbp),%eax
 11eb90d:	40 f6 c7 01          	test   $0x1,%dil
 11eb911:	75 47                	jne    11eb95a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x93a>
 11eb913:	84 c9                	test   %cl,%cl
 11eb915:	75 43                	jne    11eb95a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x93a>
 11eb917:	84 c0                	test   %al,%al
 11eb919:	75 3f                	jne    11eb95a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x93a>
 11eb91b:	80 bd e8 e3 ff ff 00 	cmpb   $0x0,-0x1c18(%rbp)
 11eb922:	75 36                	jne    11eb95a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x93a>
 11eb924:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11eb928:	c5 fc 11 85 88 e0 ff 	vmovups %ymm0,-0x1f78(%rbp)
 11eb92f:	ff 
 11eb930:	c5 fc 11 85 70 e0 ff 	vmovups %ymm0,-0x1f90(%rbp)
 11eb937:	ff 
 11eb938:	c5 fc 11 85 b8 e3 ff 	vmovups %ymm0,-0x1c48(%rbp)
 11eb93f:	ff 
 11eb940:	c5 fc 11 85 d0 e3 ff 	vmovups %ymm0,-0x1c30(%rbp)
 11eb947:	ff 
 11eb948:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11eb94f:	0f 85 70 2f 00 00    	jne    11ee8c5 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x38a5>
 11eb955:	e9 2c 30 00 00       	jmp    11ee986 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3966>
 11eb95a:	88 55 8b             	mov    %dl,-0x75(%rbp)
 11eb95d:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 11eb961:	c5 fc 10 42 70       	vmovups 0x70(%rdx),%ymm0
 11eb966:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 11eb96d:	ff 
 11eb96e:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 11eb972:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 11eb977:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 11eb97c:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 11eb981:	c5 fc 11 9d f0 fe ff 	vmovups %ymm3,-0x110(%rbp)
 11eb988:	ff 
 11eb989:	c5 fc 11 95 d0 fe ff 	vmovups %ymm2,-0x130(%rbp)
 11eb990:	ff 
 11eb991:	c5 fc 11 8d b0 fe ff 	vmovups %ymm1,-0x150(%rbp)
 11eb998:	ff 
 11eb999:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 11eb9a0:	ff 
 11eb9a1:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 11eb9a5:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 11eb9aa:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 11eb9af:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 11eb9b4:	c5 fc 11 85 e0 fc ff 	vmovups %ymm0,-0x320(%rbp)
 11eb9bb:	ff 
 11eb9bc:	c5 fc 11 8d 00 fd ff 	vmovups %ymm1,-0x300(%rbp)
 11eb9c3:	ff 
 11eb9c4:	c5 fc 11 95 20 fd ff 	vmovups %ymm2,-0x2e0(%rbp)
 11eb9cb:	ff 
 11eb9cc:	c5 fc 11 9d 40 fd ff 	vmovups %ymm3,-0x2c0(%rbp)
 11eb9d3:	ff 
 11eb9d4:	c5 fc 10 42 70       	vmovups 0x70(%rdx),%ymm0
 11eb9d9:	c5 fc 11 85 50 fd ff 	vmovups %ymm0,-0x2b0(%rbp)
 11eb9e0:	ff 
 11eb9e1:	40 f6 c7 01          	test   $0x1,%dil
 11eb9e5:	40 88 7d c6          	mov    %dil,-0x3a(%rbp)
 11eb9e9:	44 88 85 27 ff ff ff 	mov    %r8b,-0xd9(%rbp)
 11eb9f0:	44 88 8d 26 ff ff ff 	mov    %r9b,-0xda(%rbp)
 11eb9f7:	44 88 55 8e          	mov    %r10b,-0x72(%rbp)
 11eb9fb:	44 88 5d 8d          	mov    %r11b,-0x73(%rbp)
 11eb9ff:	88 5d 8c             	mov    %bl,-0x74(%rbp)
 11eba02:	0f 84 5c 01 00 00    	je     11ebb64 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xb44>
 11eba08:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11eba0f:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11eba14:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11eba1b:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11eba20:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11eba24:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11eba2a:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11eba31:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11eba36:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11eba3b:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11eba3f:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11eba44:	48 8d 85 e0 fc ff ff 	lea    -0x320(%rbp),%rax
 11eba4b:	48 89 04 24          	mov    %rax,(%rsp)
 11eba4f:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11eba56:	00 00 
 11eba58:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11eba5f:	00 00 
 11eba61:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11eba65:	4c 89 ee             	mov    %r13,%rsi
 11eba68:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11eba6c:	4c 89 e1             	mov    %r12,%rcx
 11eba6f:	4d 89 f8             	mov    %r15,%r8
 11eba72:	4d 89 f1             	mov    %r14,%r9
 11eba75:	c5 f8 77             	vzeroupper 
 11eba78:	e8 73 4b 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11eba7d:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11eba81:	66 85 db             	test   %bx,%bx
 11eba84:	0f 84 2e 04 00 00    	je     11ebeb8 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xe98>
 11eba8a:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11eba91:	ff 
 11eba92:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11eba96:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11eba9b:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ebaa2:	ff 
 11ebaa3:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ebaaa:	ff 
 11ebaab:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ebab2:	ff 
 11ebab3:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ebaba:	ff 
 11ebabb:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ebac0:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ebac5:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ebaca:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ebace:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ebad5:	4c 89 ee             	mov    %r13,%rsi
 11ebad8:	c5 f8 77             	vzeroupper 
 11ebadb:	e8 30 55 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ebae0:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ebae7:	74 42                	je     11ebb2b <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xb0b>
 11ebae9:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ebaf0:	ff 
 11ebaf1:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ebaf8:	ff 
 11ebaf9:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ebb00:	ff 
 11ebb01:	c5 fc 11 95 78 d3 ff 	vmovups %ymm2,-0x2c88(%rbp)
 11ebb08:	ff 
 11ebb09:	c5 fc 11 8d 60 d3 ff 	vmovups %ymm1,-0x2ca0(%rbp)
 11ebb10:	ff 
 11ebb11:	c5 fc 11 85 40 d3 ff 	vmovups %ymm0,-0x2cc0(%rbp)
 11ebb18:	ff 
 11ebb19:	48 8d bd 40 d3 ff ff 	lea    -0x2cc0(%rbp),%rdi
 11ebb20:	4c 89 ee             	mov    %r13,%rsi
 11ebb23:	c5 f8 77             	vzeroupper 
 11ebb26:	e8 15 56 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ebb2b:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ebb32:	0f 84 1c 44 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ebb38:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ebb3f:	ff 
 11ebb40:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ebb47:	ff 
 11ebb48:	c5 fc 11 8d f0 e8 ff 	vmovups %ymm1,-0x1710(%rbp)
 11ebb4f:	ff 
 11ebb50:	c5 fc 11 85 e0 e8 ff 	vmovups %ymm0,-0x1720(%rbp)
 11ebb57:	ff 
 11ebb58:	48 8d bd e0 e8 ff ff 	lea    -0x1720(%rbp),%rdi
 11ebb5f:	e9 e5 43 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11ebb64:	84 c9                	test   %cl,%cl
 11ebb66:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ebb6a:	0f 84 63 01 00 00    	je     11ebcd3 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xcb3>
 11ebb70:	48 8d 05 61 f3 e4 ff 	lea    -0x1b0c9f(%rip),%rax        # 103aed8 <__anon_35267>
 11ebb77:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ebb7c:	48 8d 05 e5 f2 e4 ff 	lea    -0x1b0d1b(%rip),%rax        # 103ae68 <__anon_35266>
 11ebb83:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ebb88:	48 8d 85 30 ff ff ff 	lea    -0xd0(%rbp),%rax
 11ebb8f:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 11ebb94:	48 8d 05 5d f2 e4 ff 	lea    -0x1b0da3(%rip),%rax        # 103adf8 <__anon_35263>
 11ebb9b:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ebba0:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ebba5:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ebba9:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ebbae:	48 8d 85 e0 fc ff ff 	lea    -0x320(%rbp),%rax
 11ebbb5:	48 89 04 24          	mov    %rax,(%rsp)
 11ebbb9:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ebbc0:	00 00 
 11ebbc2:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ebbc9:	00 00 
 11ebbcb:	48 c7 44 24 28 00 00 	movq   $0x0,0x28(%rsp)
 11ebbd2:	00 00 
 11ebbd4:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ebbd8:	4c 89 ee             	mov    %r13,%rsi
 11ebbdb:	4c 89 e1             	mov    %r12,%rcx
 11ebbde:	4d 89 f8             	mov    %r15,%r8
 11ebbe1:	4d 89 f1             	mov    %r14,%r9
 11ebbe4:	c5 f8 77             	vzeroupper 
 11ebbe7:	e8 04 4a 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ebbec:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ebbf0:	66 85 db             	test   %bx,%bx
 11ebbf3:	0f 84 bf 02 00 00    	je     11ebeb8 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xe98>
 11ebbf9:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ebc00:	ff 
 11ebc01:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ebc05:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ebc0a:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ebc11:	ff 
 11ebc12:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ebc19:	ff 
 11ebc1a:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ebc21:	ff 
 11ebc22:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ebc29:	ff 
 11ebc2a:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ebc2f:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ebc34:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ebc39:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ebc3d:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ebc44:	4c 89 ee             	mov    %r13,%rsi
 11ebc47:	c5 f8 77             	vzeroupper 
 11ebc4a:	e8 c1 53 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ebc4f:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ebc56:	74 42                	je     11ebc9a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xc7a>
 11ebc58:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ebc5f:	ff 
 11ebc60:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ebc67:	ff 
 11ebc68:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ebc6f:	ff 
 11ebc70:	c5 fc 11 95 18 d3 ff 	vmovups %ymm2,-0x2ce8(%rbp)
 11ebc77:	ff 
 11ebc78:	c5 fc 11 8d 00 d3 ff 	vmovups %ymm1,-0x2d00(%rbp)
 11ebc7f:	ff 
 11ebc80:	c5 fc 11 85 e0 d2 ff 	vmovups %ymm0,-0x2d20(%rbp)
 11ebc87:	ff 
 11ebc88:	48 8d bd e0 d2 ff ff 	lea    -0x2d20(%rbp),%rdi
 11ebc8f:	4c 89 ee             	mov    %r13,%rsi
 11ebc92:	c5 f8 77             	vzeroupper 
 11ebc95:	e8 a6 54 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ebc9a:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ebca1:	0f 84 ad 42 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ebca7:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ebcae:	ff 
 11ebcaf:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ebcb6:	ff 
 11ebcb7:	c5 fc 11 8d c0 e8 ff 	vmovups %ymm1,-0x1740(%rbp)
 11ebcbe:	ff 
 11ebcbf:	c5 fc 11 85 b0 e8 ff 	vmovups %ymm0,-0x1750(%rbp)
 11ebcc6:	ff 
 11ebcc7:	48 8d bd b0 e8 ff ff 	lea    -0x1750(%rbp),%rdi
 11ebcce:	e9 76 42 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11ebcd3:	84 c0                	test   %al,%al
 11ebcd5:	0f 84 5c 01 00 00    	je     11ebe37 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xe17>
 11ebcdb:	48 8d 85 70 e0 ff ff 	lea    -0x1f90(%rbp),%rax
 11ebce2:	48 8d 0d ef f1 e4 ff 	lea    -0x1b0e11(%rip),%rcx        # 103aed8 <__anon_35267>
 11ebce9:	48 89 4c 24 40       	mov    %rcx,0x40(%rsp)
 11ebcee:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 11ebcf3:	48 8d 05 6e f1 e4 ff 	lea    -0x1b0e92(%rip),%rax        # 103ae68 <__anon_35266>
 11ebcfa:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ebcff:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ebd03:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ebd09:	48 8d 05 e8 f0 e4 ff 	lea    -0x1b0f18(%rip),%rax        # 103adf8 <__anon_35263>
 11ebd10:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ebd15:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ebd1a:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ebd1e:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ebd23:	48 8d 85 e0 fc ff ff 	lea    -0x320(%rbp),%rax
 11ebd2a:	48 89 04 24          	mov    %rax,(%rsp)
 11ebd2e:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ebd35:	00 00 
 11ebd37:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ebd3b:	4c 89 ee             	mov    %r13,%rsi
 11ebd3e:	4c 89 e1             	mov    %r12,%rcx
 11ebd41:	4d 89 f8             	mov    %r15,%r8
 11ebd44:	4d 89 f1             	mov    %r14,%r9
 11ebd47:	c5 f8 77             	vzeroupper 
 11ebd4a:	e8 a1 48 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ebd4f:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ebd53:	66 85 db             	test   %bx,%bx
 11ebd56:	0f 84 5c 01 00 00    	je     11ebeb8 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xe98>
 11ebd5c:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ebd63:	ff 
 11ebd64:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ebd68:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ebd6d:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ebd74:	ff 
 11ebd75:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ebd7c:	ff 
 11ebd7d:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ebd84:	ff 
 11ebd85:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ebd8c:	ff 
 11ebd8d:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ebd92:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ebd97:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ebd9c:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ebda0:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ebda7:	4c 89 ee             	mov    %r13,%rsi
 11ebdaa:	c5 f8 77             	vzeroupper 
 11ebdad:	e8 5e 52 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ebdb2:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ebdb9:	74 43                	je     11ebdfe <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xdde>
 11ebdbb:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ebdc2:	ff 
 11ebdc3:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ebdca:	ff 
 11ebdcb:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ebdd2:	ff 
 11ebdd3:	c5 fc 11 95 b8 d2 ff 	vmovups %ymm2,-0x2d48(%rbp)
 11ebdda:	ff 
 11ebddb:	c5 fc 11 8d a0 d2 ff 	vmovups %ymm1,-0x2d60(%rbp)
 11ebde2:	ff 
 11ebde3:	c5 fc 11 85 80 d2 ff 	vmovups %ymm0,-0x2d80(%rbp)
 11ebdea:	ff 
 11ebdeb:	48 8d bd 80 d2 ff ff 	lea    -0x2d80(%rbp),%rdi
 11ebdf2:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11ebdf6:	c5 f8 77             	vzeroupper 
 11ebdf9:	e8 42 53 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ebdfe:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ebe05:	0f 84 49 41 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ebe0b:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ebe12:	ff 
 11ebe13:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ebe1a:	ff 
 11ebe1b:	c5 fc 11 8d 90 e8 ff 	vmovups %ymm1,-0x1770(%rbp)
 11ebe22:	ff 
 11ebe23:	c5 fc 11 85 80 e8 ff 	vmovups %ymm0,-0x1780(%rbp)
 11ebe2a:	ff 
 11ebe2b:	48 8d bd 80 e8 ff ff 	lea    -0x1780(%rbp),%rdi
 11ebe32:	e9 c4 46 00 00       	jmp    11f04fb <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x54db>
 11ebe37:	48 8d 85 b8 e3 ff ff 	lea    -0x1c48(%rbp),%rax
 11ebe3e:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 11ebe43:	48 8d 05 8e f0 e4 ff 	lea    -0x1b0f72(%rip),%rax        # 103aed8 <__anon_35267>
 11ebe4a:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ebe4f:	48 8d 05 12 f0 e4 ff 	lea    -0x1b0fee(%rip),%rax        # 103ae68 <__anon_35266>
 11ebe56:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ebe5b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ebe5f:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ebe65:	48 8d 05 8c ef e4 ff 	lea    -0x1b1074(%rip),%rax        # 103adf8 <__anon_35263>
 11ebe6c:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ebe71:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ebe76:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ebe7a:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ebe7f:	48 8d 85 e0 fc ff ff 	lea    -0x320(%rbp),%rax
 11ebe86:	48 89 04 24          	mov    %rax,(%rsp)
 11ebe8a:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ebe91:	00 00 
 11ebe93:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ebe97:	4c 89 ee             	mov    %r13,%rsi
 11ebe9a:	4c 89 e1             	mov    %r12,%rcx
 11ebe9d:	4d 89 f8             	mov    %r15,%r8
 11ebea0:	4d 89 f1             	mov    %r14,%r9
 11ebea3:	c5 f8 77             	vzeroupper 
 11ebea6:	e8 45 47 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ebeab:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ebeaf:	66 85 db             	test   %bx,%bx
 11ebeb2:	0f 85 6d 45 00 00    	jne    11f0425 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5405>
 11ebeb8:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ebebc:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ebec0:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ebec4:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ebec8:	0f b6 4d c7          	movzbl -0x39(%rbp),%ecx
 11ebecc:	80 bd 21 ff ff ff 00 	cmpb   $0x0,-0xdf(%rbp)
 11ebed3:	0f 94 c0             	sete   %al
 11ebed6:	c5 fc 10 85 50 fd ff 	vmovups -0x2b0(%rbp),%ymm0
 11ebedd:	ff 
 11ebede:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ebee5:	ff 
 11ebee6:	c5 fc 10 85 00 fd ff 	vmovups -0x300(%rbp),%ymm0
 11ebeed:	ff 
 11ebeee:	c5 fc 10 8d 20 fd ff 	vmovups -0x2e0(%rbp),%ymm1
 11ebef5:	ff 
 11ebef6:	c5 fc 10 95 40 fd ff 	vmovups -0x2c0(%rbp),%ymm2
 11ebefd:	ff 
 11ebefe:	c5 fc 11 95 f0 fd ff 	vmovups %ymm2,-0x210(%rbp)
 11ebf05:	ff 
 11ebf06:	c5 fc 11 8d d0 fd ff 	vmovups %ymm1,-0x230(%rbp)
 11ebf0d:	ff 
 11ebf0e:	c5 fc 11 85 b0 fd ff 	vmovups %ymm0,-0x250(%rbp)
 11ebf15:	ff 
 11ebf16:	c5 fc 10 85 e0 fc ff 	vmovups -0x320(%rbp),%ymm0
 11ebf1d:	ff 
 11ebf1e:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ebf25:	ff 
 11ebf26:	84 c9                	test   %cl,%cl
 11ebf28:	0f 94 c1             	sete   %cl
 11ebf2b:	08 c1                	or     %al,%cl
 11ebf2d:	74 0b                	je     11ebf3a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0xf1a>
 11ebf2f:	4d 89 e6             	mov    %r12,%r14
 11ebf32:	4c 89 fb             	mov    %r15,%rbx
 11ebf35:	e9 b6 01 00 00       	jmp    11ec0f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x10d0>
 11ebf3a:	48 8b 85 60 fa ff ff 	mov    -0x5a0(%rbp),%rax
 11ebf41:	48 89 85 c0 db ff ff 	mov    %rax,-0x2440(%rbp)
 11ebf48:	c5 fc 10 85 00 fa ff 	vmovups -0x600(%rbp),%ymm0
 11ebf4f:	ff 
 11ebf50:	c5 fc 10 8d 20 fa ff 	vmovups -0x5e0(%rbp),%ymm1
 11ebf57:	ff 
 11ebf58:	c5 fc 10 95 40 fa ff 	vmovups -0x5c0(%rbp),%ymm2
 11ebf5f:	ff 
 11ebf60:	c5 fc 11 95 a0 db ff 	vmovups %ymm2,-0x2460(%rbp)
 11ebf67:	ff 
 11ebf68:	c5 fc 11 8d 80 db ff 	vmovups %ymm1,-0x2480(%rbp)
 11ebf6f:	ff 
 11ebf70:	c5 fc 11 85 60 db ff 	vmovups %ymm0,-0x24a0(%rbp)
 11ebf77:	ff 
 11ebf78:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ebf7f:	ff 
 11ebf80:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ebf87:	ff 
 11ebf88:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ebf8f:	ff 
 11ebf90:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ebf97:	ff 
 11ebf98:	c5 fc 11 85 d0 f6 ff 	vmovups %ymm0,-0x930(%rbp)
 11ebf9f:	ff 
 11ebfa0:	c5 fc 11 8d f0 f6 ff 	vmovups %ymm1,-0x910(%rbp)
 11ebfa7:	ff 
 11ebfa8:	c5 fc 11 95 10 f7 ff 	vmovups %ymm2,-0x8f0(%rbp)
 11ebfaf:	ff 
 11ebfb0:	c5 fc 11 9d 30 f7 ff 	vmovups %ymm3,-0x8d0(%rbp)
 11ebfb7:	ff 
 11ebfb8:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ebfbf:	ff 
 11ebfc0:	c5 fc 11 85 40 f7 ff 	vmovups %ymm0,-0x8c0(%rbp)
 11ebfc7:	ff 
 11ebfc8:	c6 85 c8 db ff ff 01 	movb   $0x1,-0x2438(%rbp)
 11ebfcf:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ebfd6:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ebfdb:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ebfe2:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ebfe7:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ebfeb:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ebff1:	48 8d 85 60 db ff ff 	lea    -0x24a0(%rbp),%rax
 11ebff8:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ebffd:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ec002:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ec006:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ec00b:	48 8d 85 d0 f6 ff ff 	lea    -0x930(%rbp),%rax
 11ec012:	48 89 04 24          	mov    %rax,(%rsp)
 11ec016:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ec01d:	00 00 
 11ec01f:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ec026:	00 00 
 11ec028:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ec02c:	4c 89 ee             	mov    %r13,%rsi
 11ec02f:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ec033:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ec037:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ec03b:	c5 f8 77             	vzeroupper 
 11ec03e:	e8 ad 45 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ec043:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ec047:	66 85 db             	test   %bx,%bx
 11ec04a:	0f 85 16 3d 00 00    	jne    11efd66 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4d46>
 11ec050:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11ec054:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 11ec058:	4c 39 fb             	cmp    %r15,%rbx
 11ec05b:	73 69                	jae    11ec0c6 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x10a6>
 11ec05d:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec061:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec065:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec069:	4c 89 e6             	mov    %r12,%rsi
 11ec06c:	4c 89 fa             	mov    %r15,%rdx
 11ec06f:	31 c9                	xor    %ecx,%ecx
 11ec071:	ff 50 18             	call   *0x18(%rax)
 11ec074:	c5 fc 10 85 40 f7 ff 	vmovups -0x8c0(%rbp),%ymm0
 11ec07b:	ff 
 11ec07c:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ec083:	ff 
 11ec084:	c5 fc 10 85 d0 f6 ff 	vmovups -0x930(%rbp),%ymm0
 11ec08b:	ff 
 11ec08c:	c5 fc 10 8d f0 f6 ff 	vmovups -0x910(%rbp),%ymm1
 11ec093:	ff 
 11ec094:	c5 fc 10 95 10 f7 ff 	vmovups -0x8f0(%rbp),%ymm2
 11ec09b:	ff 
 11ec09c:	c5 fc 10 9d 30 f7 ff 	vmovups -0x8d0(%rbp),%ymm3
 11ec0a3:	ff 
 11ec0a4:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ec0ab:	ff 
 11ec0ac:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ec0b3:	ff 
 11ec0b4:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ec0bb:	ff 
 11ec0bc:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ec0c3:	ff 
 11ec0c4:	eb 22                	jmp    11ec0e8 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x10c8>
 11ec0c6:	48 85 db             	test   %rbx,%rbx
 11ec0c9:	74 17                	je     11ec0e2 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x10c2>
 11ec0cb:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec0cf:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec0d3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec0d7:	4c 89 f6             	mov    %r14,%rsi
 11ec0da:	48 89 da             	mov    %rbx,%rdx
 11ec0dd:	31 c9                	xor    %ecx,%ecx
 11ec0df:	ff 50 18             	call   *0x18(%rax)
 11ec0e2:	4d 89 e6             	mov    %r12,%r14
 11ec0e5:	4c 89 fb             	mov    %r15,%rbx
 11ec0e8:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ec0ec:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ec0f0:	80 bd 22 ff ff ff 00 	cmpb   $0x0,-0xde(%rbp)
 11ec0f7:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ec0fb:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ec0ff:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ec103:	0f 84 9a 01 00 00    	je     11ec2a3 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1283>
 11ec109:	48 8b 85 d0 fa ff ff 	mov    -0x530(%rbp),%rax
 11ec110:	48 89 85 50 db ff ff 	mov    %rax,-0x24b0(%rbp)
 11ec117:	c5 fc 10 85 70 fa ff 	vmovups -0x590(%rbp),%ymm0
 11ec11e:	ff 
 11ec11f:	c5 fc 10 8d 90 fa ff 	vmovups -0x570(%rbp),%ymm1
 11ec126:	ff 
 11ec127:	c5 fc 10 95 b0 fa ff 	vmovups -0x550(%rbp),%ymm2
 11ec12e:	ff 
 11ec12f:	c5 fc 11 95 30 db ff 	vmovups %ymm2,-0x24d0(%rbp)
 11ec136:	ff 
 11ec137:	c5 fc 11 8d 10 db ff 	vmovups %ymm1,-0x24f0(%rbp)
 11ec13e:	ff 
 11ec13f:	c5 fc 11 85 f0 da ff 	vmovups %ymm0,-0x2510(%rbp)
 11ec146:	ff 
 11ec147:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ec14e:	ff 
 11ec14f:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ec156:	ff 
 11ec157:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ec15e:	ff 
 11ec15f:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ec166:	ff 
 11ec167:	c5 fc 11 85 40 f6 ff 	vmovups %ymm0,-0x9c0(%rbp)
 11ec16e:	ff 
 11ec16f:	c5 fc 11 8d 60 f6 ff 	vmovups %ymm1,-0x9a0(%rbp)
 11ec176:	ff 
 11ec177:	c5 fc 11 95 80 f6 ff 	vmovups %ymm2,-0x980(%rbp)
 11ec17e:	ff 
 11ec17f:	c5 fc 11 9d a0 f6 ff 	vmovups %ymm3,-0x960(%rbp)
 11ec186:	ff 
 11ec187:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ec18e:	ff 
 11ec18f:	c5 fc 11 85 b0 f6 ff 	vmovups %ymm0,-0x950(%rbp)
 11ec196:	ff 
 11ec197:	c6 85 58 db ff ff 01 	movb   $0x1,-0x24a8(%rbp)
 11ec19e:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ec1a5:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ec1aa:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ec1b1:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ec1b6:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ec1ba:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ec1c0:	48 8d 85 f0 da ff ff 	lea    -0x2510(%rbp),%rax
 11ec1c7:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ec1cc:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ec1d1:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ec1d5:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ec1da:	48 8d 85 40 f6 ff ff 	lea    -0x9c0(%rbp),%rax
 11ec1e1:	48 89 04 24          	mov    %rax,(%rsp)
 11ec1e5:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ec1ec:	00 00 
 11ec1ee:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ec1f5:	00 00 
 11ec1f7:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ec1fb:	4c 89 ee             	mov    %r13,%rsi
 11ec1fe:	c5 f8 77             	vzeroupper 
 11ec201:	e8 ea 43 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ec206:	44 0f b7 7d b0       	movzwl -0x50(%rbp),%r15d
 11ec20b:	66 45 85 ff          	test   %r15w,%r15w
 11ec20f:	0f 85 d4 2b 00 00    	jne    11eede9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3dc9>
 11ec215:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ec219:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ec21d:	49 39 df             	cmp    %rbx,%r15
 11ec220:	0f 83 20 02 00 00    	jae    11ec446 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1426>
 11ec226:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec22a:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec22e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec232:	4c 89 f6             	mov    %r14,%rsi
 11ec235:	48 89 da             	mov    %rbx,%rdx
 11ec238:	31 c9                	xor    %ecx,%ecx
 11ec23a:	ff 50 18             	call   *0x18(%rax)
 11ec23d:	c5 fc 10 85 b0 f6 ff 	vmovups -0x950(%rbp),%ymm0
 11ec244:	ff 
 11ec245:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ec24c:	ff 
 11ec24d:	c5 fc 10 85 40 f6 ff 	vmovups -0x9c0(%rbp),%ymm0
 11ec254:	ff 
 11ec255:	c5 fc 10 8d 60 f6 ff 	vmovups -0x9a0(%rbp),%ymm1
 11ec25c:	ff 
 11ec25d:	c5 fc 10 95 80 f6 ff 	vmovups -0x980(%rbp),%ymm2
 11ec264:	ff 
 11ec265:	c5 fc 10 9d a0 f6 ff 	vmovups -0x960(%rbp),%ymm3
 11ec26c:	ff 
 11ec26d:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ec274:	ff 
 11ec275:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ec27c:	ff 
 11ec27d:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ec284:	ff 
 11ec285:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ec28c:	ff 
 11ec28d:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ec291:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ec295:	80 bd 23 ff ff ff 00 	cmpb   $0x0,-0xdd(%rbp)
 11ec29c:	75 18                	jne    11ec2b6 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1296>
 11ec29e:	e9 da 01 00 00       	jmp    11ec47d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x145d>
 11ec2a3:	4d 89 f4             	mov    %r14,%r12
 11ec2a6:	49 89 df             	mov    %rbx,%r15
 11ec2a9:	80 bd 23 ff ff ff 00 	cmpb   $0x0,-0xdd(%rbp)
 11ec2b0:	0f 84 c7 01 00 00    	je     11ec47d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x145d>
 11ec2b6:	48 8b 85 40 fb ff ff 	mov    -0x4c0(%rbp),%rax
 11ec2bd:	48 89 85 e0 da ff ff 	mov    %rax,-0x2520(%rbp)
 11ec2c4:	c5 fc 10 85 e0 fa ff 	vmovups -0x520(%rbp),%ymm0
 11ec2cb:	ff 
 11ec2cc:	c5 fc 10 8d 00 fb ff 	vmovups -0x500(%rbp),%ymm1
 11ec2d3:	ff 
 11ec2d4:	c5 fc 10 95 20 fb ff 	vmovups -0x4e0(%rbp),%ymm2
 11ec2db:	ff 
 11ec2dc:	c5 fc 11 95 c0 da ff 	vmovups %ymm2,-0x2540(%rbp)
 11ec2e3:	ff 
 11ec2e4:	c5 fc 11 8d a0 da ff 	vmovups %ymm1,-0x2560(%rbp)
 11ec2eb:	ff 
 11ec2ec:	c5 fc 11 85 80 da ff 	vmovups %ymm0,-0x2580(%rbp)
 11ec2f3:	ff 
 11ec2f4:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ec2fb:	ff 
 11ec2fc:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ec303:	ff 
 11ec304:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ec30b:	ff 
 11ec30c:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ec313:	ff 
 11ec314:	c5 fc 11 85 b0 f5 ff 	vmovups %ymm0,-0xa50(%rbp)
 11ec31b:	ff 
 11ec31c:	c5 fc 11 8d d0 f5 ff 	vmovups %ymm1,-0xa30(%rbp)
 11ec323:	ff 
 11ec324:	c5 fc 11 95 f0 f5 ff 	vmovups %ymm2,-0xa10(%rbp)
 11ec32b:	ff 
 11ec32c:	c5 fc 11 9d 10 f6 ff 	vmovups %ymm3,-0x9f0(%rbp)
 11ec333:	ff 
 11ec334:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ec33b:	ff 
 11ec33c:	c5 fc 11 85 20 f6 ff 	vmovups %ymm0,-0x9e0(%rbp)
 11ec343:	ff 
 11ec344:	c6 85 e8 da ff ff 01 	movb   $0x1,-0x2518(%rbp)
 11ec34b:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ec352:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ec357:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ec35e:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ec363:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ec367:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ec36d:	48 8d 85 80 da ff ff 	lea    -0x2580(%rbp),%rax
 11ec374:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ec379:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ec37e:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ec382:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ec387:	48 8d 85 b0 f5 ff ff 	lea    -0xa50(%rbp),%rax
 11ec38e:	48 89 04 24          	mov    %rax,(%rsp)
 11ec392:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ec399:	00 00 
 11ec39b:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ec3a2:	00 00 
 11ec3a4:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ec3a8:	4c 89 ee             	mov    %r13,%rsi
 11ec3ab:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ec3af:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ec3b3:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ec3b7:	c5 f8 77             	vzeroupper 
 11ec3ba:	e8 31 42 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ec3bf:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ec3c3:	66 85 db             	test   %bx,%bx
 11ec3c6:	0f 85 13 2b 00 00    	jne    11eeedf <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3ebf>
 11ec3cc:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11ec3d0:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 11ec3d4:	4c 39 fb             	cmp    %r15,%rbx
 11ec3d7:	0f 83 a8 00 00 00    	jae    11ec485 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1465>
 11ec3dd:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec3e1:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec3e5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec3e9:	4c 89 e6             	mov    %r12,%rsi
 11ec3ec:	4c 89 fa             	mov    %r15,%rdx
 11ec3ef:	31 c9                	xor    %ecx,%ecx
 11ec3f1:	ff 50 18             	call   *0x18(%rax)
 11ec3f4:	c5 fc 10 85 20 f6 ff 	vmovups -0x9e0(%rbp),%ymm0
 11ec3fb:	ff 
 11ec3fc:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ec403:	ff 
 11ec404:	c5 fc 10 85 b0 f5 ff 	vmovups -0xa50(%rbp),%ymm0
 11ec40b:	ff 
 11ec40c:	c5 fc 10 8d d0 f5 ff 	vmovups -0xa30(%rbp),%ymm1
 11ec413:	ff 
 11ec414:	c5 fc 10 95 f0 f5 ff 	vmovups -0xa10(%rbp),%ymm2
 11ec41b:	ff 
 11ec41c:	c5 fc 10 9d 10 f6 ff 	vmovups -0x9f0(%rbp),%ymm3
 11ec423:	ff 
 11ec424:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ec42b:	ff 
 11ec42c:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ec433:	ff 
 11ec434:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ec43b:	ff 
 11ec43c:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ec443:	ff 
 11ec444:	eb 61                	jmp    11ec4a7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1487>
 11ec446:	4d 85 ff             	test   %r15,%r15
 11ec449:	74 17                	je     11ec462 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1442>
 11ec44b:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec44f:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec453:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec457:	4c 89 e6             	mov    %r12,%rsi
 11ec45a:	4c 89 fa             	mov    %r15,%rdx
 11ec45d:	31 c9                	xor    %ecx,%ecx
 11ec45f:	ff 50 18             	call   *0x18(%rax)
 11ec462:	4d 89 f4             	mov    %r14,%r12
 11ec465:	49 89 df             	mov    %rbx,%r15
 11ec468:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ec46c:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ec470:	80 bd 23 ff ff ff 00 	cmpb   $0x0,-0xdd(%rbp)
 11ec477:	0f 85 39 fe ff ff    	jne    11ec2b6 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1296>
 11ec47d:	4d 89 e6             	mov    %r12,%r14
 11ec480:	4c 89 fb             	mov    %r15,%rbx
 11ec483:	eb 2a                	jmp    11ec4af <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x148f>
 11ec485:	48 85 db             	test   %rbx,%rbx
 11ec488:	74 17                	je     11ec4a1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1481>
 11ec48a:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec48e:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec492:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec496:	4c 89 f6             	mov    %r14,%rsi
 11ec499:	48 89 da             	mov    %rbx,%rdx
 11ec49c:	31 c9                	xor    %ecx,%ecx
 11ec49e:	ff 50 18             	call   *0x18(%rax)
 11ec4a1:	4d 89 e6             	mov    %r12,%r14
 11ec4a4:	4c 89 fb             	mov    %r15,%rbx
 11ec4a7:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ec4ab:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ec4af:	80 bd 24 ff ff ff 00 	cmpb   $0x0,-0xdc(%rbp)
 11ec4b6:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ec4ba:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ec4be:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ec4c2:	0f 84 9a 01 00 00    	je     11ec662 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1642>
 11ec4c8:	48 8b 85 b0 fb ff ff 	mov    -0x450(%rbp),%rax
 11ec4cf:	48 89 85 70 da ff ff 	mov    %rax,-0x2590(%rbp)
 11ec4d6:	c5 fc 10 85 50 fb ff 	vmovups -0x4b0(%rbp),%ymm0
 11ec4dd:	ff 
 11ec4de:	c5 fc 10 8d 70 fb ff 	vmovups -0x490(%rbp),%ymm1
 11ec4e5:	ff 
 11ec4e6:	c5 fc 10 95 90 fb ff 	vmovups -0x470(%rbp),%ymm2
 11ec4ed:	ff 
 11ec4ee:	c5 fc 11 95 50 da ff 	vmovups %ymm2,-0x25b0(%rbp)
 11ec4f5:	ff 
 11ec4f6:	c5 fc 11 8d 30 da ff 	vmovups %ymm1,-0x25d0(%rbp)
 11ec4fd:	ff 
 11ec4fe:	c5 fc 11 85 10 da ff 	vmovups %ymm0,-0x25f0(%rbp)
 11ec505:	ff 
 11ec506:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ec50d:	ff 
 11ec50e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ec515:	ff 
 11ec516:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ec51d:	ff 
 11ec51e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ec525:	ff 
 11ec526:	c5 fc 11 85 20 f5 ff 	vmovups %ymm0,-0xae0(%rbp)
 11ec52d:	ff 
 11ec52e:	c5 fc 11 8d 40 f5 ff 	vmovups %ymm1,-0xac0(%rbp)
 11ec535:	ff 
 11ec536:	c5 fc 11 95 60 f5 ff 	vmovups %ymm2,-0xaa0(%rbp)
 11ec53d:	ff 
 11ec53e:	c5 fc 11 9d 80 f5 ff 	vmovups %ymm3,-0xa80(%rbp)
 11ec545:	ff 
 11ec546:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ec54d:	ff 
 11ec54e:	c5 fc 11 85 90 f5 ff 	vmovups %ymm0,-0xa70(%rbp)
 11ec555:	ff 
 11ec556:	c6 85 78 da ff ff 01 	movb   $0x1,-0x2588(%rbp)
 11ec55d:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ec564:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ec569:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ec570:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ec575:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ec579:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ec57f:	48 8d 85 10 da ff ff 	lea    -0x25f0(%rbp),%rax
 11ec586:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ec58b:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ec590:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ec594:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ec599:	48 8d 85 20 f5 ff ff 	lea    -0xae0(%rbp),%rax
 11ec5a0:	48 89 04 24          	mov    %rax,(%rsp)
 11ec5a4:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ec5ab:	00 00 
 11ec5ad:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ec5b4:	00 00 
 11ec5b6:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ec5ba:	4c 89 ee             	mov    %r13,%rsi
 11ec5bd:	c5 f8 77             	vzeroupper 
 11ec5c0:	e8 2b 40 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ec5c5:	44 0f b7 7d b0       	movzwl -0x50(%rbp),%r15d
 11ec5ca:	66 45 85 ff          	test   %r15w,%r15w
 11ec5ce:	0f 85 01 2a 00 00    	jne    11eefd5 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3fb5>
 11ec5d4:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ec5d8:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ec5dc:	49 39 df             	cmp    %rbx,%r15
 11ec5df:	0f 83 20 02 00 00    	jae    11ec805 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x17e5>
 11ec5e5:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec5e9:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec5ed:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec5f1:	4c 89 f6             	mov    %r14,%rsi
 11ec5f4:	48 89 da             	mov    %rbx,%rdx
 11ec5f7:	31 c9                	xor    %ecx,%ecx
 11ec5f9:	ff 50 18             	call   *0x18(%rax)
 11ec5fc:	c5 fc 10 85 90 f5 ff 	vmovups -0xa70(%rbp),%ymm0
 11ec603:	ff 
 11ec604:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ec60b:	ff 
 11ec60c:	c5 fc 10 85 20 f5 ff 	vmovups -0xae0(%rbp),%ymm0
 11ec613:	ff 
 11ec614:	c5 fc 10 8d 40 f5 ff 	vmovups -0xac0(%rbp),%ymm1
 11ec61b:	ff 
 11ec61c:	c5 fc 10 95 60 f5 ff 	vmovups -0xaa0(%rbp),%ymm2
 11ec623:	ff 
 11ec624:	c5 fc 10 9d 80 f5 ff 	vmovups -0xa80(%rbp),%ymm3
 11ec62b:	ff 
 11ec62c:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ec633:	ff 
 11ec634:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ec63b:	ff 
 11ec63c:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ec643:	ff 
 11ec644:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ec64b:	ff 
 11ec64c:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ec650:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ec654:	80 bd 25 ff ff ff 00 	cmpb   $0x0,-0xdb(%rbp)
 11ec65b:	75 18                	jne    11ec675 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1655>
 11ec65d:	e9 da 01 00 00       	jmp    11ec83c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x181c>
 11ec662:	4d 89 f4             	mov    %r14,%r12
 11ec665:	49 89 df             	mov    %rbx,%r15
 11ec668:	80 bd 25 ff ff ff 00 	cmpb   $0x0,-0xdb(%rbp)
 11ec66f:	0f 84 c7 01 00 00    	je     11ec83c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x181c>
 11ec675:	48 8b 85 20 fc ff ff 	mov    -0x3e0(%rbp),%rax
 11ec67c:	48 89 85 00 da ff ff 	mov    %rax,-0x2600(%rbp)
 11ec683:	c5 fc 10 85 c0 fb ff 	vmovups -0x440(%rbp),%ymm0
 11ec68a:	ff 
 11ec68b:	c5 fc 10 8d e0 fb ff 	vmovups -0x420(%rbp),%ymm1
 11ec692:	ff 
 11ec693:	c5 fc 10 95 00 fc ff 	vmovups -0x400(%rbp),%ymm2
 11ec69a:	ff 
 11ec69b:	c5 fc 11 95 e0 d9 ff 	vmovups %ymm2,-0x2620(%rbp)
 11ec6a2:	ff 
 11ec6a3:	c5 fc 11 8d c0 d9 ff 	vmovups %ymm1,-0x2640(%rbp)
 11ec6aa:	ff 
 11ec6ab:	c5 fc 11 85 a0 d9 ff 	vmovups %ymm0,-0x2660(%rbp)
 11ec6b2:	ff 
 11ec6b3:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ec6ba:	ff 
 11ec6bb:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ec6c2:	ff 
 11ec6c3:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ec6ca:	ff 
 11ec6cb:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ec6d2:	ff 
 11ec6d3:	c5 fc 11 85 90 f4 ff 	vmovups %ymm0,-0xb70(%rbp)
 11ec6da:	ff 
 11ec6db:	c5 fc 11 8d b0 f4 ff 	vmovups %ymm1,-0xb50(%rbp)
 11ec6e2:	ff 
 11ec6e3:	c5 fc 11 95 d0 f4 ff 	vmovups %ymm2,-0xb30(%rbp)
 11ec6ea:	ff 
 11ec6eb:	c5 fc 11 9d f0 f4 ff 	vmovups %ymm3,-0xb10(%rbp)
 11ec6f2:	ff 
 11ec6f3:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ec6fa:	ff 
 11ec6fb:	c5 fc 11 85 00 f5 ff 	vmovups %ymm0,-0xb00(%rbp)
 11ec702:	ff 
 11ec703:	c6 85 08 da ff ff 01 	movb   $0x1,-0x25f8(%rbp)
 11ec70a:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ec711:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ec716:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ec71d:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ec722:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ec726:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ec72c:	48 8d 85 a0 d9 ff ff 	lea    -0x2660(%rbp),%rax
 11ec733:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ec738:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ec73d:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ec741:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ec746:	48 8d 85 90 f4 ff ff 	lea    -0xb70(%rbp),%rax
 11ec74d:	48 89 04 24          	mov    %rax,(%rsp)
 11ec751:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ec758:	00 00 
 11ec75a:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ec761:	00 00 
 11ec763:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ec767:	4c 89 ee             	mov    %r13,%rsi
 11ec76a:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ec76e:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ec772:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ec776:	c5 f8 77             	vzeroupper 
 11ec779:	e8 72 3e 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ec77e:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ec782:	66 85 db             	test   %bx,%bx
 11ec785:	0f 85 40 29 00 00    	jne    11ef0cb <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x40ab>
 11ec78b:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11ec78f:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 11ec793:	4c 39 fb             	cmp    %r15,%rbx
 11ec796:	0f 83 a8 00 00 00    	jae    11ec844 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1824>
 11ec79c:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec7a0:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec7a4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec7a8:	4c 89 e6             	mov    %r12,%rsi
 11ec7ab:	4c 89 fa             	mov    %r15,%rdx
 11ec7ae:	31 c9                	xor    %ecx,%ecx
 11ec7b0:	ff 50 18             	call   *0x18(%rax)
 11ec7b3:	c5 fc 10 85 00 f5 ff 	vmovups -0xb00(%rbp),%ymm0
 11ec7ba:	ff 
 11ec7bb:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ec7c2:	ff 
 11ec7c3:	c5 fc 10 85 90 f4 ff 	vmovups -0xb70(%rbp),%ymm0
 11ec7ca:	ff 
 11ec7cb:	c5 fc 10 8d b0 f4 ff 	vmovups -0xb50(%rbp),%ymm1
 11ec7d2:	ff 
 11ec7d3:	c5 fc 10 95 d0 f4 ff 	vmovups -0xb30(%rbp),%ymm2
 11ec7da:	ff 
 11ec7db:	c5 fc 10 9d f0 f4 ff 	vmovups -0xb10(%rbp),%ymm3
 11ec7e2:	ff 
 11ec7e3:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ec7ea:	ff 
 11ec7eb:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ec7f2:	ff 
 11ec7f3:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ec7fa:	ff 
 11ec7fb:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ec802:	ff 
 11ec803:	eb 61                	jmp    11ec866 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1846>
 11ec805:	4d 85 ff             	test   %r15,%r15
 11ec808:	74 17                	je     11ec821 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1801>
 11ec80a:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec80e:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec812:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec816:	4c 89 e6             	mov    %r12,%rsi
 11ec819:	4c 89 fa             	mov    %r15,%rdx
 11ec81c:	31 c9                	xor    %ecx,%ecx
 11ec81e:	ff 50 18             	call   *0x18(%rax)
 11ec821:	4d 89 f4             	mov    %r14,%r12
 11ec824:	49 89 df             	mov    %rbx,%r15
 11ec827:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ec82b:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ec82f:	80 bd 25 ff ff ff 00 	cmpb   $0x0,-0xdb(%rbp)
 11ec836:	0f 85 39 fe ff ff    	jne    11ec675 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1655>
 11ec83c:	4d 89 e6             	mov    %r12,%r14
 11ec83f:	4c 89 fb             	mov    %r15,%rbx
 11ec842:	eb 2a                	jmp    11ec86e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x184e>
 11ec844:	48 85 db             	test   %rbx,%rbx
 11ec847:	74 17                	je     11ec860 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1840>
 11ec849:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec84d:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec851:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec855:	4c 89 f6             	mov    %r14,%rsi
 11ec858:	48 89 da             	mov    %rbx,%rdx
 11ec85b:	31 c9                	xor    %ecx,%ecx
 11ec85d:	ff 50 18             	call   *0x18(%rax)
 11ec860:	4d 89 e6             	mov    %r12,%r14
 11ec863:	4c 89 fb             	mov    %r15,%rbx
 11ec866:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ec86a:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ec86e:	80 7d 8f 00          	cmpb   $0x0,-0x71(%rbp)
 11ec872:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ec876:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ec87a:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ec87e:	0f 84 89 01 00 00    	je     11eca0d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x19ed>
 11ec884:	48 8b 85 90 fc ff ff 	mov    -0x370(%rbp),%rax
 11ec88b:	48 89 85 90 d9 ff ff 	mov    %rax,-0x2670(%rbp)
 11ec892:	c5 fc 10 85 30 fc ff 	vmovups -0x3d0(%rbp),%ymm0
 11ec899:	ff 
 11ec89a:	c5 fc 10 8d 50 fc ff 	vmovups -0x3b0(%rbp),%ymm1
 11ec8a1:	ff 
 11ec8a2:	c5 fc 10 95 70 fc ff 	vmovups -0x390(%rbp),%ymm2
 11ec8a9:	ff 
 11ec8aa:	c5 fc 11 95 70 d9 ff 	vmovups %ymm2,-0x2690(%rbp)
 11ec8b1:	ff 
 11ec8b2:	c5 fc 11 8d 50 d9 ff 	vmovups %ymm1,-0x26b0(%rbp)
 11ec8b9:	ff 
 11ec8ba:	c5 fc 11 85 30 d9 ff 	vmovups %ymm0,-0x26d0(%rbp)
 11ec8c1:	ff 
 11ec8c2:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ec8c9:	ff 
 11ec8ca:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ec8d1:	ff 
 11ec8d2:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ec8d9:	ff 
 11ec8da:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ec8e1:	ff 
 11ec8e2:	c5 fc 11 85 00 f4 ff 	vmovups %ymm0,-0xc00(%rbp)
 11ec8e9:	ff 
 11ec8ea:	c5 fc 11 8d 20 f4 ff 	vmovups %ymm1,-0xbe0(%rbp)
 11ec8f1:	ff 
 11ec8f2:	c5 fc 11 95 40 f4 ff 	vmovups %ymm2,-0xbc0(%rbp)
 11ec8f9:	ff 
 11ec8fa:	c5 fc 11 9d 60 f4 ff 	vmovups %ymm3,-0xba0(%rbp)
 11ec901:	ff 
 11ec902:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ec909:	ff 
 11ec90a:	c5 fc 11 85 70 f4 ff 	vmovups %ymm0,-0xb90(%rbp)
 11ec911:	ff 
 11ec912:	c6 85 98 d9 ff ff 01 	movb   $0x1,-0x2668(%rbp)
 11ec919:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ec920:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ec925:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ec92c:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ec931:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ec935:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ec93b:	48 8d 85 30 d9 ff ff 	lea    -0x26d0(%rbp),%rax
 11ec942:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ec947:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ec94c:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ec950:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ec955:	48 8d 85 00 f4 ff ff 	lea    -0xc00(%rbp),%rax
 11ec95c:	48 89 04 24          	mov    %rax,(%rsp)
 11ec960:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ec967:	00 00 
 11ec969:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ec970:	00 00 
 11ec972:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ec976:	4c 89 ee             	mov    %r13,%rsi
 11ec979:	c5 f8 77             	vzeroupper 
 11ec97c:	e8 6f 3c 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ec981:	44 0f b7 7d b0       	movzwl -0x50(%rbp),%r15d
 11ec986:	66 45 85 ff          	test   %r15w,%r15w
 11ec98a:	0f 85 31 28 00 00    	jne    11ef1c1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x41a1>
 11ec990:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ec994:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ec998:	49 39 df             	cmp    %rbx,%r15
 11ec99b:	0f 83 f4 01 00 00    	jae    11ecb95 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1b75>
 11ec9a1:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ec9a5:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ec9a9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ec9ad:	4c 89 f6             	mov    %r14,%rsi
 11ec9b0:	48 89 da             	mov    %rbx,%rdx
 11ec9b3:	31 c9                	xor    %ecx,%ecx
 11ec9b5:	ff 50 18             	call   *0x18(%rax)
 11ec9b8:	c5 fc 10 85 70 f4 ff 	vmovups -0xb90(%rbp),%ymm0
 11ec9bf:	ff 
 11ec9c0:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ec9c7:	ff 
 11ec9c8:	c5 fc 10 85 00 f4 ff 	vmovups -0xc00(%rbp),%ymm0
 11ec9cf:	ff 
 11ec9d0:	c5 fc 10 8d 20 f4 ff 	vmovups -0xbe0(%rbp),%ymm1
 11ec9d7:	ff 
 11ec9d8:	c5 fc 10 95 40 f4 ff 	vmovups -0xbc0(%rbp),%ymm2
 11ec9df:	ff 
 11ec9e0:	c5 fc 10 9d 60 f4 ff 	vmovups -0xba0(%rbp),%ymm3
 11ec9e7:	ff 
 11ec9e8:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ec9ef:	ff 
 11ec9f0:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ec9f7:	ff 
 11ec9f8:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ec9ff:	ff 
 11eca00:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11eca07:	ff 
 11eca08:	e9 aa 01 00 00       	jmp    11ecbb7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1b97>
 11eca0d:	4d 89 f4             	mov    %r14,%r12
 11eca10:	49 89 df             	mov    %rbx,%r15
 11eca13:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eca1a:	0f 95 c0             	setne  %al
 11eca1d:	84 45 c6             	test   %al,-0x3a(%rbp)
 11eca20:	0f 85 ac 01 00 00    	jne    11ecbd2 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1bb2>
 11eca26:	4d 89 e6             	mov    %r12,%r14
 11eca29:	4d 89 fd             	mov    %r15,%r13
 11eca2c:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11eca33:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11eca37:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11eca3b:	0f 84 96 05 00 00    	je     11ecfd7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1fb7>
 11eca41:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11eca48:	ff 
 11eca49:	c5 fc 11 85 50 f3 ff 	vmovups %ymm0,-0xcb0(%rbp)
 11eca50:	ff 
 11eca51:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11eca58:	ff 
 11eca59:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11eca60:	ff 
 11eca61:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11eca68:	ff 
 11eca69:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11eca70:	ff 
 11eca71:	c5 fc 11 9d 40 f3 ff 	vmovups %ymm3,-0xcc0(%rbp)
 11eca78:	ff 
 11eca79:	c5 fc 11 95 20 f3 ff 	vmovups %ymm2,-0xce0(%rbp)
 11eca80:	ff 
 11eca81:	c5 fc 11 8d 00 f3 ff 	vmovups %ymm1,-0xd00(%rbp)
 11eca88:	ff 
 11eca89:	c5 fc 11 85 e0 f2 ff 	vmovups %ymm0,-0xd20(%rbp)
 11eca90:	ff 
 11eca91:	48 8d 05 40 e4 e4 ff 	lea    -0x1b1bc0(%rip),%rax        # 103aed8 <__anon_35267>
 11eca98:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11eca9d:	48 8d 05 c4 e3 e4 ff 	lea    -0x1b1c3c(%rip),%rax        # 103ae68 <__anon_35266>
 11ecaa4:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ecaa9:	48 8d 85 30 fe ff ff 	lea    -0x1d0(%rbp),%rax
 11ecab0:	48 89 44 24 28       	mov    %rax,0x28(%rsp)
 11ecab5:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 11ecaba:	48 8d 05 37 e3 e4 ff 	lea    -0x1b1cc9(%rip),%rax        # 103adf8 <__anon_35263>
 11ecac1:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ecac6:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ecacb:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ecacf:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ecad4:	48 8d 85 e0 f2 ff ff 	lea    -0xd20(%rbp),%rax
 11ecadb:	48 89 04 24          	mov    %rax,(%rsp)
 11ecadf:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ecae6:	00 00 
 11ecae8:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ecaef:	00 00 
 11ecaf1:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ecaf5:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11ecaf9:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ecafd:	4d 89 cf             	mov    %r9,%r15
 11ecb00:	c5 f8 77             	vzeroupper 
 11ecb03:	e8 e8 3a 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ecb08:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ecb0c:	66 85 db             	test   %bx,%bx
 11ecb0f:	0f 85 a2 27 00 00    	jne    11ef2b7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4297>
 11ecb15:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ecb19:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 11ecb1d:	4c 39 eb             	cmp    %r13,%rbx
 11ecb20:	0f 83 08 02 00 00    	jae    11ecd2e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1d0e>
 11ecb26:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ecb2a:	48 8b 38             	mov    (%rax),%rdi
 11ecb2d:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ecb31:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ecb35:	4c 89 f6             	mov    %r14,%rsi
 11ecb38:	4c 89 ea             	mov    %r13,%rdx
 11ecb3b:	31 c9                	xor    %ecx,%ecx
 11ecb3d:	ff 50 18             	call   *0x18(%rax)
 11ecb40:	c5 fc 10 85 50 f3 ff 	vmovups -0xcb0(%rbp),%ymm0
 11ecb47:	ff 
 11ecb48:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ecb4f:	ff 
 11ecb50:	c5 fc 10 85 e0 f2 ff 	vmovups -0xd20(%rbp),%ymm0
 11ecb57:	ff 
 11ecb58:	c5 fc 10 8d 00 f3 ff 	vmovups -0xd00(%rbp),%ymm1
 11ecb5f:	ff 
 11ecb60:	c5 fc 10 95 20 f3 ff 	vmovups -0xce0(%rbp),%ymm2
 11ecb67:	ff 
 11ecb68:	c5 fc 10 9d 40 f3 ff 	vmovups -0xcc0(%rbp),%ymm3
 11ecb6f:	ff 
 11ecb70:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ecb77:	ff 
 11ecb78:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ecb7f:	ff 
 11ecb80:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ecb87:	ff 
 11ecb88:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ecb8f:	ff 
 11ecb90:	e9 be 01 00 00       	jmp    11ecd53 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1d33>
 11ecb95:	4d 85 ff             	test   %r15,%r15
 11ecb98:	74 17                	je     11ecbb1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1b91>
 11ecb9a:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ecb9e:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ecba2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ecba6:	4c 89 e6             	mov    %r12,%rsi
 11ecba9:	4c 89 fa             	mov    %r15,%rdx
 11ecbac:	31 c9                	xor    %ecx,%ecx
 11ecbae:	ff 50 18             	call   *0x18(%rax)
 11ecbb1:	4d 89 f4             	mov    %r14,%r12
 11ecbb4:	49 89 df             	mov    %rbx,%r15
 11ecbb7:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ecbbb:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ecbbf:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ecbc6:	0f 95 c0             	setne  %al
 11ecbc9:	84 45 c6             	test   %al,-0x3a(%rbp)
 11ecbcc:	0f 84 54 fe ff ff    	je     11eca26 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1a06>
 11ecbd2:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ecbd9:	ff 
 11ecbda:	c5 fc 11 85 e0 f3 ff 	vmovups %ymm0,-0xc20(%rbp)
 11ecbe1:	ff 
 11ecbe2:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ecbe9:	ff 
 11ecbea:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ecbf1:	ff 
 11ecbf2:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ecbf9:	ff 
 11ecbfa:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ecc01:	ff 
 11ecc02:	c5 fc 11 9d d0 f3 ff 	vmovups %ymm3,-0xc30(%rbp)
 11ecc09:	ff 
 11ecc0a:	c5 fc 11 95 b0 f3 ff 	vmovups %ymm2,-0xc50(%rbp)
 11ecc11:	ff 
 11ecc12:	c5 fc 11 8d 90 f3 ff 	vmovups %ymm1,-0xc70(%rbp)
 11ecc19:	ff 
 11ecc1a:	c5 fc 11 85 70 f3 ff 	vmovups %ymm0,-0xc90(%rbp)
 11ecc21:	ff 
 11ecc22:	48 8d 05 af e2 e4 ff 	lea    -0x1b1d51(%rip),%rax        # 103aed8 <__anon_35267>
 11ecc29:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ecc2e:	48 8d 05 33 e2 e4 ff 	lea    -0x1b1dcd(%rip),%rax        # 103ae68 <__anon_35266>
 11ecc35:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ecc3a:	48 8d 85 30 ff ff ff 	lea    -0xd0(%rbp),%rax
 11ecc41:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 11ecc46:	48 8d 05 ab e1 e4 ff 	lea    -0x1b1e55(%rip),%rax        # 103adf8 <__anon_35263>
 11ecc4d:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ecc52:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ecc57:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ecc5b:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ecc60:	48 8d 85 70 f3 ff ff 	lea    -0xc90(%rbp),%rax
 11ecc67:	48 89 04 24          	mov    %rax,(%rsp)
 11ecc6b:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ecc72:	00 00 
 11ecc74:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ecc7b:	00 00 
 11ecc7d:	48 c7 44 24 28 00 00 	movq   $0x0,0x28(%rsp)
 11ecc84:	00 00 
 11ecc86:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ecc8a:	4c 89 ee             	mov    %r13,%rsi
 11ecc8d:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ecc91:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ecc95:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ecc99:	c5 f8 77             	vzeroupper 
 11ecc9c:	e8 4f 39 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ecca1:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ecca5:	66 85 db             	test   %bx,%bx
 11ecca8:	0f 85 ae 31 00 00    	jne    11efe5c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4e3c>
 11eccae:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11eccb2:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 11eccb6:	4d 39 fd             	cmp    %r15,%r13
 11eccb9:	0f 83 d6 02 00 00    	jae    11ecf95 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f75>
 11eccbf:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eccc3:	48 8b 38             	mov    (%rax),%rdi
 11eccc6:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eccca:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eccce:	4c 89 e6             	mov    %r12,%rsi
 11eccd1:	4c 89 fa             	mov    %r15,%rdx
 11eccd4:	31 c9                	xor    %ecx,%ecx
 11eccd6:	ff 50 18             	call   *0x18(%rax)
 11eccd9:	c5 fc 10 85 e0 f3 ff 	vmovups -0xc20(%rbp),%ymm0
 11ecce0:	ff 
 11ecce1:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ecce8:	ff 
 11ecce9:	c5 fc 10 85 70 f3 ff 	vmovups -0xc90(%rbp),%ymm0
 11eccf0:	ff 
 11eccf1:	c5 fc 10 8d 90 f3 ff 	vmovups -0xc70(%rbp),%ymm1
 11eccf8:	ff 
 11eccf9:	c5 fc 10 95 b0 f3 ff 	vmovups -0xc50(%rbp),%ymm2
 11ecd00:	ff 
 11ecd01:	c5 fc 10 9d d0 f3 ff 	vmovups -0xc30(%rbp),%ymm3
 11ecd08:	ff 
 11ecd09:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ecd10:	ff 
 11ecd11:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ecd18:	ff 
 11ecd19:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ecd20:	ff 
 11ecd21:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ecd28:	ff 
 11ecd29:	e9 8c 02 00 00       	jmp    11ecfba <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f9a>
 11ecd2e:	48 85 db             	test   %rbx,%rbx
 11ecd31:	74 1a                	je     11ecd4d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1d2d>
 11ecd33:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ecd37:	48 8b 38             	mov    (%rax),%rdi
 11ecd3a:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ecd3e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ecd42:	4c 89 e6             	mov    %r12,%rsi
 11ecd45:	48 89 da             	mov    %rbx,%rdx
 11ecd48:	31 c9                	xor    %ecx,%ecx
 11ecd4a:	ff 50 18             	call   *0x18(%rax)
 11ecd4d:	4d 89 f4             	mov    %r14,%r12
 11ecd50:	4c 89 eb             	mov    %r13,%rbx
 11ecd53:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ecd57:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ecd5b:	4d 89 f9             	mov    %r15,%r9
 11ecd5e:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ecd62:	80 bd a8 de ff ff 00 	cmpb   $0x0,-0x2158(%rbp)
 11ecd69:	0f 84 7b 02 00 00    	je     11ecfea <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1fca>
 11ecd6f:	48 8b 85 a0 de ff ff 	mov    -0x2160(%rbp),%rax
 11ecd76:	48 89 85 20 d9 ff ff 	mov    %rax,-0x26e0(%rbp)
 11ecd7d:	c5 fc 10 85 40 de ff 	vmovups -0x21c0(%rbp),%ymm0
 11ecd84:	ff 
 11ecd85:	c5 fc 10 8d 60 de ff 	vmovups -0x21a0(%rbp),%ymm1
 11ecd8c:	ff 
 11ecd8d:	c5 fc 10 95 80 de ff 	vmovups -0x2180(%rbp),%ymm2
 11ecd94:	ff 
 11ecd95:	c5 fc 11 95 00 d9 ff 	vmovups %ymm2,-0x2700(%rbp)
 11ecd9c:	ff 
 11ecd9d:	c5 fc 11 8d e0 d8 ff 	vmovups %ymm1,-0x2720(%rbp)
 11ecda4:	ff 
 11ecda5:	c5 fc 11 85 c0 d8 ff 	vmovups %ymm0,-0x2740(%rbp)
 11ecdac:	ff 
 11ecdad:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ecdb4:	ff 
 11ecdb5:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ecdbc:	ff 
 11ecdbd:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ecdc4:	ff 
 11ecdc5:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ecdcc:	ff 
 11ecdcd:	c5 fc 11 85 50 f2 ff 	vmovups %ymm0,-0xdb0(%rbp)
 11ecdd4:	ff 
 11ecdd5:	c5 fc 11 8d 70 f2 ff 	vmovups %ymm1,-0xd90(%rbp)
 11ecddc:	ff 
 11ecddd:	c5 fc 11 95 90 f2 ff 	vmovups %ymm2,-0xd70(%rbp)
 11ecde4:	ff 
 11ecde5:	c5 fc 11 9d b0 f2 ff 	vmovups %ymm3,-0xd50(%rbp)
 11ecdec:	ff 
 11ecded:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ecdf4:	ff 
 11ecdf5:	c5 fc 11 85 c0 f2 ff 	vmovups %ymm0,-0xd40(%rbp)
 11ecdfc:	ff 
 11ecdfd:	c6 85 28 d9 ff ff 01 	movb   $0x1,-0x26d8(%rbp)
 11ece04:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ece0b:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ece10:	48 8d 85 c0 d8 ff ff 	lea    -0x2740(%rbp),%rax
 11ece17:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ece1c:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ece20:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ece26:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ece2d:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ece32:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ece37:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ece3b:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ece40:	48 8d 85 50 f2 ff ff 	lea    -0xdb0(%rbp),%rax
 11ece47:	48 89 04 24          	mov    %rax,(%rsp)
 11ece4b:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ece52:	00 00 
 11ece54:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ece5b:	00 00 
 11ece5d:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ece61:	4c 8b 6d c8          	mov    -0x38(%rbp),%r13
 11ece65:	4c 89 ee             	mov    %r13,%rsi
 11ece68:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ece6c:	c5 f8 77             	vzeroupper 
 11ece6f:	e8 7c 37 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ece74:	44 0f b7 7d b0       	movzwl -0x50(%rbp),%r15d
 11ece79:	66 45 85 ff          	test   %r15w,%r15w
 11ece7d:	0f 85 31 25 00 00    	jne    11ef3b4 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4394>
 11ece83:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11ece87:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ece8b:	49 39 df             	cmp    %rbx,%r15
 11ece8e:	73 7e                	jae    11ecf0e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1eee>
 11ece90:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ece94:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ece98:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ece9c:	4c 89 e6             	mov    %r12,%rsi
 11ece9f:	48 89 da             	mov    %rbx,%rdx
 11ecea2:	31 c9                	xor    %ecx,%ecx
 11ecea4:	ff 50 18             	call   *0x18(%rax)
 11ecea7:	c5 fc 10 85 c0 f2 ff 	vmovups -0xd40(%rbp),%ymm0
 11eceae:	ff 
 11eceaf:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11eceb6:	ff 
 11eceb7:	c5 fc 10 85 50 f2 ff 	vmovups -0xdb0(%rbp),%ymm0
 11ecebe:	ff 
 11ecebf:	c5 fc 10 8d 70 f2 ff 	vmovups -0xd90(%rbp),%ymm1
 11ecec6:	ff 
 11ecec7:	c5 fc 10 95 90 f2 ff 	vmovups -0xd70(%rbp),%ymm2
 11ecece:	ff 
 11ececf:	c5 fc 10 9d b0 f2 ff 	vmovups -0xd50(%rbp),%ymm3
 11eced6:	ff 
 11eced7:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ecede:	ff 
 11ecedf:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ecee6:	ff 
 11ecee7:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11eceee:	ff 
 11eceef:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ecef6:	ff 
 11ecef7:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ecefb:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11eceff:	80 bd 18 df ff ff 00 	cmpb   $0x0,-0x20e8(%rbp)
 11ecf06:	0f 85 f5 00 00 00    	jne    11ed001 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1fe1>
 11ecf0c:	eb 37                	jmp    11ecf45 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f25>
 11ecf0e:	4d 85 ff             	test   %r15,%r15
 11ecf11:	74 17                	je     11ecf2a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f0a>
 11ecf13:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ecf17:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ecf1b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ecf1f:	4c 89 f6             	mov    %r14,%rsi
 11ecf22:	4c 89 fa             	mov    %r15,%rdx
 11ecf25:	31 c9                	xor    %ecx,%ecx
 11ecf27:	ff 50 18             	call   *0x18(%rax)
 11ecf2a:	4d 89 e6             	mov    %r12,%r14
 11ecf2d:	49 89 df             	mov    %rbx,%r15
 11ecf30:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ecf34:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ecf38:	80 bd 18 df ff ff 00 	cmpb   $0x0,-0x20e8(%rbp)
 11ecf3f:	0f 85 bc 00 00 00    	jne    11ed001 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1fe1>
 11ecf45:	4d 89 f5             	mov    %r14,%r13
 11ecf48:	4c 89 fb             	mov    %r15,%rbx
 11ecf4b:	80 bd 88 df ff ff 00 	cmpb   $0x0,-0x2078(%rbp)
 11ecf52:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 11ecf56:	0f 85 72 02 00 00    	jne    11ed1ce <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x21ae>
 11ecf5c:	4d 89 ee             	mov    %r13,%r14
 11ecf5f:	49 89 df             	mov    %rbx,%r15
 11ecf62:	80 bd f8 df ff ff 00 	cmpb   $0x0,-0x2008(%rbp)
 11ecf69:	0f 85 42 04 00 00    	jne    11ed3b1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2391>
 11ecf6f:	4c 89 f3             	mov    %r14,%rbx
 11ecf72:	4d 89 fc             	mov    %r15,%r12
 11ecf75:	80 bd 68 e0 ff ff 00 	cmpb   $0x0,-0x1f98(%rbp)
 11ecf7c:	0f 85 10 06 00 00    	jne    11ed592 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2572>
 11ecf82:	49 89 de             	mov    %rbx,%r14
 11ecf85:	4d 89 e5             	mov    %r12,%r13
 11ecf88:	44 0f b6 bd 80 fd ff 	movzbl -0x280(%rbp),%r15d
 11ecf8f:	ff 
 11ecf90:	e9 c7 07 00 00       	jmp    11ed75c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x273c>
 11ecf95:	4d 85 ed             	test   %r13,%r13
 11ecf98:	74 1a                	je     11ecfb4 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f94>
 11ecf9a:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ecf9e:	48 8b 38             	mov    (%rax),%rdi
 11ecfa1:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ecfa5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ecfa9:	4c 89 f6             	mov    %r14,%rsi
 11ecfac:	4c 89 ea             	mov    %r13,%rdx
 11ecfaf:	31 c9                	xor    %ecx,%ecx
 11ecfb1:	ff 50 18             	call   *0x18(%rax)
 11ecfb4:	4d 89 e6             	mov    %r12,%r14
 11ecfb7:	4d 89 fd             	mov    %r15,%r13
 11ecfba:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ecfbe:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ecfc2:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ecfc9:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ecfcd:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ecfd1:	0f 85 6a fa ff ff    	jne    11eca41 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1a21>
 11ecfd7:	4d 89 f4             	mov    %r14,%r12
 11ecfda:	4c 89 eb             	mov    %r13,%rbx
 11ecfdd:	80 bd a8 de ff ff 00 	cmpb   $0x0,-0x2158(%rbp)
 11ecfe4:	0f 85 85 fd ff ff    	jne    11ecd6f <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1d4f>
 11ecfea:	4d 89 e6             	mov    %r12,%r14
 11ecfed:	49 89 df             	mov    %rbx,%r15
 11ecff0:	4c 8b 6d c8          	mov    -0x38(%rbp),%r13
 11ecff4:	80 bd 18 df ff ff 00 	cmpb   $0x0,-0x20e8(%rbp)
 11ecffb:	0f 84 44 ff ff ff    	je     11ecf45 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f25>
 11ed001:	48 8b 85 10 df ff ff 	mov    -0x20f0(%rbp),%rax
 11ed008:	48 89 85 b0 d8 ff ff 	mov    %rax,-0x2750(%rbp)
 11ed00f:	c5 fc 10 85 b0 de ff 	vmovups -0x2150(%rbp),%ymm0
 11ed016:	ff 
 11ed017:	c5 fc 10 8d d0 de ff 	vmovups -0x2130(%rbp),%ymm1
 11ed01e:	ff 
 11ed01f:	c5 fc 10 95 f0 de ff 	vmovups -0x2110(%rbp),%ymm2
 11ed026:	ff 
 11ed027:	c5 fc 11 95 90 d8 ff 	vmovups %ymm2,-0x2770(%rbp)
 11ed02e:	ff 
 11ed02f:	c5 fc 11 8d 70 d8 ff 	vmovups %ymm1,-0x2790(%rbp)
 11ed036:	ff 
 11ed037:	c5 fc 11 85 50 d8 ff 	vmovups %ymm0,-0x27b0(%rbp)
 11ed03e:	ff 
 11ed03f:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ed046:	ff 
 11ed047:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ed04e:	ff 
 11ed04f:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ed056:	ff 
 11ed057:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ed05e:	ff 
 11ed05f:	c5 fc 11 85 c0 f1 ff 	vmovups %ymm0,-0xe40(%rbp)
 11ed066:	ff 
 11ed067:	c5 fc 11 8d e0 f1 ff 	vmovups %ymm1,-0xe20(%rbp)
 11ed06e:	ff 
 11ed06f:	c5 fc 11 95 00 f2 ff 	vmovups %ymm2,-0xe00(%rbp)
 11ed076:	ff 
 11ed077:	c5 fc 11 9d 20 f2 ff 	vmovups %ymm3,-0xde0(%rbp)
 11ed07e:	ff 
 11ed07f:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ed086:	ff 
 11ed087:	c5 fc 11 85 30 f2 ff 	vmovups %ymm0,-0xdd0(%rbp)
 11ed08e:	ff 
 11ed08f:	c6 85 b8 d8 ff ff 01 	movb   $0x1,-0x2748(%rbp)
 11ed096:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ed09d:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ed0a2:	48 8d 85 50 d8 ff ff 	lea    -0x27b0(%rbp),%rax
 11ed0a9:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ed0ae:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ed0b2:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ed0b8:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ed0bf:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ed0c4:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ed0c9:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ed0cd:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ed0d2:	48 8d 85 c0 f1 ff ff 	lea    -0xe40(%rbp),%rax
 11ed0d9:	48 89 04 24          	mov    %rax,(%rsp)
 11ed0dd:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ed0e4:	00 00 
 11ed0e6:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ed0ed:	00 00 
 11ed0ef:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ed0f3:	4c 89 ee             	mov    %r13,%rsi
 11ed0f6:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ed0fa:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ed0fe:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ed102:	c5 f8 77             	vzeroupper 
 11ed105:	e8 e6 34 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ed10a:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ed10e:	66 85 db             	test   %bx,%bx
 11ed111:	0f 85 96 23 00 00    	jne    11ef4ad <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x448d>
 11ed117:	4c 8b 6d a0          	mov    -0x60(%rbp),%r13
 11ed11b:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 11ed11f:	4c 39 fb             	cmp    %r15,%rbx
 11ed122:	73 6c                	jae    11ed190 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2170>
 11ed124:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed128:	48 8b 38             	mov    (%rax),%rdi
 11ed12b:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed12f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed133:	4c 89 f6             	mov    %r14,%rsi
 11ed136:	4c 89 fa             	mov    %r15,%rdx
 11ed139:	31 c9                	xor    %ecx,%ecx
 11ed13b:	ff 50 18             	call   *0x18(%rax)
 11ed13e:	c5 fc 10 85 30 f2 ff 	vmovups -0xdd0(%rbp),%ymm0
 11ed145:	ff 
 11ed146:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ed14d:	ff 
 11ed14e:	c5 fc 10 85 c0 f1 ff 	vmovups -0xe40(%rbp),%ymm0
 11ed155:	ff 
 11ed156:	c5 fc 10 8d e0 f1 ff 	vmovups -0xe20(%rbp),%ymm1
 11ed15d:	ff 
 11ed15e:	c5 fc 10 95 00 f2 ff 	vmovups -0xe00(%rbp),%ymm2
 11ed165:	ff 
 11ed166:	c5 fc 10 9d 20 f2 ff 	vmovups -0xde0(%rbp),%ymm3
 11ed16d:	ff 
 11ed16e:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ed175:	ff 
 11ed176:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ed17d:	ff 
 11ed17e:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ed185:	ff 
 11ed186:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ed18d:	ff 
 11ed18e:	eb 25                	jmp    11ed1b5 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2195>
 11ed190:	48 85 db             	test   %rbx,%rbx
 11ed193:	74 1a                	je     11ed1af <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x218f>
 11ed195:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed199:	48 8b 38             	mov    (%rax),%rdi
 11ed19c:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed1a0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed1a4:	4c 89 ee             	mov    %r13,%rsi
 11ed1a7:	48 89 da             	mov    %rbx,%rdx
 11ed1aa:	31 c9                	xor    %ecx,%ecx
 11ed1ac:	ff 50 18             	call   *0x18(%rax)
 11ed1af:	4d 89 f5             	mov    %r14,%r13
 11ed1b2:	4c 89 fb             	mov    %r15,%rbx
 11ed1b5:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ed1b9:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ed1bd:	80 bd 88 df ff ff 00 	cmpb   $0x0,-0x2078(%rbp)
 11ed1c4:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 11ed1c8:	0f 84 8e fd ff ff    	je     11ecf5c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f3c>
 11ed1ce:	48 8b 85 80 df ff ff 	mov    -0x2080(%rbp),%rax
 11ed1d5:	48 89 85 40 d8 ff ff 	mov    %rax,-0x27c0(%rbp)
 11ed1dc:	c5 fc 10 85 20 df ff 	vmovups -0x20e0(%rbp),%ymm0
 11ed1e3:	ff 
 11ed1e4:	c5 fc 10 8d 40 df ff 	vmovups -0x20c0(%rbp),%ymm1
 11ed1eb:	ff 
 11ed1ec:	c5 fc 10 95 60 df ff 	vmovups -0x20a0(%rbp),%ymm2
 11ed1f3:	ff 
 11ed1f4:	c5 fc 11 95 20 d8 ff 	vmovups %ymm2,-0x27e0(%rbp)
 11ed1fb:	ff 
 11ed1fc:	c5 fc 11 8d 00 d8 ff 	vmovups %ymm1,-0x2800(%rbp)
 11ed203:	ff 
 11ed204:	c5 fc 11 85 e0 d7 ff 	vmovups %ymm0,-0x2820(%rbp)
 11ed20b:	ff 
 11ed20c:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ed213:	ff 
 11ed214:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ed21b:	ff 
 11ed21c:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ed223:	ff 
 11ed224:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ed22b:	ff 
 11ed22c:	c5 fc 11 85 30 f1 ff 	vmovups %ymm0,-0xed0(%rbp)
 11ed233:	ff 
 11ed234:	c5 fc 11 8d 50 f1 ff 	vmovups %ymm1,-0xeb0(%rbp)
 11ed23b:	ff 
 11ed23c:	c5 fc 11 95 70 f1 ff 	vmovups %ymm2,-0xe90(%rbp)
 11ed243:	ff 
 11ed244:	c5 fc 11 9d 90 f1 ff 	vmovups %ymm3,-0xe70(%rbp)
 11ed24b:	ff 
 11ed24c:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ed253:	ff 
 11ed254:	c5 fc 11 85 a0 f1 ff 	vmovups %ymm0,-0xe60(%rbp)
 11ed25b:	ff 
 11ed25c:	c6 85 48 d8 ff ff 01 	movb   $0x1,-0x27b8(%rbp)
 11ed263:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ed26a:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ed26f:	48 8d 85 e0 d7 ff ff 	lea    -0x2820(%rbp),%rax
 11ed276:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ed27b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ed27f:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ed285:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ed28c:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ed291:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ed296:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ed29a:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ed29f:	48 8d 85 30 f1 ff ff 	lea    -0xed0(%rbp),%rax
 11ed2a6:	48 89 04 24          	mov    %rax,(%rsp)
 11ed2aa:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ed2b1:	00 00 
 11ed2b3:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ed2ba:	00 00 
 11ed2bc:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ed2c0:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11ed2c4:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ed2c8:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ed2cc:	4d 89 e1             	mov    %r12,%r9
 11ed2cf:	c5 f8 77             	vzeroupper 
 11ed2d2:	e8 19 33 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ed2d7:	44 0f b7 7d b0       	movzwl -0x50(%rbp),%r15d
 11ed2dc:	66 45 85 ff          	test   %r15w,%r15w
 11ed2e0:	0f 85 bd 22 00 00    	jne    11ef5a3 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4583>
 11ed2e6:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11ed2ea:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ed2ee:	49 39 df             	cmp    %rbx,%r15
 11ed2f1:	0f 83 80 00 00 00    	jae    11ed377 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2357>
 11ed2f7:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed2fb:	48 8b 38             	mov    (%rax),%rdi
 11ed2fe:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed302:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed306:	4c 89 ee             	mov    %r13,%rsi
 11ed309:	48 89 da             	mov    %rbx,%rdx
 11ed30c:	31 c9                	xor    %ecx,%ecx
 11ed30e:	ff 50 18             	call   *0x18(%rax)
 11ed311:	c5 fc 10 85 a0 f1 ff 	vmovups -0xe60(%rbp),%ymm0
 11ed318:	ff 
 11ed319:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ed320:	ff 
 11ed321:	c5 fc 10 85 30 f1 ff 	vmovups -0xed0(%rbp),%ymm0
 11ed328:	ff 
 11ed329:	c5 fc 10 8d 50 f1 ff 	vmovups -0xeb0(%rbp),%ymm1
 11ed330:	ff 
 11ed331:	c5 fc 10 95 70 f1 ff 	vmovups -0xe90(%rbp),%ymm2
 11ed338:	ff 
 11ed339:	c5 fc 10 9d 90 f1 ff 	vmovups -0xe70(%rbp),%ymm3
 11ed340:	ff 
 11ed341:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ed348:	ff 
 11ed349:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ed350:	ff 
 11ed351:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ed358:	ff 
 11ed359:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ed360:	ff 
 11ed361:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ed365:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ed369:	80 bd f8 df ff ff 00 	cmpb   $0x0,-0x2008(%rbp)
 11ed370:	75 3f                	jne    11ed3b1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2391>
 11ed372:	e9 f8 fb ff ff       	jmp    11ecf6f <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f4f>
 11ed377:	4d 85 ff             	test   %r15,%r15
 11ed37a:	74 1a                	je     11ed396 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2376>
 11ed37c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed380:	48 8b 38             	mov    (%rax),%rdi
 11ed383:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed387:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed38b:	4c 89 f6             	mov    %r14,%rsi
 11ed38e:	4c 89 fa             	mov    %r15,%rdx
 11ed391:	31 c9                	xor    %ecx,%ecx
 11ed393:	ff 50 18             	call   *0x18(%rax)
 11ed396:	4d 89 ee             	mov    %r13,%r14
 11ed399:	49 89 df             	mov    %rbx,%r15
 11ed39c:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ed3a0:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ed3a4:	80 bd f8 df ff ff 00 	cmpb   $0x0,-0x2008(%rbp)
 11ed3ab:	0f 84 be fb ff ff    	je     11ecf6f <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f4f>
 11ed3b1:	48 8b 85 f0 df ff ff 	mov    -0x2010(%rbp),%rax
 11ed3b8:	48 89 85 d0 d7 ff ff 	mov    %rax,-0x2830(%rbp)
 11ed3bf:	c5 fc 10 85 90 df ff 	vmovups -0x2070(%rbp),%ymm0
 11ed3c6:	ff 
 11ed3c7:	c5 fc 10 8d b0 df ff 	vmovups -0x2050(%rbp),%ymm1
 11ed3ce:	ff 
 11ed3cf:	c5 fc 10 95 d0 df ff 	vmovups -0x2030(%rbp),%ymm2
 11ed3d6:	ff 
 11ed3d7:	c5 fc 11 95 b0 d7 ff 	vmovups %ymm2,-0x2850(%rbp)
 11ed3de:	ff 
 11ed3df:	c5 fc 11 8d 90 d7 ff 	vmovups %ymm1,-0x2870(%rbp)
 11ed3e6:	ff 
 11ed3e7:	c5 fc 11 85 70 d7 ff 	vmovups %ymm0,-0x2890(%rbp)
 11ed3ee:	ff 
 11ed3ef:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ed3f6:	ff 
 11ed3f7:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ed3fe:	ff 
 11ed3ff:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ed406:	ff 
 11ed407:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ed40e:	ff 
 11ed40f:	c5 fc 11 85 a0 f0 ff 	vmovups %ymm0,-0xf60(%rbp)
 11ed416:	ff 
 11ed417:	c5 fc 11 8d c0 f0 ff 	vmovups %ymm1,-0xf40(%rbp)
 11ed41e:	ff 
 11ed41f:	c5 fc 11 95 e0 f0 ff 	vmovups %ymm2,-0xf20(%rbp)
 11ed426:	ff 
 11ed427:	c5 fc 11 9d 00 f1 ff 	vmovups %ymm3,-0xf00(%rbp)
 11ed42e:	ff 
 11ed42f:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ed436:	ff 
 11ed437:	c5 fc 11 85 10 f1 ff 	vmovups %ymm0,-0xef0(%rbp)
 11ed43e:	ff 
 11ed43f:	c6 85 d8 d7 ff ff 01 	movb   $0x1,-0x2828(%rbp)
 11ed446:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ed44d:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ed452:	48 8d 85 70 d7 ff ff 	lea    -0x2890(%rbp),%rax
 11ed459:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ed45e:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ed462:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ed468:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ed46f:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ed474:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ed479:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ed47d:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ed482:	48 8d 85 a0 f0 ff ff 	lea    -0xf60(%rbp),%rax
 11ed489:	48 89 04 24          	mov    %rax,(%rsp)
 11ed48d:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ed494:	00 00 
 11ed496:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ed49d:	00 00 
 11ed49f:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ed4a3:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11ed4a7:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ed4ab:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ed4af:	4d 89 e1             	mov    %r12,%r9
 11ed4b2:	c5 f8 77             	vzeroupper 
 11ed4b5:	e8 36 31 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ed4ba:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ed4be:	66 85 db             	test   %bx,%bx
 11ed4c1:	0f 85 d9 21 00 00    	jne    11ef6a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4680>
 11ed4c7:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 11ed4cb:	4c 8b 65 a8          	mov    -0x58(%rbp),%r12
 11ed4cf:	4d 39 fc             	cmp    %r15,%r12
 11ed4d2:	0f 83 80 00 00 00    	jae    11ed558 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2538>
 11ed4d8:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed4dc:	48 8b 38             	mov    (%rax),%rdi
 11ed4df:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed4e3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed4e7:	4c 89 f6             	mov    %r14,%rsi
 11ed4ea:	4c 89 fa             	mov    %r15,%rdx
 11ed4ed:	31 c9                	xor    %ecx,%ecx
 11ed4ef:	ff 50 18             	call   *0x18(%rax)
 11ed4f2:	c5 fc 10 85 10 f1 ff 	vmovups -0xef0(%rbp),%ymm0
 11ed4f9:	ff 
 11ed4fa:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ed501:	ff 
 11ed502:	c5 fc 10 85 a0 f0 ff 	vmovups -0xf60(%rbp),%ymm0
 11ed509:	ff 
 11ed50a:	c5 fc 10 8d c0 f0 ff 	vmovups -0xf40(%rbp),%ymm1
 11ed511:	ff 
 11ed512:	c5 fc 10 95 e0 f0 ff 	vmovups -0xf20(%rbp),%ymm2
 11ed519:	ff 
 11ed51a:	c5 fc 10 9d 00 f1 ff 	vmovups -0xf00(%rbp),%ymm3
 11ed521:	ff 
 11ed522:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ed529:	ff 
 11ed52a:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ed531:	ff 
 11ed532:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ed539:	ff 
 11ed53a:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ed541:	ff 
 11ed542:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ed546:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ed54a:	80 bd 68 e0 ff ff 00 	cmpb   $0x0,-0x1f98(%rbp)
 11ed551:	75 3f                	jne    11ed592 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2572>
 11ed553:	e9 2a fa ff ff       	jmp    11ecf82 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f62>
 11ed558:	4d 85 e4             	test   %r12,%r12
 11ed55b:	74 1a                	je     11ed577 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2557>
 11ed55d:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed561:	48 8b 38             	mov    (%rax),%rdi
 11ed564:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed568:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed56c:	48 89 de             	mov    %rbx,%rsi
 11ed56f:	4c 89 e2             	mov    %r12,%rdx
 11ed572:	31 c9                	xor    %ecx,%ecx
 11ed574:	ff 50 18             	call   *0x18(%rax)
 11ed577:	4c 89 f3             	mov    %r14,%rbx
 11ed57a:	4d 89 fc             	mov    %r15,%r12
 11ed57d:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ed581:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ed585:	80 bd 68 e0 ff ff 00 	cmpb   $0x0,-0x1f98(%rbp)
 11ed58c:	0f 84 f0 f9 ff ff    	je     11ecf82 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x1f62>
 11ed592:	48 8b 85 60 e0 ff ff 	mov    -0x1fa0(%rbp),%rax
 11ed599:	48 89 85 60 d7 ff ff 	mov    %rax,-0x28a0(%rbp)
 11ed5a0:	c5 fc 10 85 00 e0 ff 	vmovups -0x2000(%rbp),%ymm0
 11ed5a7:	ff 
 11ed5a8:	c5 fc 10 8d 20 e0 ff 	vmovups -0x1fe0(%rbp),%ymm1
 11ed5af:	ff 
 11ed5b0:	c5 fc 10 95 40 e0 ff 	vmovups -0x1fc0(%rbp),%ymm2
 11ed5b7:	ff 
 11ed5b8:	c5 fc 11 95 40 d7 ff 	vmovups %ymm2,-0x28c0(%rbp)
 11ed5bf:	ff 
 11ed5c0:	c5 fc 11 8d 20 d7 ff 	vmovups %ymm1,-0x28e0(%rbp)
 11ed5c7:	ff 
 11ed5c8:	c5 fc 11 85 00 d7 ff 	vmovups %ymm0,-0x2900(%rbp)
 11ed5cf:	ff 
 11ed5d0:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ed5d7:	ff 
 11ed5d8:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ed5df:	ff 
 11ed5e0:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ed5e7:	ff 
 11ed5e8:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ed5ef:	ff 
 11ed5f0:	c5 fc 11 85 10 f0 ff 	vmovups %ymm0,-0xff0(%rbp)
 11ed5f7:	ff 
 11ed5f8:	c5 fc 11 8d 30 f0 ff 	vmovups %ymm1,-0xfd0(%rbp)
 11ed5ff:	ff 
 11ed600:	c5 fc 11 95 50 f0 ff 	vmovups %ymm2,-0xfb0(%rbp)
 11ed607:	ff 
 11ed608:	c5 fc 11 9d 70 f0 ff 	vmovups %ymm3,-0xf90(%rbp)
 11ed60f:	ff 
 11ed610:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ed617:	ff 
 11ed618:	c5 fc 11 85 80 f0 ff 	vmovups %ymm0,-0xf80(%rbp)
 11ed61f:	ff 
 11ed620:	c6 85 68 d7 ff ff 01 	movb   $0x1,-0x2898(%rbp)
 11ed627:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11ed62e:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ed633:	48 8d 85 00 d7 ff ff 	lea    -0x2900(%rbp),%rax
 11ed63a:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ed63f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ed643:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ed649:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ed650:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ed655:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ed65a:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ed65e:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ed663:	48 8d 85 10 f0 ff ff 	lea    -0xff0(%rbp),%rax
 11ed66a:	48 89 04 24          	mov    %rax,(%rsp)
 11ed66e:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ed675:	00 00 
 11ed677:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ed67e:	00 00 
 11ed680:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ed684:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 11ed688:	4c 89 fe             	mov    %r15,%rsi
 11ed68b:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ed68f:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ed693:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ed697:	c5 f8 77             	vzeroupper 
 11ed69a:	e8 51 2f 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ed69f:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 11ed6a4:	66 45 85 f6          	test   %r14w,%r14w
 11ed6a8:	0f 85 ef 20 00 00    	jne    11ef79d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x477d>
 11ed6ae:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11ed6b2:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 11ed6b6:	4d 39 e5             	cmp    %r12,%r13
 11ed6b9:	44 0f b6 bd 80 fd ff 	movzbl -0x280(%rbp),%r15d
 11ed6c0:	ff 
 11ed6c1:	73 6c                	jae    11ed72f <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x270f>
 11ed6c3:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed6c7:	48 8b 38             	mov    (%rax),%rdi
 11ed6ca:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed6ce:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed6d2:	48 89 de             	mov    %rbx,%rsi
 11ed6d5:	4c 89 e2             	mov    %r12,%rdx
 11ed6d8:	31 c9                	xor    %ecx,%ecx
 11ed6da:	ff 50 18             	call   *0x18(%rax)
 11ed6dd:	c5 fc 10 85 80 f0 ff 	vmovups -0xf80(%rbp),%ymm0
 11ed6e4:	ff 
 11ed6e5:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ed6ec:	ff 
 11ed6ed:	c5 fc 10 85 10 f0 ff 	vmovups -0xff0(%rbp),%ymm0
 11ed6f4:	ff 
 11ed6f5:	c5 fc 10 8d 30 f0 ff 	vmovups -0xfd0(%rbp),%ymm1
 11ed6fc:	ff 
 11ed6fd:	c5 fc 10 95 50 f0 ff 	vmovups -0xfb0(%rbp),%ymm2
 11ed704:	ff 
 11ed705:	c5 fc 10 9d 70 f0 ff 	vmovups -0xf90(%rbp),%ymm3
 11ed70c:	ff 
 11ed70d:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ed714:	ff 
 11ed715:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ed71c:	ff 
 11ed71d:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ed724:	ff 
 11ed725:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ed72c:	ff 
 11ed72d:	eb 25                	jmp    11ed754 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2734>
 11ed72f:	4d 85 ed             	test   %r13,%r13
 11ed732:	74 1a                	je     11ed74e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x272e>
 11ed734:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ed738:	48 8b 38             	mov    (%rax),%rdi
 11ed73b:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ed73f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed743:	4c 89 f6             	mov    %r14,%rsi
 11ed746:	4c 89 ea             	mov    %r13,%rdx
 11ed749:	31 c9                	xor    %ecx,%ecx
 11ed74b:	ff 50 18             	call   *0x18(%rax)
 11ed74e:	49 89 de             	mov    %rbx,%r14
 11ed751:	4d 89 e5             	mov    %r12,%r13
 11ed754:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ed758:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ed75c:	45 84 ff             	test   %r15b,%r15b
 11ed75f:	0f 94 c0             	sete   %al
 11ed762:	80 7d 8b 00          	cmpb   $0x0,-0x75(%rbp)
 11ed766:	0f 94 c1             	sete   %cl
 11ed769:	08 c1                	or     %al,%cl
 11ed76b:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 11ed76f:	0f 84 b5 01 00 00    	je     11ed92a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x290a>
 11ed775:	4d 89 ef             	mov    %r13,%r15
 11ed778:	80 7d 8c 00          	cmpb   $0x0,-0x74(%rbp)
 11ed77c:	0f 84 c1 03 00 00    	je     11edb43 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2b23>
 11ed782:	48 8b 85 30 f8 ff ff 	mov    -0x7d0(%rbp),%rax
 11ed789:	48 89 85 80 d6 ff ff 	mov    %rax,-0x2980(%rbp)
 11ed790:	c5 fc 10 85 d0 f7 ff 	vmovups -0x830(%rbp),%ymm0
 11ed797:	ff 
 11ed798:	c5 fc 10 8d f0 f7 ff 	vmovups -0x810(%rbp),%ymm1
 11ed79f:	ff 
 11ed7a0:	c5 fc 10 95 10 f8 ff 	vmovups -0x7f0(%rbp),%ymm2
 11ed7a7:	ff 
 11ed7a8:	c5 fc 11 95 60 d6 ff 	vmovups %ymm2,-0x29a0(%rbp)
 11ed7af:	ff 
 11ed7b0:	c5 fc 11 8d 40 d6 ff 	vmovups %ymm1,-0x29c0(%rbp)
 11ed7b7:	ff 
 11ed7b8:	c5 fc 11 85 20 d6 ff 	vmovups %ymm0,-0x29e0(%rbp)
 11ed7bf:	ff 
 11ed7c0:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ed7c7:	ff 
 11ed7c8:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ed7cf:	ff 
 11ed7d0:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ed7d7:	ff 
 11ed7d8:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ed7df:	ff 
 11ed7e0:	c5 fc 11 85 f0 ee ff 	vmovups %ymm0,-0x1110(%rbp)
 11ed7e7:	ff 
 11ed7e8:	c5 fc 11 8d 10 ef ff 	vmovups %ymm1,-0x10f0(%rbp)
 11ed7ef:	ff 
 11ed7f0:	c5 fc 11 95 30 ef ff 	vmovups %ymm2,-0x10d0(%rbp)
 11ed7f7:	ff 
 11ed7f8:	c5 fc 11 9d 50 ef ff 	vmovups %ymm3,-0x10b0(%rbp)
 11ed7ff:	ff 
 11ed800:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ed807:	ff 
 11ed808:	c5 fc 11 85 60 ef ff 	vmovups %ymm0,-0x10a0(%rbp)
 11ed80f:	ff 
 11ed810:	c6 85 88 d6 ff ff 01 	movb   $0x1,-0x2978(%rbp)
 11ed817:	48 8d 85 20 d6 ff ff 	lea    -0x29e0(%rbp),%rax
 11ed81e:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ed823:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ed82a:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ed82f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ed833:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ed839:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ed840:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ed845:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ed84a:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ed84e:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ed853:	48 8d 85 f0 ee ff ff 	lea    -0x1110(%rbp),%rax
 11ed85a:	48 89 04 24          	mov    %rax,(%rsp)
 11ed85e:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ed865:	00 00 
 11ed867:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ed86e:	00 00 
 11ed870:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ed874:	4c 8b 6d c8          	mov    -0x38(%rbp),%r13
 11ed878:	4c 89 ee             	mov    %r13,%rsi
 11ed87b:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ed87f:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ed883:	4d 89 e1             	mov    %r12,%r9
 11ed886:	c5 f8 77             	vzeroupper 
 11ed889:	e8 62 2d 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ed88e:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ed892:	66 85 db             	test   %bx,%bx
 11ed895:	0f 85 fa 1f 00 00    	jne    11ef895 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4875>
 11ed89b:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ed89f:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 11ed8a3:	4c 39 fb             	cmp    %r15,%rbx
 11ed8a6:	0f 83 28 02 00 00    	jae    11edad4 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2ab4>
 11ed8ac:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ed8b0:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ed8b4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ed8b8:	4c 89 f6             	mov    %r14,%rsi
 11ed8bb:	4c 89 fa             	mov    %r15,%rdx
 11ed8be:	31 c9                	xor    %ecx,%ecx
 11ed8c0:	ff 50 18             	call   *0x18(%rax)
 11ed8c3:	c5 fc 10 85 60 ef ff 	vmovups -0x10a0(%rbp),%ymm0
 11ed8ca:	ff 
 11ed8cb:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ed8d2:	ff 
 11ed8d3:	c5 fc 10 85 f0 ee ff 	vmovups -0x1110(%rbp),%ymm0
 11ed8da:	ff 
 11ed8db:	c5 fc 10 8d 10 ef ff 	vmovups -0x10f0(%rbp),%ymm1
 11ed8e2:	ff 
 11ed8e3:	c5 fc 10 95 30 ef ff 	vmovups -0x10d0(%rbp),%ymm2
 11ed8ea:	ff 
 11ed8eb:	c5 fc 10 9d 50 ef ff 	vmovups -0x10b0(%rbp),%ymm3
 11ed8f2:	ff 
 11ed8f3:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ed8fa:	ff 
 11ed8fb:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ed902:	ff 
 11ed903:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ed90a:	ff 
 11ed90b:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ed912:	ff 
 11ed913:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ed917:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ed91b:	80 7d 8d 00          	cmpb   $0x0,-0x73(%rbp)
 11ed91f:	0f 85 2e 02 00 00    	jne    11edb53 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2b33>
 11ed925:	e9 da 01 00 00       	jmp    11edb04 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2ae4>
 11ed92a:	48 8b 85 c0 f7 ff ff 	mov    -0x840(%rbp),%rax
 11ed931:	48 89 85 f0 d6 ff ff 	mov    %rax,-0x2910(%rbp)
 11ed938:	c5 fc 10 85 60 f7 ff 	vmovups -0x8a0(%rbp),%ymm0
 11ed93f:	ff 
 11ed940:	c5 fc 10 8d 80 f7 ff 	vmovups -0x880(%rbp),%ymm1
 11ed947:	ff 
 11ed948:	c5 fc 10 95 a0 f7 ff 	vmovups -0x860(%rbp),%ymm2
 11ed94f:	ff 
 11ed950:	c5 fc 11 95 d0 d6 ff 	vmovups %ymm2,-0x2930(%rbp)
 11ed957:	ff 
 11ed958:	c5 fc 11 8d b0 d6 ff 	vmovups %ymm1,-0x2950(%rbp)
 11ed95f:	ff 
 11ed960:	c5 fc 11 85 90 d6 ff 	vmovups %ymm0,-0x2970(%rbp)
 11ed967:	ff 
 11ed968:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ed96f:	ff 
 11ed970:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ed977:	ff 
 11ed978:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ed97f:	ff 
 11ed980:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ed987:	ff 
 11ed988:	c5 fc 11 85 80 ef ff 	vmovups %ymm0,-0x1080(%rbp)
 11ed98f:	ff 
 11ed990:	c5 fc 11 8d a0 ef ff 	vmovups %ymm1,-0x1060(%rbp)
 11ed997:	ff 
 11ed998:	c5 fc 11 95 c0 ef ff 	vmovups %ymm2,-0x1040(%rbp)
 11ed99f:	ff 
 11ed9a0:	c5 fc 11 9d e0 ef ff 	vmovups %ymm3,-0x1020(%rbp)
 11ed9a7:	ff 
 11ed9a8:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ed9af:	ff 
 11ed9b0:	c5 fc 11 85 f0 ef ff 	vmovups %ymm0,-0x1010(%rbp)
 11ed9b7:	ff 
 11ed9b8:	c6 85 f8 d6 ff ff 01 	movb   $0x1,-0x2908(%rbp)
 11ed9bf:	48 8d 85 90 d6 ff ff 	lea    -0x2970(%rbp),%rax
 11ed9c6:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ed9cb:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ed9d2:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ed9d7:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ed9db:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ed9e1:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ed9e8:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ed9ed:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ed9f2:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ed9f6:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ed9fb:	48 8d 85 80 ef ff ff 	lea    -0x1080(%rbp),%rax
 11eda02:	48 89 04 24          	mov    %rax,(%rsp)
 11eda06:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11eda0d:	00 00 
 11eda0f:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11eda16:	00 00 
 11eda18:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11eda1c:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11eda20:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11eda24:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11eda28:	4d 89 e1             	mov    %r12,%r9
 11eda2b:	c5 f8 77             	vzeroupper 
 11eda2e:	e8 bd 2b 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11eda33:	44 0f b7 7d b0       	movzwl -0x50(%rbp),%r15d
 11eda38:	66 45 85 ff          	test   %r15w,%r15w
 11eda3c:	0f 85 1f 25 00 00    	jne    11eff61 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f41>
 11eda42:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 11eda46:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11eda4a:	4d 39 ef             	cmp    %r13,%r15
 11eda4d:	0f 83 bc 00 00 00    	jae    11edb0f <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2aef>
 11eda53:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eda57:	48 8b 38             	mov    (%rax),%rdi
 11eda5a:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eda5e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eda62:	4c 89 f6             	mov    %r14,%rsi
 11eda65:	4c 89 ea             	mov    %r13,%rdx
 11eda68:	31 c9                	xor    %ecx,%ecx
 11eda6a:	ff 50 18             	call   *0x18(%rax)
 11eda6d:	c5 fc 10 85 f0 ef ff 	vmovups -0x1010(%rbp),%ymm0
 11eda74:	ff 
 11eda75:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11eda7c:	ff 
 11eda7d:	c5 fc 10 85 80 ef ff 	vmovups -0x1080(%rbp),%ymm0
 11eda84:	ff 
 11eda85:	c5 fc 10 8d a0 ef ff 	vmovups -0x1060(%rbp),%ymm1
 11eda8c:	ff 
 11eda8d:	c5 fc 10 95 c0 ef ff 	vmovups -0x1040(%rbp),%ymm2
 11eda94:	ff 
 11eda95:	c5 fc 10 9d e0 ef ff 	vmovups -0x1020(%rbp),%ymm3
 11eda9c:	ff 
 11eda9d:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11edaa4:	ff 
 11edaa5:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11edaac:	ff 
 11edaad:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11edab4:	ff 
 11edab5:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11edabc:	ff 
 11edabd:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11edac1:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11edac5:	49 89 de             	mov    %rbx,%r14
 11edac8:	80 7d 8c 00          	cmpb   $0x0,-0x74(%rbp)
 11edacc:	0f 85 b0 fc ff ff    	jne    11ed782 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2762>
 11edad2:	eb 6f                	jmp    11edb43 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2b23>
 11edad4:	48 85 db             	test   %rbx,%rbx
 11edad7:	74 17                	je     11edaf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2ad0>
 11edad9:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11edadd:	49 8b 45 08          	mov    0x8(%r13),%rax
 11edae1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11edae5:	4c 89 e6             	mov    %r12,%rsi
 11edae8:	48 89 da             	mov    %rbx,%rdx
 11edaeb:	31 c9                	xor    %ecx,%ecx
 11edaed:	ff 50 18             	call   *0x18(%rax)
 11edaf0:	4d 89 f4             	mov    %r14,%r12
 11edaf3:	4c 89 fb             	mov    %r15,%rbx
 11edaf6:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11edafa:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11edafe:	80 7d 8d 00          	cmpb   $0x0,-0x73(%rbp)
 11edb02:	75 4f                	jne    11edb53 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2b33>
 11edb04:	4d 89 e6             	mov    %r12,%r14
 11edb07:	49 89 df             	mov    %rbx,%r15
 11edb0a:	e9 fc 01 00 00       	jmp    11edd0b <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2ceb>
 11edb0f:	4d 85 ff             	test   %r15,%r15
 11edb12:	74 1a                	je     11edb2e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2b0e>
 11edb14:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11edb18:	48 8b 38             	mov    (%rax),%rdi
 11edb1b:	48 8b 40 08          	mov    0x8(%rax),%rax
 11edb1f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11edb23:	48 89 de             	mov    %rbx,%rsi
 11edb26:	4c 89 fa             	mov    %r15,%rdx
 11edb29:	31 c9                	xor    %ecx,%ecx
 11edb2b:	ff 50 18             	call   *0x18(%rax)
 11edb2e:	4d 89 ef             	mov    %r13,%r15
 11edb31:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11edb35:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11edb39:	80 7d 8c 00          	cmpb   $0x0,-0x74(%rbp)
 11edb3d:	0f 85 3f fc ff ff    	jne    11ed782 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2762>
 11edb43:	4d 89 f4             	mov    %r14,%r12
 11edb46:	4c 89 fb             	mov    %r15,%rbx
 11edb49:	4c 8b 6d c8          	mov    -0x38(%rbp),%r13
 11edb4d:	80 7d 8d 00          	cmpb   $0x0,-0x73(%rbp)
 11edb51:	74 b1                	je     11edb04 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2ae4>
 11edb53:	48 8b 85 a0 f8 ff ff 	mov    -0x760(%rbp),%rax
 11edb5a:	48 89 85 10 d6 ff ff 	mov    %rax,-0x29f0(%rbp)
 11edb61:	c5 fc 10 85 40 f8 ff 	vmovups -0x7c0(%rbp),%ymm0
 11edb68:	ff 
 11edb69:	c5 fc 10 8d 60 f8 ff 	vmovups -0x7a0(%rbp),%ymm1
 11edb70:	ff 
 11edb71:	c5 fc 10 95 80 f8 ff 	vmovups -0x780(%rbp),%ymm2
 11edb78:	ff 
 11edb79:	c5 fc 11 95 f0 d5 ff 	vmovups %ymm2,-0x2a10(%rbp)
 11edb80:	ff 
 11edb81:	c5 fc 11 8d d0 d5 ff 	vmovups %ymm1,-0x2a30(%rbp)
 11edb88:	ff 
 11edb89:	c5 fc 11 85 b0 d5 ff 	vmovups %ymm0,-0x2a50(%rbp)
 11edb90:	ff 
 11edb91:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11edb98:	ff 
 11edb99:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11edba0:	ff 
 11edba1:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11edba8:	ff 
 11edba9:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11edbb0:	ff 
 11edbb1:	c5 fc 11 85 60 ee ff 	vmovups %ymm0,-0x11a0(%rbp)
 11edbb8:	ff 
 11edbb9:	c5 fc 11 8d 80 ee ff 	vmovups %ymm1,-0x1180(%rbp)
 11edbc0:	ff 
 11edbc1:	c5 fc 11 95 a0 ee ff 	vmovups %ymm2,-0x1160(%rbp)
 11edbc8:	ff 
 11edbc9:	c5 fc 11 9d c0 ee ff 	vmovups %ymm3,-0x1140(%rbp)
 11edbd0:	ff 
 11edbd1:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11edbd8:	ff 
 11edbd9:	c5 fc 11 85 d0 ee ff 	vmovups %ymm0,-0x1130(%rbp)
 11edbe0:	ff 
 11edbe1:	c6 85 18 d6 ff ff 01 	movb   $0x1,-0x29e8(%rbp)
 11edbe8:	48 8d 85 b0 d5 ff ff 	lea    -0x2a50(%rbp),%rax
 11edbef:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11edbf4:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11edbfb:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11edc00:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11edc04:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11edc0a:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11edc11:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11edc16:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11edc1b:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11edc1f:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11edc24:	48 8d 85 60 ee ff ff 	lea    -0x11a0(%rbp),%rax
 11edc2b:	48 89 04 24          	mov    %rax,(%rsp)
 11edc2f:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11edc36:	00 00 
 11edc38:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11edc3f:	00 00 
 11edc41:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11edc45:	4c 89 ee             	mov    %r13,%rsi
 11edc48:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11edc4c:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11edc50:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11edc54:	c5 f8 77             	vzeroupper 
 11edc57:	e8 94 29 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11edc5c:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 11edc61:	66 45 85 f6          	test   %r14w,%r14w
 11edc65:	0f 85 20 1d 00 00    	jne    11ef98b <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x496b>
 11edc6b:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11edc6f:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11edc73:	49 39 df             	cmp    %rbx,%r15
 11edc76:	73 69                	jae    11edce1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2cc1>
 11edc78:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11edc7c:	49 8b 45 08          	mov    0x8(%r13),%rax
 11edc80:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11edc84:	4c 89 e6             	mov    %r12,%rsi
 11edc87:	48 89 da             	mov    %rbx,%rdx
 11edc8a:	31 c9                	xor    %ecx,%ecx
 11edc8c:	ff 50 18             	call   *0x18(%rax)
 11edc8f:	c5 fc 10 85 d0 ee ff 	vmovups -0x1130(%rbp),%ymm0
 11edc96:	ff 
 11edc97:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11edc9e:	ff 
 11edc9f:	c5 fc 10 85 60 ee ff 	vmovups -0x11a0(%rbp),%ymm0
 11edca6:	ff 
 11edca7:	c5 fc 10 8d 80 ee ff 	vmovups -0x1180(%rbp),%ymm1
 11edcae:	ff 
 11edcaf:	c5 fc 10 95 a0 ee ff 	vmovups -0x1160(%rbp),%ymm2
 11edcb6:	ff 
 11edcb7:	c5 fc 10 9d c0 ee ff 	vmovups -0x1140(%rbp),%ymm3
 11edcbe:	ff 
 11edcbf:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11edcc6:	ff 
 11edcc7:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11edcce:	ff 
 11edccf:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11edcd6:	ff 
 11edcd7:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11edcde:	ff 
 11edcdf:	eb 22                	jmp    11edd03 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2ce3>
 11edce1:	4d 85 ff             	test   %r15,%r15
 11edce4:	74 17                	je     11edcfd <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2cdd>
 11edce6:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11edcea:	49 8b 45 08          	mov    0x8(%r13),%rax
 11edcee:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11edcf2:	4c 89 f6             	mov    %r14,%rsi
 11edcf5:	4c 89 fa             	mov    %r15,%rdx
 11edcf8:	31 c9                	xor    %ecx,%ecx
 11edcfa:	ff 50 18             	call   *0x18(%rax)
 11edcfd:	4d 89 e6             	mov    %r12,%r14
 11edd00:	49 89 df             	mov    %rbx,%r15
 11edd03:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11edd07:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11edd0b:	80 7d 8e 00          	cmpb   $0x0,-0x72(%rbp)
 11edd0f:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11edd13:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11edd17:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11edd1b:	0f 84 98 01 00 00    	je     11edeb9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2e99>
 11edd21:	48 8b 85 10 f9 ff ff 	mov    -0x6f0(%rbp),%rax
 11edd28:	48 89 85 a0 d5 ff ff 	mov    %rax,-0x2a60(%rbp)
 11edd2f:	c5 fc 10 85 b0 f8 ff 	vmovups -0x750(%rbp),%ymm0
 11edd36:	ff 
 11edd37:	c5 fc 10 8d d0 f8 ff 	vmovups -0x730(%rbp),%ymm1
 11edd3e:	ff 
 11edd3f:	c5 fc 10 95 f0 f8 ff 	vmovups -0x710(%rbp),%ymm2
 11edd46:	ff 
 11edd47:	c5 fc 11 95 80 d5 ff 	vmovups %ymm2,-0x2a80(%rbp)
 11edd4e:	ff 
 11edd4f:	c5 fc 11 8d 60 d5 ff 	vmovups %ymm1,-0x2aa0(%rbp)
 11edd56:	ff 
 11edd57:	c5 fc 11 85 40 d5 ff 	vmovups %ymm0,-0x2ac0(%rbp)
 11edd5e:	ff 
 11edd5f:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11edd66:	ff 
 11edd67:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11edd6e:	ff 
 11edd6f:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11edd76:	ff 
 11edd77:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11edd7e:	ff 
 11edd7f:	c5 fc 11 85 d0 ed ff 	vmovups %ymm0,-0x1230(%rbp)
 11edd86:	ff 
 11edd87:	c5 fc 11 8d f0 ed ff 	vmovups %ymm1,-0x1210(%rbp)
 11edd8e:	ff 
 11edd8f:	c5 fc 11 95 10 ee ff 	vmovups %ymm2,-0x11f0(%rbp)
 11edd96:	ff 
 11edd97:	c5 fc 11 9d 30 ee ff 	vmovups %ymm3,-0x11d0(%rbp)
 11edd9e:	ff 
 11edd9f:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11edda6:	ff 
 11edda7:	c5 fc 11 85 40 ee ff 	vmovups %ymm0,-0x11c0(%rbp)
 11eddae:	ff 
 11eddaf:	c6 85 a8 d5 ff ff 01 	movb   $0x1,-0x2a58(%rbp)
 11eddb6:	48 8d 85 40 d5 ff ff 	lea    -0x2ac0(%rbp),%rax
 11eddbd:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11eddc2:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11eddc9:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11eddce:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11eddd2:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11eddd8:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11edddf:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11edde4:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11edde9:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11edded:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11eddf2:	48 8d 85 d0 ed ff ff 	lea    -0x1230(%rbp),%rax
 11eddf9:	48 89 04 24          	mov    %rax,(%rsp)
 11eddfd:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ede04:	00 00 
 11ede06:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ede0d:	00 00 
 11ede0f:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ede13:	4c 89 ee             	mov    %r13,%rsi
 11ede16:	c5 f8 77             	vzeroupper 
 11ede19:	e8 d2 27 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ede1e:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ede22:	66 85 db             	test   %bx,%bx
 11ede25:	0f 85 56 1c 00 00    	jne    11efa81 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4a61>
 11ede2b:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ede2f:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 11ede33:	4c 39 fb             	cmp    %r15,%rbx
 11ede36:	0f 83 22 02 00 00    	jae    11ee05e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x303e>
 11ede3c:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ede40:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ede44:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ede48:	4c 89 f6             	mov    %r14,%rsi
 11ede4b:	4c 89 fa             	mov    %r15,%rdx
 11ede4e:	31 c9                	xor    %ecx,%ecx
 11ede50:	ff 50 18             	call   *0x18(%rax)
 11ede53:	c5 fc 10 85 40 ee ff 	vmovups -0x11c0(%rbp),%ymm0
 11ede5a:	ff 
 11ede5b:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ede62:	ff 
 11ede63:	c5 fc 10 85 d0 ed ff 	vmovups -0x1230(%rbp),%ymm0
 11ede6a:	ff 
 11ede6b:	c5 fc 10 8d f0 ed ff 	vmovups -0x1210(%rbp),%ymm1
 11ede72:	ff 
 11ede73:	c5 fc 10 95 10 ee ff 	vmovups -0x11f0(%rbp),%ymm2
 11ede7a:	ff 
 11ede7b:	c5 fc 10 9d 30 ee ff 	vmovups -0x11d0(%rbp),%ymm3
 11ede82:	ff 
 11ede83:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ede8a:	ff 
 11ede8b:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ede92:	ff 
 11ede93:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ede9a:	ff 
 11ede9b:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11edea2:	ff 
 11edea3:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11edea7:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11edeab:	80 bd 26 ff ff ff 00 	cmpb   $0x0,-0xda(%rbp)
 11edeb2:	75 18                	jne    11edecc <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2eac>
 11edeb4:	e9 dc 01 00 00       	jmp    11ee095 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3075>
 11edeb9:	4d 89 f4             	mov    %r14,%r12
 11edebc:	4c 89 fb             	mov    %r15,%rbx
 11edebf:	80 bd 26 ff ff ff 00 	cmpb   $0x0,-0xda(%rbp)
 11edec6:	0f 84 c9 01 00 00    	je     11ee095 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3075>
 11edecc:	48 8b 85 80 f9 ff ff 	mov    -0x680(%rbp),%rax
 11eded3:	48 89 85 30 d5 ff ff 	mov    %rax,-0x2ad0(%rbp)
 11ededa:	c5 fc 10 85 20 f9 ff 	vmovups -0x6e0(%rbp),%ymm0
 11edee1:	ff 
 11edee2:	c5 fc 10 8d 40 f9 ff 	vmovups -0x6c0(%rbp),%ymm1
 11edee9:	ff 
 11edeea:	c5 fc 10 95 60 f9 ff 	vmovups -0x6a0(%rbp),%ymm2
 11edef1:	ff 
 11edef2:	c5 fc 11 95 10 d5 ff 	vmovups %ymm2,-0x2af0(%rbp)
 11edef9:	ff 
 11edefa:	c5 fc 11 8d f0 d4 ff 	vmovups %ymm1,-0x2b10(%rbp)
 11edf01:	ff 
 11edf02:	c5 fc 11 85 d0 d4 ff 	vmovups %ymm0,-0x2b30(%rbp)
 11edf09:	ff 
 11edf0a:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11edf11:	ff 
 11edf12:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11edf19:	ff 
 11edf1a:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11edf21:	ff 
 11edf22:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11edf29:	ff 
 11edf2a:	c5 fc 11 85 40 ed ff 	vmovups %ymm0,-0x12c0(%rbp)
 11edf31:	ff 
 11edf32:	c5 fc 11 8d 60 ed ff 	vmovups %ymm1,-0x12a0(%rbp)
 11edf39:	ff 
 11edf3a:	c5 fc 11 95 80 ed ff 	vmovups %ymm2,-0x1280(%rbp)
 11edf41:	ff 
 11edf42:	c5 fc 11 9d a0 ed ff 	vmovups %ymm3,-0x1260(%rbp)
 11edf49:	ff 
 11edf4a:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11edf51:	ff 
 11edf52:	c5 fc 11 85 b0 ed ff 	vmovups %ymm0,-0x1250(%rbp)
 11edf59:	ff 
 11edf5a:	c6 85 38 d5 ff ff 01 	movb   $0x1,-0x2ac8(%rbp)
 11edf61:	48 8d 85 d0 d4 ff ff 	lea    -0x2b30(%rbp),%rax
 11edf68:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11edf6d:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11edf74:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11edf79:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11edf7d:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11edf83:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11edf8a:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11edf8f:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11edf94:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11edf98:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11edf9d:	48 8d 85 40 ed ff ff 	lea    -0x12c0(%rbp),%rax
 11edfa4:	48 89 04 24          	mov    %rax,(%rsp)
 11edfa8:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11edfaf:	00 00 
 11edfb1:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11edfb8:	00 00 
 11edfba:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11edfbe:	4c 89 ee             	mov    %r13,%rsi
 11edfc1:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11edfc5:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11edfc9:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11edfcd:	c5 f8 77             	vzeroupper 
 11edfd0:	e8 1b 26 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11edfd5:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 11edfda:	66 45 85 f6          	test   %r14w,%r14w
 11edfde:	0f 85 93 1b 00 00    	jne    11efb77 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4b57>
 11edfe4:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11edfe8:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11edfec:	49 39 df             	cmp    %rbx,%r15
 11edfef:	0f 83 be 00 00 00    	jae    11ee0b3 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3093>
 11edff5:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11edff9:	49 8b 45 08          	mov    0x8(%r13),%rax
 11edffd:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee001:	4c 89 e6             	mov    %r12,%rsi
 11ee004:	48 89 da             	mov    %rbx,%rdx
 11ee007:	31 c9                	xor    %ecx,%ecx
 11ee009:	ff 50 18             	call   *0x18(%rax)
 11ee00c:	c5 fc 10 85 b0 ed ff 	vmovups -0x1250(%rbp),%ymm0
 11ee013:	ff 
 11ee014:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ee01b:	ff 
 11ee01c:	c5 fc 10 85 40 ed ff 	vmovups -0x12c0(%rbp),%ymm0
 11ee023:	ff 
 11ee024:	c5 fc 10 8d 60 ed ff 	vmovups -0x12a0(%rbp),%ymm1
 11ee02b:	ff 
 11ee02c:	c5 fc 10 95 80 ed ff 	vmovups -0x1280(%rbp),%ymm2
 11ee033:	ff 
 11ee034:	c5 fc 10 9d a0 ed ff 	vmovups -0x1260(%rbp),%ymm3
 11ee03b:	ff 
 11ee03c:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ee043:	ff 
 11ee044:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ee04b:	ff 
 11ee04c:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ee053:	ff 
 11ee054:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ee05b:	ff 
 11ee05c:	eb 77                	jmp    11ee0d5 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x30b5>
 11ee05e:	48 85 db             	test   %rbx,%rbx
 11ee061:	74 17                	je     11ee07a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x305a>
 11ee063:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ee067:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ee06b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee06f:	4c 89 e6             	mov    %r12,%rsi
 11ee072:	48 89 da             	mov    %rbx,%rdx
 11ee075:	31 c9                	xor    %ecx,%ecx
 11ee077:	ff 50 18             	call   *0x18(%rax)
 11ee07a:	4d 89 f4             	mov    %r14,%r12
 11ee07d:	4c 89 fb             	mov    %r15,%rbx
 11ee080:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ee084:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ee088:	80 bd 26 ff ff ff 00 	cmpb   $0x0,-0xda(%rbp)
 11ee08f:	0f 85 37 fe ff ff    	jne    11edecc <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x2eac>
 11ee095:	4d 89 e6             	mov    %r12,%r14
 11ee098:	49 89 df             	mov    %rbx,%r15
 11ee09b:	80 bd 27 ff ff ff 00 	cmpb   $0x0,-0xd9(%rbp)
 11ee0a2:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ee0a6:	75 42                	jne    11ee0ea <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x30ca>
 11ee0a8:	4c 89 f3             	mov    %r14,%rbx
 11ee0ab:	4d 89 fd             	mov    %r15,%r13
 11ee0ae:	e9 f5 01 00 00       	jmp    11ee2a8 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3288>
 11ee0b3:	4d 85 ff             	test   %r15,%r15
 11ee0b6:	74 17                	je     11ee0cf <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x30af>
 11ee0b8:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ee0bc:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ee0c0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee0c4:	4c 89 f6             	mov    %r14,%rsi
 11ee0c7:	4c 89 fa             	mov    %r15,%rdx
 11ee0ca:	31 c9                	xor    %ecx,%ecx
 11ee0cc:	ff 50 18             	call   *0x18(%rax)
 11ee0cf:	4d 89 e6             	mov    %r12,%r14
 11ee0d2:	49 89 df             	mov    %rbx,%r15
 11ee0d5:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ee0d9:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ee0dd:	80 bd 27 ff ff ff 00 	cmpb   $0x0,-0xd9(%rbp)
 11ee0e4:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ee0e8:	74 be                	je     11ee0a8 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3088>
 11ee0ea:	48 8b 85 f0 f9 ff ff 	mov    -0x610(%rbp),%rax
 11ee0f1:	48 89 85 c0 d4 ff ff 	mov    %rax,-0x2b40(%rbp)
 11ee0f8:	c5 fc 10 85 90 f9 ff 	vmovups -0x670(%rbp),%ymm0
 11ee0ff:	ff 
 11ee100:	c5 fc 10 8d b0 f9 ff 	vmovups -0x650(%rbp),%ymm1
 11ee107:	ff 
 11ee108:	c5 fc 10 95 d0 f9 ff 	vmovups -0x630(%rbp),%ymm2
 11ee10f:	ff 
 11ee110:	c5 fc 11 95 a0 d4 ff 	vmovups %ymm2,-0x2b60(%rbp)
 11ee117:	ff 
 11ee118:	c5 fc 11 8d 80 d4 ff 	vmovups %ymm1,-0x2b80(%rbp)
 11ee11f:	ff 
 11ee120:	c5 fc 11 85 60 d4 ff 	vmovups %ymm0,-0x2ba0(%rbp)
 11ee127:	ff 
 11ee128:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ee12f:	ff 
 11ee130:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ee137:	ff 
 11ee138:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ee13f:	ff 
 11ee140:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ee147:	ff 
 11ee148:	c5 fc 11 85 b0 ec ff 	vmovups %ymm0,-0x1350(%rbp)
 11ee14f:	ff 
 11ee150:	c5 fc 11 8d d0 ec ff 	vmovups %ymm1,-0x1330(%rbp)
 11ee157:	ff 
 11ee158:	c5 fc 11 95 f0 ec ff 	vmovups %ymm2,-0x1310(%rbp)
 11ee15f:	ff 
 11ee160:	c5 fc 11 9d 10 ed ff 	vmovups %ymm3,-0x12f0(%rbp)
 11ee167:	ff 
 11ee168:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ee16f:	ff 
 11ee170:	c5 fc 11 85 20 ed ff 	vmovups %ymm0,-0x12e0(%rbp)
 11ee177:	ff 
 11ee178:	c6 85 c8 d4 ff ff 01 	movb   $0x1,-0x2b38(%rbp)
 11ee17f:	48 8d 85 60 d4 ff ff 	lea    -0x2ba0(%rbp),%rax
 11ee186:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ee18b:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11ee192:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ee197:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee19b:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ee1a1:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11ee1a8:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ee1ad:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ee1b2:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ee1b6:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ee1bb:	48 8d 85 b0 ec ff ff 	lea    -0x1350(%rbp),%rax
 11ee1c2:	48 89 04 24          	mov    %rax,(%rsp)
 11ee1c6:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ee1cd:	00 00 
 11ee1cf:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ee1d6:	00 00 
 11ee1d8:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ee1dc:	4c 89 ee             	mov    %r13,%rsi
 11ee1df:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ee1e3:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ee1e7:	4d 89 cc             	mov    %r9,%r12
 11ee1ea:	c5 f8 77             	vzeroupper 
 11ee1ed:	e8 fe 23 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ee1f2:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ee1f6:	66 85 db             	test   %bx,%bx
 11ee1f9:	0f 85 71 1a 00 00    	jne    11efc70 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4c50>
 11ee1ff:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 11ee203:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 11ee207:	4d 39 fd             	cmp    %r15,%r13
 11ee20a:	73 6c                	jae    11ee278 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3258>
 11ee20c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee210:	48 8b 38             	mov    (%rax),%rdi
 11ee213:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ee217:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee21b:	4c 89 f6             	mov    %r14,%rsi
 11ee21e:	4c 89 fa             	mov    %r15,%rdx
 11ee221:	31 c9                	xor    %ecx,%ecx
 11ee223:	ff 50 18             	call   *0x18(%rax)
 11ee226:	c5 fc 10 85 20 ed ff 	vmovups -0x12e0(%rbp),%ymm0
 11ee22d:	ff 
 11ee22e:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ee235:	ff 
 11ee236:	c5 fc 10 85 b0 ec ff 	vmovups -0x1350(%rbp),%ymm0
 11ee23d:	ff 
 11ee23e:	c5 fc 10 8d d0 ec ff 	vmovups -0x1330(%rbp),%ymm1
 11ee245:	ff 
 11ee246:	c5 fc 10 95 f0 ec ff 	vmovups -0x1310(%rbp),%ymm2
 11ee24d:	ff 
 11ee24e:	c5 fc 10 9d 10 ed ff 	vmovups -0x12f0(%rbp),%ymm3
 11ee255:	ff 
 11ee256:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ee25d:	ff 
 11ee25e:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ee265:	ff 
 11ee266:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ee26d:	ff 
 11ee26e:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ee275:	ff 
 11ee276:	eb 25                	jmp    11ee29d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x327d>
 11ee278:	4d 85 ed             	test   %r13,%r13
 11ee27b:	74 1a                	je     11ee297 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3277>
 11ee27d:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee281:	48 8b 38             	mov    (%rax),%rdi
 11ee284:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ee288:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee28c:	48 89 de             	mov    %rbx,%rsi
 11ee28f:	4c 89 ea             	mov    %r13,%rdx
 11ee292:	31 c9                	xor    %ecx,%ecx
 11ee294:	ff 50 18             	call   *0x18(%rax)
 11ee297:	4c 89 f3             	mov    %r14,%rbx
 11ee29a:	4d 89 fd             	mov    %r15,%r13
 11ee29d:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ee2a1:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ee2a5:	4d 89 e1             	mov    %r12,%r9
 11ee2a8:	0f b6 4d c6          	movzbl -0x3a(%rbp),%ecx
 11ee2ac:	80 f1 01             	xor    $0x1,%cl
 11ee2af:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ee2b6:	0f 94 c0             	sete   %al
 11ee2b9:	41 89 cc             	mov    %ecx,%r12d
 11ee2bc:	84 c1                	test   %al,%cl
 11ee2be:	0f 85 59 01 00 00    	jne    11ee41d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x33fd>
 11ee2c4:	80 bd a0 e0 ff ff 00 	cmpb   $0x0,-0x1f60(%rbp)
 11ee2cb:	0f 84 4c 01 00 00    	je     11ee41d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x33fd>
 11ee2d1:	48 8d 85 70 e0 ff ff 	lea    -0x1f90(%rbp),%rax
 11ee2d8:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ee2df:	ff 
 11ee2e0:	c5 fc 11 85 90 ec ff 	vmovups %ymm0,-0x1370(%rbp)
 11ee2e7:	ff 
 11ee2e8:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ee2ef:	ff 
 11ee2f0:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ee2f7:	ff 
 11ee2f8:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ee2ff:	ff 
 11ee300:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ee307:	ff 
 11ee308:	c5 fc 11 9d 80 ec ff 	vmovups %ymm3,-0x1380(%rbp)
 11ee30f:	ff 
 11ee310:	c5 fc 11 95 60 ec ff 	vmovups %ymm2,-0x13a0(%rbp)
 11ee317:	ff 
 11ee318:	c5 fc 11 8d 40 ec ff 	vmovups %ymm1,-0x13c0(%rbp)
 11ee31f:	ff 
 11ee320:	c5 fc 11 85 20 ec ff 	vmovups %ymm0,-0x13e0(%rbp)
 11ee327:	ff 
 11ee328:	48 8d 0d a9 cb e4 ff 	lea    -0x1b3457(%rip),%rcx        # 103aed8 <__anon_35267>
 11ee32f:	48 89 4c 24 40       	mov    %rcx,0x40(%rsp)
 11ee334:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 11ee339:	48 8d 05 28 cb e4 ff 	lea    -0x1b34d8(%rip),%rax        # 103ae68 <__anon_35266>
 11ee340:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ee345:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee349:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ee34f:	48 8d 05 a2 ca e4 ff 	lea    -0x1b355e(%rip),%rax        # 103adf8 <__anon_35263>
 11ee356:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ee35b:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ee360:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ee364:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ee369:	48 8d 85 20 ec ff ff 	lea    -0x13e0(%rbp),%rax
 11ee370:	48 89 04 24          	mov    %rax,(%rsp)
 11ee374:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 11ee37b:	00 00 
 11ee37d:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ee381:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11ee385:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ee389:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ee38d:	c5 f8 77             	vzeroupper 
 11ee390:	e8 5b 22 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ee395:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 11ee39a:	66 45 85 f6          	test   %r14w,%r14w
 11ee39e:	0f 85 ca 1c 00 00    	jne    11f006e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x504e>
 11ee3a4:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11ee3a8:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ee3ac:	4d 39 ef             	cmp    %r13,%r15
 11ee3af:	73 74                	jae    11ee425 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3405>
 11ee3b1:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee3b5:	48 8b 38             	mov    (%rax),%rdi
 11ee3b8:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ee3bc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee3c0:	48 89 de             	mov    %rbx,%rsi
 11ee3c3:	4c 89 ea             	mov    %r13,%rdx
 11ee3c6:	31 c9                	xor    %ecx,%ecx
 11ee3c8:	ff 50 18             	call   *0x18(%rax)
 11ee3cb:	c5 fc 10 85 90 ec ff 	vmovups -0x1370(%rbp),%ymm0
 11ee3d2:	ff 
 11ee3d3:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ee3da:	ff 
 11ee3db:	c5 fc 10 85 20 ec ff 	vmovups -0x13e0(%rbp),%ymm0
 11ee3e2:	ff 
 11ee3e3:	c5 fc 10 8d 40 ec ff 	vmovups -0x13c0(%rbp),%ymm1
 11ee3ea:	ff 
 11ee3eb:	c5 fc 10 95 60 ec ff 	vmovups -0x13a0(%rbp),%ymm2
 11ee3f2:	ff 
 11ee3f3:	c5 fc 10 9d 80 ec ff 	vmovups -0x1380(%rbp),%ymm3
 11ee3fa:	ff 
 11ee3fb:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ee402:	ff 
 11ee403:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ee40a:	ff 
 11ee40b:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ee412:	ff 
 11ee413:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ee41a:	ff 
 11ee41b:	eb 2d                	jmp    11ee44a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x342a>
 11ee41d:	49 89 de             	mov    %rbx,%r14
 11ee420:	4d 89 ef             	mov    %r13,%r15
 11ee423:	eb 2d                	jmp    11ee452 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3432>
 11ee425:	4d 85 ff             	test   %r15,%r15
 11ee428:	74 1a                	je     11ee444 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3424>
 11ee42a:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee42e:	48 8b 38             	mov    (%rax),%rdi
 11ee431:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ee435:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee439:	4c 89 f6             	mov    %r14,%rsi
 11ee43c:	4c 89 fa             	mov    %r15,%rdx
 11ee43f:	31 c9                	xor    %ecx,%ecx
 11ee441:	ff 50 18             	call   *0x18(%rax)
 11ee444:	49 89 de             	mov    %rbx,%r14
 11ee447:	4d 89 ef             	mov    %r13,%r15
 11ee44a:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ee44e:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ee452:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ee459:	0f 94 c0             	sete   %al
 11ee45c:	41 20 c4             	and    %al,%r12b
 11ee45f:	80 bd a0 e0 ff ff 00 	cmpb   $0x0,-0x1f60(%rbp)
 11ee466:	0f 94 c0             	sete   %al
 11ee469:	41 84 c4             	test   %al,%r12b
 11ee46c:	0f 85 62 01 00 00    	jne    11ee5d4 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x35b4>
 11ee472:	80 bd e8 e3 ff ff 00 	cmpb   $0x0,-0x1c18(%rbp)
 11ee479:	0f 84 55 01 00 00    	je     11ee5d4 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x35b4>
 11ee47f:	48 8d 85 b8 e3 ff ff 	lea    -0x1c48(%rbp),%rax
 11ee486:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ee48d:	ff 
 11ee48e:	c5 fc 11 85 00 ec ff 	vmovups %ymm0,-0x1400(%rbp)
 11ee495:	ff 
 11ee496:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ee49d:	ff 
 11ee49e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ee4a5:	ff 
 11ee4a6:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ee4ad:	ff 
 11ee4ae:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ee4b5:	ff 
 11ee4b6:	c5 fc 11 9d f0 eb ff 	vmovups %ymm3,-0x1410(%rbp)
 11ee4bd:	ff 
 11ee4be:	c5 fc 11 95 d0 eb ff 	vmovups %ymm2,-0x1430(%rbp)
 11ee4c5:	ff 
 11ee4c6:	c5 fc 11 8d b0 eb ff 	vmovups %ymm1,-0x1450(%rbp)
 11ee4cd:	ff 
 11ee4ce:	c5 fc 11 85 90 eb ff 	vmovups %ymm0,-0x1470(%rbp)
 11ee4d5:	ff 
 11ee4d6:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 11ee4db:	48 8d 05 f6 c9 e4 ff 	lea    -0x1b360a(%rip),%rax        # 103aed8 <__anon_35267>
 11ee4e2:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ee4e7:	48 8d 05 7a c9 e4 ff 	lea    -0x1b3686(%rip),%rax        # 103ae68 <__anon_35266>
 11ee4ee:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ee4f3:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee4f7:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ee4fd:	48 8d 05 f4 c8 e4 ff 	lea    -0x1b370c(%rip),%rax        # 103adf8 <__anon_35263>
 11ee504:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ee509:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ee50e:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ee512:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ee517:	48 8d 85 90 eb ff ff 	lea    -0x1470(%rbp),%rax
 11ee51e:	48 89 04 24          	mov    %rax,(%rsp)
 11ee522:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 11ee529:	00 00 
 11ee52b:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ee52f:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 11ee533:	4c 89 e6             	mov    %r12,%rsi
 11ee536:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ee53a:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ee53e:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ee542:	c5 f8 77             	vzeroupper 
 11ee545:	e8 a6 20 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ee54a:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ee54e:	66 85 db             	test   %bx,%bx
 11ee551:	0f 85 24 1c 00 00    	jne    11f017b <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x515b>
 11ee557:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 11ee55b:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 11ee55f:	4d 39 fd             	cmp    %r15,%r13
 11ee562:	0f 83 87 00 00 00    	jae    11ee5ef <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x35cf>
 11ee568:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee56c:	48 8b 38             	mov    (%rax),%rdi
 11ee56f:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ee573:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee577:	4c 89 f6             	mov    %r14,%rsi
 11ee57a:	4c 89 fa             	mov    %r15,%rdx
 11ee57d:	31 c9                	xor    %ecx,%ecx
 11ee57f:	ff 50 18             	call   *0x18(%rax)
 11ee582:	c5 fc 10 85 00 ec ff 	vmovups -0x1400(%rbp),%ymm0
 11ee589:	ff 
 11ee58a:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ee591:	ff 
 11ee592:	c5 fc 10 85 90 eb ff 	vmovups -0x1470(%rbp),%ymm0
 11ee599:	ff 
 11ee59a:	c5 fc 10 8d b0 eb ff 	vmovups -0x1450(%rbp),%ymm1
 11ee5a1:	ff 
 11ee5a2:	c5 fc 10 95 d0 eb ff 	vmovups -0x1430(%rbp),%ymm2
 11ee5a9:	ff 
 11ee5aa:	c5 fc 10 9d f0 eb ff 	vmovups -0x1410(%rbp),%ymm3
 11ee5b1:	ff 
 11ee5b2:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ee5b9:	ff 
 11ee5ba:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ee5c1:	ff 
 11ee5c2:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ee5c9:	ff 
 11ee5ca:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ee5d1:	ff 
 11ee5d2:	eb 40                	jmp    11ee614 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x35f4>
 11ee5d4:	4d 89 f4             	mov    %r14,%r12
 11ee5d7:	4d 89 fd             	mov    %r15,%r13
 11ee5da:	48 8d 8d 70 e0 ff ff 	lea    -0x1f90(%rbp),%rcx
 11ee5e1:	80 bd a0 e0 ff ff 00 	cmpb   $0x0,-0x1f60(%rbp)
 11ee5e8:	75 46                	jne    11ee630 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3610>
 11ee5ea:	e9 38 04 00 00       	jmp    11eea27 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3a07>
 11ee5ef:	4d 85 ed             	test   %r13,%r13
 11ee5f2:	74 1a                	je     11ee60e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x35ee>
 11ee5f4:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee5f8:	48 8b 38             	mov    (%rax),%rdi
 11ee5fb:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ee5ff:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee603:	4c 89 e6             	mov    %r12,%rsi
 11ee606:	4c 89 ea             	mov    %r13,%rdx
 11ee609:	31 c9                	xor    %ecx,%ecx
 11ee60b:	ff 50 18             	call   *0x18(%rax)
 11ee60e:	4d 89 f4             	mov    %r14,%r12
 11ee611:	4d 89 fd             	mov    %r15,%r13
 11ee614:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 11ee618:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 11ee61c:	48 8d 8d 70 e0 ff ff 	lea    -0x1f90(%rbp),%rcx
 11ee623:	80 bd a0 e0 ff ff 00 	cmpb   $0x0,-0x1f60(%rbp)
 11ee62a:	0f 84 f7 03 00 00    	je     11eea27 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3a07>
 11ee630:	80 bd e8 e3 ff ff 00 	cmpb   $0x0,-0x1c18(%rbp)
 11ee637:	0f 84 ea 03 00 00    	je     11eea27 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3a07>
 11ee63d:	48 8d 85 b8 e3 ff ff 	lea    -0x1c48(%rbp),%rax
 11ee644:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ee64b:	ff 
 11ee64c:	c5 fc 11 85 70 eb ff 	vmovups %ymm0,-0x1490(%rbp)
 11ee653:	ff 
 11ee654:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ee65b:	ff 
 11ee65c:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ee663:	ff 
 11ee664:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ee66b:	ff 
 11ee66c:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ee673:	ff 
 11ee674:	c5 fc 11 9d 60 eb ff 	vmovups %ymm3,-0x14a0(%rbp)
 11ee67b:	ff 
 11ee67c:	c5 fc 11 95 40 eb ff 	vmovups %ymm2,-0x14c0(%rbp)
 11ee683:	ff 
 11ee684:	c5 fc 11 8d 20 eb ff 	vmovups %ymm1,-0x14e0(%rbp)
 11ee68b:	ff 
 11ee68c:	c5 fc 11 85 00 eb ff 	vmovups %ymm0,-0x1500(%rbp)
 11ee693:	ff 
 11ee694:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 11ee699:	48 8d 05 38 c8 e4 ff 	lea    -0x1b37c8(%rip),%rax        # 103aed8 <__anon_35267>
 11ee6a0:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 11ee6a5:	48 89 4c 24 38       	mov    %rcx,0x38(%rsp)
 11ee6aa:	48 8d 05 b7 c7 e4 ff 	lea    -0x1b3849(%rip),%rax        # 103ae68 <__anon_35266>
 11ee6b1:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 11ee6b6:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee6ba:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 11ee6c0:	48 8d 05 31 c7 e4 ff 	lea    -0x1b38cf(%rip),%rax        # 103adf8 <__anon_35263>
 11ee6c7:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 11ee6cc:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 11ee6d1:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11ee6d5:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 11ee6da:	48 8d 85 00 eb ff ff 	lea    -0x1500(%rbp),%rax
 11ee6e1:	48 89 04 24          	mov    %rax,(%rsp)
 11ee6e5:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 11ee6e9:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11ee6ed:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11ee6f1:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 11ee6f5:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 11ee6f9:	c5 f8 77             	vzeroupper 
 11ee6fc:	e8 ef 1e 00 00       	call   11f05f0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_43678>
 11ee701:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 11ee705:	66 85 db             	test   %bx,%bx
 11ee708:	0f 85 67 1b 00 00    	jne    11f0275 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5255>
 11ee70e:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 11ee712:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 11ee716:	4d 39 ef             	cmp    %r13,%r15
 11ee719:	0f 83 e9 02 00 00    	jae    11eea08 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x39e8>
 11ee71f:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee723:	48 8b 38             	mov    (%rax),%rdi
 11ee726:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ee72a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee72e:	4c 89 e6             	mov    %r12,%rsi
 11ee731:	4c 89 ea             	mov    %r13,%rdx
 11ee734:	31 c9                	xor    %ecx,%ecx
 11ee736:	ff 50 18             	call   *0x18(%rax)
 11ee739:	c5 fc 10 85 70 eb ff 	vmovups -0x1490(%rbp),%ymm0
 11ee740:	ff 
 11ee741:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 11ee748:	ff 
 11ee749:	c5 fc 10 85 00 eb ff 	vmovups -0x1500(%rbp),%ymm0
 11ee750:	ff 
 11ee751:	c5 fc 10 8d 20 eb ff 	vmovups -0x14e0(%rbp),%ymm1
 11ee758:	ff 
 11ee759:	c5 fc 10 95 40 eb ff 	vmovups -0x14c0(%rbp),%ymm2
 11ee760:	ff 
 11ee761:	c5 fc 10 9d 60 eb ff 	vmovups -0x14a0(%rbp),%ymm3
 11ee768:	ff 
 11ee769:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 11ee770:	ff 
 11ee771:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 11ee778:	ff 
 11ee779:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 11ee780:	ff 
 11ee781:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 11ee788:	ff 
 11ee789:	4c 3b bd 78 fd ff ff 	cmp    -0x288(%rbp),%r15
 11ee790:	0f 82 a4 02 00 00    	jb     11eea3a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3a1a>
 11ee796:	4d 85 ff             	test   %r15,%r15
 11ee799:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 11ee79d:	74 1b                	je     11ee7ba <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x379a>
 11ee79f:	49 8b 3c 24          	mov    (%r12),%rdi
 11ee7a3:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 11ee7a8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee7ac:	48 89 de             	mov    %rbx,%rsi
 11ee7af:	4c 89 fa             	mov    %r15,%rdx
 11ee7b2:	31 c9                	xor    %ecx,%ecx
 11ee7b4:	c5 f8 77             	vzeroupper 
 11ee7b7:	ff 50 18             	call   *0x18(%rax)
 11ee7ba:	80 bd a0 e0 ff ff 00 	cmpb   $0x0,-0x1f60(%rbp)
 11ee7c1:	74 5e                	je     11ee821 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3801>
 11ee7c3:	48 8b 95 78 e0 ff ff 	mov    -0x1f88(%rbp),%rdx
 11ee7ca:	48 8b 9d 80 e0 ff ff 	mov    -0x1f80(%rbp),%rbx
 11ee7d1:	4c 8b b5 88 e0 ff ff 	mov    -0x1f78(%rbp),%r14
 11ee7d8:	4d 8b 3c 24          	mov    (%r12),%r15
 11ee7dc:	4d 8b 64 24 08       	mov    0x8(%r12),%r12
 11ee7e1:	48 85 d2             	test   %rdx,%rdx
 11ee7e4:	74 1f                	je     11ee805 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x37e5>
 11ee7e6:	48 8b b5 70 e0 ff ff 	mov    -0x1f90(%rbp),%rsi
 11ee7ed:	48 c1 e2 02          	shl    $0x2,%rdx
 11ee7f1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee7f5:	4c 89 ff             	mov    %r15,%rdi
 11ee7f8:	b9 02 00 00 00       	mov    $0x2,%ecx
 11ee7fd:	c5 f8 77             	vzeroupper 
 11ee800:	41 ff 54 24 18       	call   *0x18(%r12)
 11ee805:	4d 85 f6             	test   %r14,%r14
 11ee808:	74 17                	je     11ee821 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3801>
 11ee80a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee80e:	4c 89 ff             	mov    %r15,%rdi
 11ee811:	48 89 de             	mov    %rbx,%rsi
 11ee814:	4c 89 f2             	mov    %r14,%rdx
 11ee817:	31 c9                	xor    %ecx,%ecx
 11ee819:	c5 f8 77             	vzeroupper 
 11ee81c:	41 ff 54 24 18       	call   *0x18(%r12)
 11ee821:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee825:	48 8d 85 70 e0 ff ff 	lea    -0x1f90(%rbp),%rax
 11ee82c:	c5 fc 11 40 18       	vmovups %ymm0,0x18(%rax)
 11ee831:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ee835:	4c 8d a5 b8 e3 ff ff 	lea    -0x1c48(%rbp),%r12
 11ee83c:	80 bd e8 e3 ff ff 00 	cmpb   $0x0,-0x1c18(%rbp)
 11ee843:	74 66                	je     11ee8ab <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x388b>
 11ee845:	48 8b 95 c0 e3 ff ff 	mov    -0x1c40(%rbp),%rdx
 11ee84c:	48 8b 9d c8 e3 ff ff 	mov    -0x1c38(%rbp),%rbx
 11ee853:	4c 8b b5 d0 e3 ff ff 	mov    -0x1c30(%rbp),%r14
 11ee85a:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee85e:	4c 8b 38             	mov    (%rax),%r15
 11ee861:	4c 8b 68 08          	mov    0x8(%rax),%r13
 11ee865:	48 85 d2             	test   %rdx,%rdx
 11ee868:	74 22                	je     11ee88c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x386c>
 11ee86a:	48 8b b5 b8 e3 ff ff 	mov    -0x1c48(%rbp),%rsi
 11ee871:	48 c1 e2 02          	shl    $0x2,%rdx
 11ee875:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee879:	4c 89 ff             	mov    %r15,%rdi
 11ee87c:	b9 02 00 00 00       	mov    $0x2,%ecx
 11ee881:	c5 f8 77             	vzeroupper 
 11ee884:	41 ff 55 18          	call   *0x18(%r13)
 11ee888:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee88c:	4d 85 f6             	test   %r14,%r14
 11ee88f:	74 1a                	je     11ee8ab <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x388b>
 11ee891:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee895:	4c 89 ff             	mov    %r15,%rdi
 11ee898:	48 89 de             	mov    %rbx,%rsi
 11ee89b:	4c 89 f2             	mov    %r14,%rdx
 11ee89e:	31 c9                	xor    %ecx,%ecx
 11ee8a0:	c5 f8 77             	vzeroupper 
 11ee8a3:	41 ff 55 18          	call   *0x18(%r13)
 11ee8a7:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee8ab:	c4 c1 7c 11 44 24 18 	vmovups %ymm0,0x18(%r12)
 11ee8b2:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 11ee8b8:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ee8bf:	0f 84 c1 00 00 00    	je     11ee986 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3966>
 11ee8c5:	48 8b 95 38 fe ff ff 	mov    -0x1c8(%rbp),%rdx
 11ee8cc:	48 8b b5 40 fe ff ff 	mov    -0x1c0(%rbp),%rsi
 11ee8d3:	4c 8b a5 48 fe ff ff 	mov    -0x1b8(%rbp),%r12
 11ee8da:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 11ee8e1:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 11ee8e5:	4c 8b ad 68 fe ff ff 	mov    -0x198(%rbp),%r13
 11ee8ec:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 11ee8f3:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 11ee8f7:	4c 8b b5 78 fe ff ff 	mov    -0x188(%rbp),%r14
 11ee8fe:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee902:	4c 8b 38             	mov    (%rax),%r15
 11ee905:	48 8b 58 08          	mov    0x8(%rax),%rbx
 11ee909:	48 85 d2             	test   %rdx,%rdx
 11ee90c:	74 2b                	je     11ee939 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3919>
 11ee90e:	4c 89 75 d0          	mov    %r14,-0x30(%rbp)
 11ee912:	49 89 f6             	mov    %rsi,%r14
 11ee915:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 11ee91c:	48 c1 e2 02          	shl    $0x2,%rdx
 11ee920:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee924:	4c 89 ff             	mov    %r15,%rdi
 11ee927:	b9 02 00 00 00       	mov    $0x2,%ecx
 11ee92c:	c5 f8 77             	vzeroupper 
 11ee92f:	ff 53 18             	call   *0x18(%rbx)
 11ee932:	4c 89 f6             	mov    %r14,%rsi
 11ee935:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 11ee939:	4d 85 e4             	test   %r12,%r12
 11ee93c:	74 12                	je     11ee950 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3930>
 11ee93e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee942:	4c 89 ff             	mov    %r15,%rdi
 11ee945:	4c 89 e2             	mov    %r12,%rdx
 11ee948:	31 c9                	xor    %ecx,%ecx
 11ee94a:	c5 f8 77             	vzeroupper 
 11ee94d:	ff 53 18             	call   *0x18(%rbx)
 11ee950:	4d 85 ed             	test   %r13,%r13
 11ee953:	74 16                	je     11ee96b <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x394b>
 11ee955:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee959:	4c 89 ff             	mov    %r15,%rdi
 11ee95c:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 11ee960:	4c 89 ea             	mov    %r13,%rdx
 11ee963:	31 c9                	xor    %ecx,%ecx
 11ee965:	c5 f8 77             	vzeroupper 
 11ee968:	ff 53 18             	call   *0x18(%rbx)
 11ee96b:	4d 85 f6             	test   %r14,%r14
 11ee96e:	74 16                	je     11ee986 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3966>
 11ee970:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee974:	4c 89 ff             	mov    %r15,%rdi
 11ee977:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 11ee97b:	4c 89 f2             	mov    %r14,%rdx
 11ee97e:	31 c9                	xor    %ecx,%ecx
 11ee980:	c5 f8 77             	vzeroupper 
 11ee983:	ff 53 18             	call   *0x18(%rbx)
 11ee986:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ee98d:	74 60                	je     11ee9ef <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x39cf>
 11ee98f:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 11ee996:	48 8b 9d 40 ff ff ff 	mov    -0xc0(%rbp),%rbx
 11ee99d:	4c 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%r14
 11ee9a4:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ee9a8:	4c 8b 38             	mov    (%rax),%r15
 11ee9ab:	4c 8b 60 08          	mov    0x8(%rax),%r12
 11ee9af:	48 85 d2             	test   %rdx,%rdx
 11ee9b2:	74 1f                	je     11ee9d3 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x39b3>
 11ee9b4:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 11ee9bb:	48 c1 e2 02          	shl    $0x2,%rdx
 11ee9bf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee9c3:	4c 89 ff             	mov    %r15,%rdi
 11ee9c6:	b9 02 00 00 00       	mov    $0x2,%ecx
 11ee9cb:	c5 f8 77             	vzeroupper 
 11ee9ce:	41 ff 54 24 18       	call   *0x18(%r12)
 11ee9d3:	4d 85 f6             	test   %r14,%r14
 11ee9d6:	74 17                	je     11ee9ef <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x39cf>
 11ee9d8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ee9dc:	4c 89 ff             	mov    %r15,%rdi
 11ee9df:	48 89 de             	mov    %rbx,%rsi
 11ee9e2:	4c 89 f2             	mov    %r14,%rdx
 11ee9e5:	31 c9                	xor    %ecx,%ecx
 11ee9e7:	c5 f8 77             	vzeroupper 
 11ee9ea:	41 ff 54 24 18       	call   *0x18(%r12)
 11ee9ef:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11ee9f3:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11ee9f7:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 11ee9fb:	48 c7 40 10 00 00 00 	movq   $0x0,0x10(%rax)
 11eea02:	00 
 11eea03:	e9 d1 02 00 00       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11eea08:	4d 85 ff             	test   %r15,%r15
 11eea0b:	74 1a                	je     11eea27 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3a07>
 11eea0d:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eea11:	48 8b 38             	mov    (%rax),%rdi
 11eea14:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eea18:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eea1c:	48 89 de             	mov    %rbx,%rsi
 11eea1f:	4c 89 fa             	mov    %r15,%rdx
 11eea22:	31 c9                	xor    %ecx,%ecx
 11eea24:	ff 50 18             	call   *0x18(%rax)
 11eea27:	4c 89 e3             	mov    %r12,%rbx
 11eea2a:	4d 89 ef             	mov    %r13,%r15
 11eea2d:	4c 3b bd 78 fd ff ff 	cmp    -0x288(%rbp),%r15
 11eea34:	0f 83 5c fd ff ff    	jae    11ee796 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3776>
 11eea3a:	48 89 5d 90          	mov    %rbx,-0x70(%rbp)
 11eea3e:	c5 fc 10 85 00 fe ff 	vmovups -0x200(%rbp),%ymm0
 11eea45:	ff 
 11eea46:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11eea4a:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11eea4f:	c5 fc 10 85 90 fd ff 	vmovups -0x270(%rbp),%ymm0
 11eea56:	ff 
 11eea57:	c5 fc 10 8d b0 fd ff 	vmovups -0x250(%rbp),%ymm1
 11eea5e:	ff 
 11eea5f:	c5 fc 10 95 d0 fd ff 	vmovups -0x230(%rbp),%ymm2
 11eea66:	ff 
 11eea67:	c5 fc 10 9d f0 fd ff 	vmovups -0x210(%rbp),%ymm3
 11eea6e:	ff 
 11eea6f:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11eea74:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11eea79:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11eea7e:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11eea82:	80 bd a0 e0 ff ff 00 	cmpb   $0x0,-0x1f60(%rbp)
 11eea89:	74 5e                	je     11eeae9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3ac9>
 11eea8b:	48 8b 95 78 e0 ff ff 	mov    -0x1f88(%rbp),%rdx
 11eea92:	48 8b 9d 80 e0 ff ff 	mov    -0x1f80(%rbp),%rbx
 11eea99:	4c 8b b5 88 e0 ff ff 	mov    -0x1f78(%rbp),%r14
 11eeaa0:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eeaa4:	4c 8b 20             	mov    (%rax),%r12
 11eeaa7:	4c 8b 68 08          	mov    0x8(%rax),%r13
 11eeaab:	48 85 d2             	test   %rdx,%rdx
 11eeaae:	74 1e                	je     11eeace <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3aae>
 11eeab0:	48 8b b5 70 e0 ff ff 	mov    -0x1f90(%rbp),%rsi
 11eeab7:	48 c1 e2 02          	shl    $0x2,%rdx
 11eeabb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eeabf:	4c 89 e7             	mov    %r12,%rdi
 11eeac2:	b9 02 00 00 00       	mov    $0x2,%ecx
 11eeac7:	c5 f8 77             	vzeroupper 
 11eeaca:	41 ff 55 18          	call   *0x18(%r13)
 11eeace:	4d 85 f6             	test   %r14,%r14
 11eead1:	74 16                	je     11eeae9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3ac9>
 11eead3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eead7:	4c 89 e7             	mov    %r12,%rdi
 11eeada:	48 89 de             	mov    %rbx,%rsi
 11eeadd:	4c 89 f2             	mov    %r14,%rdx
 11eeae0:	31 c9                	xor    %ecx,%ecx
 11eeae2:	c5 f8 77             	vzeroupper 
 11eeae5:	41 ff 55 18          	call   *0x18(%r13)
 11eeae9:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11eeaed:	48 8d 85 70 e0 ff ff 	lea    -0x1f90(%rbp),%rax
 11eeaf4:	c5 fc 11 40 18       	vmovups %ymm0,0x18(%rax)
 11eeaf9:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11eeafd:	4c 8d ad b8 e3 ff ff 	lea    -0x1c48(%rbp),%r13
 11eeb04:	80 bd e8 e3 ff ff 00 	cmpb   $0x0,-0x1c18(%rbp)
 11eeb0b:	74 69                	je     11eeb76 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3b56>
 11eeb0d:	48 8b 95 c0 e3 ff ff 	mov    -0x1c40(%rbp),%rdx
 11eeb14:	48 8b b5 c8 e3 ff ff 	mov    -0x1c38(%rbp),%rsi
 11eeb1b:	4c 8b b5 d0 e3 ff ff 	mov    -0x1c30(%rbp),%r14
 11eeb22:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eeb26:	4c 8b 20             	mov    (%rax),%r12
 11eeb29:	48 8b 58 08          	mov    0x8(%rax),%rbx
 11eeb2d:	48 85 d2             	test   %rdx,%rdx
 11eeb30:	74 29                	je     11eeb5b <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3b3b>
 11eeb32:	48 89 75 98          	mov    %rsi,-0x68(%rbp)
 11eeb36:	48 8b b5 b8 e3 ff ff 	mov    -0x1c48(%rbp),%rsi
 11eeb3d:	48 c1 e2 02          	shl    $0x2,%rdx
 11eeb41:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eeb45:	4c 89 e7             	mov    %r12,%rdi
 11eeb48:	b9 02 00 00 00       	mov    $0x2,%ecx
 11eeb4d:	c5 f8 77             	vzeroupper 
 11eeb50:	ff 53 18             	call   *0x18(%rbx)
 11eeb53:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 11eeb57:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11eeb5b:	4d 85 f6             	test   %r14,%r14
 11eeb5e:	74 16                	je     11eeb76 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3b56>
 11eeb60:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eeb64:	4c 89 e7             	mov    %r12,%rdi
 11eeb67:	4c 89 f2             	mov    %r14,%rdx
 11eeb6a:	31 c9                	xor    %ecx,%ecx
 11eeb6c:	c5 f8 77             	vzeroupper 
 11eeb6f:	ff 53 18             	call   *0x18(%rbx)
 11eeb72:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11eeb76:	c4 c1 7c 11 45 18    	vmovups %ymm0,0x18(%r13)
 11eeb7c:	c4 c1 7c 11 45 00    	vmovups %ymm0,0x0(%r13)
 11eeb82:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11eeb89:	0f 84 ce 00 00 00    	je     11eec5d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3c3d>
 11eeb8f:	48 8b 95 38 fe ff ff 	mov    -0x1c8(%rbp),%rdx
 11eeb96:	48 8b b5 40 fe ff ff 	mov    -0x1c0(%rbp),%rsi
 11eeb9d:	4c 8b b5 48 fe ff ff 	mov    -0x1b8(%rbp),%r14
 11eeba4:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 11eebab:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 11eebaf:	48 8b 9d 68 fe ff ff 	mov    -0x198(%rbp),%rbx
 11eebb6:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 11eebbd:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 11eebc1:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11eebc8:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 11eebcc:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eebd0:	4c 8b 28             	mov    (%rax),%r13
 11eebd3:	4c 8b 60 08          	mov    0x8(%rax),%r12
 11eebd7:	48 85 d2             	test   %rdx,%rdx
 11eebda:	74 2d                	je     11eec09 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3be9>
 11eebdc:	48 89 b5 78 ff ff ff 	mov    %rsi,-0x88(%rbp)
 11eebe3:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 11eebea:	48 c1 e2 02          	shl    $0x2,%rdx
 11eebee:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eebf2:	4c 89 ef             	mov    %r13,%rdi
 11eebf5:	b9 02 00 00 00       	mov    $0x2,%ecx
 11eebfa:	c5 f8 77             	vzeroupper 
 11eebfd:	41 ff 54 24 18       	call   *0x18(%r12)
 11eec02:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11eec09:	4d 85 f6             	test   %r14,%r14
 11eec0c:	74 14                	je     11eec22 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3c02>
 11eec0e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eec12:	4c 89 ef             	mov    %r13,%rdi
 11eec15:	4c 89 f2             	mov    %r14,%rdx
 11eec18:	31 c9                	xor    %ecx,%ecx
 11eec1a:	c5 f8 77             	vzeroupper 
 11eec1d:	41 ff 54 24 18       	call   *0x18(%r12)
 11eec22:	48 85 db             	test   %rbx,%rbx
 11eec25:	74 18                	je     11eec3f <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3c1f>
 11eec27:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eec2b:	4c 89 ef             	mov    %r13,%rdi
 11eec2e:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 11eec32:	48 89 da             	mov    %rbx,%rdx
 11eec35:	31 c9                	xor    %ecx,%ecx
 11eec37:	c5 f8 77             	vzeroupper 
 11eec3a:	41 ff 54 24 18       	call   *0x18(%r12)
 11eec3f:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11eec43:	48 85 d2             	test   %rdx,%rdx
 11eec46:	74 15                	je     11eec5d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3c3d>
 11eec48:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eec4c:	4c 89 ef             	mov    %r13,%rdi
 11eec4f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 11eec53:	31 c9                	xor    %ecx,%ecx
 11eec55:	c5 f8 77             	vzeroupper 
 11eec58:	41 ff 54 24 18       	call   *0x18(%r12)
 11eec5d:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eec64:	74 5e                	je     11eecc4 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3ca4>
 11eec66:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 11eec6d:	48 8b 9d 40 ff ff ff 	mov    -0xc0(%rbp),%rbx
 11eec74:	4c 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%r14
 11eec7b:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eec7f:	4c 8b 20             	mov    (%rax),%r12
 11eec82:	4c 8b 68 08          	mov    0x8(%rax),%r13
 11eec86:	48 85 d2             	test   %rdx,%rdx
 11eec89:	74 1e                	je     11eeca9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3c89>
 11eec8b:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 11eec92:	48 c1 e2 02          	shl    $0x2,%rdx
 11eec96:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eec9a:	4c 89 e7             	mov    %r12,%rdi
 11eec9d:	b9 02 00 00 00       	mov    $0x2,%ecx
 11eeca2:	c5 f8 77             	vzeroupper 
 11eeca5:	41 ff 55 18          	call   *0x18(%r13)
 11eeca9:	4d 85 f6             	test   %r14,%r14
 11eecac:	74 16                	je     11eecc4 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3ca4>
 11eecae:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eecb2:	4c 89 e7             	mov    %r12,%rdi
 11eecb5:	48 89 de             	mov    %rbx,%rsi
 11eecb8:	4c 89 f2             	mov    %r14,%rdx
 11eecbb:	31 c9                	xor    %ecx,%ecx
 11eecbd:	c5 f8 77             	vzeroupper 
 11eecc0:	41 ff 55 18          	call   *0x18(%r13)
 11eecc4:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11eecc8:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 11eecce:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 11eecd2:	48 89 08             	mov    %rcx,(%rax)
 11eecd5:	4c 89 78 08          	mov    %r15,0x8(%rax)
 11eecd9:	48 81 c4 c8 40 00 00 	add    $0x40c8,%rsp
 11eece0:	5b                   	pop    %rbx
 11eece1:	41 5c                	pop    %r12
 11eece3:	41 5d                	pop    %r13
 11eece5:	41 5e                	pop    %r14
 11eece7:	41 5f                	pop    %r15
 11eece9:	5d                   	pop    %rbp
 11eecea:	c5 f8 77             	vzeroupper 
 11eeced:	c3                   	ret    
 11eecee:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11eecf5:	74 42                	je     11eed39 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3d19>
 11eecf7:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11eecfe:	ff 
 11eecff:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11eed06:	ff 
 11eed07:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11eed0e:	ff 
 11eed0f:	c5 fc 11 95 d8 d3 ff 	vmovups %ymm2,-0x2c28(%rbp)
 11eed16:	ff 
 11eed17:	c5 fc 11 8d c0 d3 ff 	vmovups %ymm1,-0x2c40(%rbp)
 11eed1e:	ff 
 11eed1f:	c5 fc 11 85 a0 d3 ff 	vmovups %ymm0,-0x2c60(%rbp)
 11eed26:	ff 
 11eed27:	48 8d bd a0 d3 ff ff 	lea    -0x2c60(%rbp),%rdi
 11eed2e:	4c 89 ee             	mov    %r13,%rsi
 11eed31:	c5 f8 77             	vzeroupper 
 11eed34:	e8 07 24 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11eed39:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eed40:	0f 84 0e 12 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11eed46:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11eed4d:	ff 
 11eed4e:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11eed55:	ff 
 11eed56:	c5 fc 11 8d 20 e9 ff 	vmovups %ymm1,-0x16e0(%rbp)
 11eed5d:	ff 
 11eed5e:	c5 fc 11 85 10 e9 ff 	vmovups %ymm0,-0x16f0(%rbp)
 11eed65:	ff 
 11eed66:	48 8d bd 10 e9 ff ff 	lea    -0x16f0(%rbp),%rdi
 11eed6d:	e9 d7 11 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11eed72:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11eed76:	66 89 41 10          	mov    %ax,0x10(%rcx)
 11eed7a:	e9 5a ff ff ff       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11eed7f:	83 f8 1a             	cmp    $0x1a,%eax
 11eed82:	0f 84 ed 15 00 00    	je     11f0375 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5355>
 11eed88:	83 f8 4f             	cmp    $0x4f,%eax
 11eed8b:	0f 85 3c 16 00 00    	jne    11f03cd <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x53ad>
 11eed91:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eed98:	74 32                	je     11eedcc <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3dac>
 11eed9a:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11eeda1:	ff 
 11eeda2:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11eeda9:	ff 
 11eedaa:	c5 fc 11 8d 80 e9 ff 	vmovups %ymm1,-0x1680(%rbp)
 11eedb1:	ff 
 11eedb2:	c5 fc 11 85 70 e9 ff 	vmovups %ymm0,-0x1690(%rbp)
 11eedb9:	ff 
 11eedba:	48 8d bd 70 e9 ff ff 	lea    -0x1690(%rbp),%rdi
 11eedc1:	4c 89 ee             	mov    %r13,%rsi
 11eedc4:	c5 f8 77             	vzeroupper 
 11eedc7:	e8 e4 4c 01 00       	call   1203ab0 <br.encoder.block_split_plan.Plan.deinit>
 11eedcc:	c5 f8 10 05 ec 1c e7 	vmovups -0x18e314(%rip),%xmm0        # 1060ac0 <__anon_77454>
 11eedd3:	ff 
 11eedd4:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11eedd8:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 11eeddc:	48 c7 40 10 4f 00 00 	movq   $0x4f,0x10(%rax)
 11eede3:	00 
 11eede4:	e9 f0 fe ff ff       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11eede9:	48 85 db             	test   %rbx,%rbx
 11eedec:	74 17                	je     11eee05 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3de5>
 11eedee:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11eedf2:	49 8b 45 08          	mov    0x8(%r13),%rax
 11eedf6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eedfa:	4c 89 f6             	mov    %r14,%rsi
 11eedfd:	48 89 da             	mov    %rbx,%rdx
 11eee00:	31 c9                	xor    %ecx,%ecx
 11eee02:	ff 50 18             	call   *0x18(%rax)
 11eee05:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11eee0c:	ff 
 11eee0d:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11eee11:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11eee16:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11eee1d:	ff 
 11eee1e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11eee25:	ff 
 11eee26:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11eee2d:	ff 
 11eee2e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11eee35:	ff 
 11eee36:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11eee3b:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11eee40:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11eee45:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11eee49:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11eee50:	4c 89 ee             	mov    %r13,%rsi
 11eee53:	c5 f8 77             	vzeroupper 
 11eee56:	e8 b5 21 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11eee5b:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11eee62:	74 42                	je     11eeea6 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3e86>
 11eee64:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11eee6b:	ff 
 11eee6c:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11eee73:	ff 
 11eee74:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11eee7b:	ff 
 11eee7c:	c5 fc 11 95 98 d1 ff 	vmovups %ymm2,-0x2e68(%rbp)
 11eee83:	ff 
 11eee84:	c5 fc 11 8d 80 d1 ff 	vmovups %ymm1,-0x2e80(%rbp)
 11eee8b:	ff 
 11eee8c:	c5 fc 11 85 60 d1 ff 	vmovups %ymm0,-0x2ea0(%rbp)
 11eee93:	ff 
 11eee94:	48 8d bd 60 d1 ff ff 	lea    -0x2ea0(%rbp),%rdi
 11eee9b:	4c 89 ee             	mov    %r13,%rsi
 11eee9e:	c5 f8 77             	vzeroupper 
 11eeea1:	e8 9a 22 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11eeea6:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eeead:	0f 84 ad 11 00 00    	je     11f0060 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5040>
 11eeeb3:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11eeeba:	ff 
 11eeebb:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11eeec2:	ff 
 11eeec3:	c5 fc 11 8d 00 e8 ff 	vmovups %ymm1,-0x1800(%rbp)
 11eeeca:	ff 
 11eeecb:	c5 fc 11 85 f0 e7 ff 	vmovups %ymm0,-0x1810(%rbp)
 11eeed2:	ff 
 11eeed3:	48 8d bd f0 e7 ff ff 	lea    -0x1810(%rbp),%rdi
 11eeeda:	e9 c6 05 00 00       	jmp    11ef4a5 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4485>
 11eeedf:	4d 85 ff             	test   %r15,%r15
 11eeee2:	74 17                	je     11eeefb <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3edb>
 11eeee4:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11eeee8:	49 8b 45 08          	mov    0x8(%r13),%rax
 11eeeec:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eeef0:	4c 89 e6             	mov    %r12,%rsi
 11eeef3:	4c 89 fa             	mov    %r15,%rdx
 11eeef6:	31 c9                	xor    %ecx,%ecx
 11eeef8:	ff 50 18             	call   *0x18(%rax)
 11eeefb:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11eef02:	ff 
 11eef03:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11eef07:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11eef0c:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11eef13:	ff 
 11eef14:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11eef1b:	ff 
 11eef1c:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11eef23:	ff 
 11eef24:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11eef2b:	ff 
 11eef2c:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11eef31:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11eef36:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11eef3b:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11eef3f:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11eef46:	4c 89 ee             	mov    %r13,%rsi
 11eef49:	c5 f8 77             	vzeroupper 
 11eef4c:	e8 bf 20 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11eef51:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11eef58:	74 42                	je     11eef9c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3f7c>
 11eef5a:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11eef61:	ff 
 11eef62:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11eef69:	ff 
 11eef6a:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11eef71:	ff 
 11eef72:	c5 fc 11 95 38 d1 ff 	vmovups %ymm2,-0x2ec8(%rbp)
 11eef79:	ff 
 11eef7a:	c5 fc 11 8d 20 d1 ff 	vmovups %ymm1,-0x2ee0(%rbp)
 11eef81:	ff 
 11eef82:	c5 fc 11 85 00 d1 ff 	vmovups %ymm0,-0x2f00(%rbp)
 11eef89:	ff 
 11eef8a:	48 8d bd 00 d1 ff ff 	lea    -0x2f00(%rbp),%rdi
 11eef91:	4c 89 ee             	mov    %r13,%rsi
 11eef94:	c5 f8 77             	vzeroupper 
 11eef97:	e8 a4 21 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11eef9c:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eefa3:	0f 84 ab 0f 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11eefa9:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11eefb0:	ff 
 11eefb1:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11eefb8:	ff 
 11eefb9:	c5 fc 11 8d d0 e7 ff 	vmovups %ymm1,-0x1830(%rbp)
 11eefc0:	ff 
 11eefc1:	c5 fc 11 85 c0 e7 ff 	vmovups %ymm0,-0x1840(%rbp)
 11eefc8:	ff 
 11eefc9:	48 8d bd c0 e7 ff ff 	lea    -0x1840(%rbp),%rdi
 11eefd0:	e9 74 0f 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11eefd5:	48 85 db             	test   %rbx,%rbx
 11eefd8:	74 17                	je     11eeff1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3fd1>
 11eefda:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11eefde:	49 8b 45 08          	mov    0x8(%r13),%rax
 11eefe2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eefe6:	4c 89 f6             	mov    %r14,%rsi
 11eefe9:	48 89 da             	mov    %rbx,%rdx
 11eefec:	31 c9                	xor    %ecx,%ecx
 11eefee:	ff 50 18             	call   *0x18(%rax)
 11eeff1:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11eeff8:	ff 
 11eeff9:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11eeffd:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef002:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef009:	ff 
 11ef00a:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef011:	ff 
 11ef012:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef019:	ff 
 11ef01a:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef021:	ff 
 11ef022:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef027:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef02c:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef031:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef035:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef03c:	4c 89 ee             	mov    %r13,%rsi
 11ef03f:	c5 f8 77             	vzeroupper 
 11ef042:	e8 c9 1f 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef047:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef04e:	74 42                	je     11ef092 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4072>
 11ef050:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef057:	ff 
 11ef058:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef05f:	ff 
 11ef060:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef067:	ff 
 11ef068:	c5 fc 11 95 d8 d0 ff 	vmovups %ymm2,-0x2f28(%rbp)
 11ef06f:	ff 
 11ef070:	c5 fc 11 8d c0 d0 ff 	vmovups %ymm1,-0x2f40(%rbp)
 11ef077:	ff 
 11ef078:	c5 fc 11 85 a0 d0 ff 	vmovups %ymm0,-0x2f60(%rbp)
 11ef07f:	ff 
 11ef080:	48 8d bd a0 d0 ff ff 	lea    -0x2f60(%rbp),%rdi
 11ef087:	4c 89 ee             	mov    %r13,%rsi
 11ef08a:	c5 f8 77             	vzeroupper 
 11ef08d:	e8 ae 20 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef092:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef099:	0f 84 c1 0f 00 00    	je     11f0060 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5040>
 11ef09f:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef0a6:	ff 
 11ef0a7:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef0ae:	ff 
 11ef0af:	c5 fc 11 8d a0 e7 ff 	vmovups %ymm1,-0x1860(%rbp)
 11ef0b6:	ff 
 11ef0b7:	c5 fc 11 85 90 e7 ff 	vmovups %ymm0,-0x1870(%rbp)
 11ef0be:	ff 
 11ef0bf:	48 8d bd 90 e7 ff ff 	lea    -0x1870(%rbp),%rdi
 11ef0c6:	e9 da 03 00 00       	jmp    11ef4a5 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4485>
 11ef0cb:	4d 85 ff             	test   %r15,%r15
 11ef0ce:	74 17                	je     11ef0e7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x40c7>
 11ef0d0:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ef0d4:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ef0d8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef0dc:	4c 89 e6             	mov    %r12,%rsi
 11ef0df:	4c 89 fa             	mov    %r15,%rdx
 11ef0e2:	31 c9                	xor    %ecx,%ecx
 11ef0e4:	ff 50 18             	call   *0x18(%rax)
 11ef0e7:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef0ee:	ff 
 11ef0ef:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef0f3:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef0f8:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef0ff:	ff 
 11ef100:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef107:	ff 
 11ef108:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef10f:	ff 
 11ef110:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef117:	ff 
 11ef118:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef11d:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef122:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef127:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef12b:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef132:	4c 89 ee             	mov    %r13,%rsi
 11ef135:	c5 f8 77             	vzeroupper 
 11ef138:	e8 d3 1e 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef13d:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef144:	74 42                	je     11ef188 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4168>
 11ef146:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef14d:	ff 
 11ef14e:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef155:	ff 
 11ef156:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef15d:	ff 
 11ef15e:	c5 fc 11 95 78 d0 ff 	vmovups %ymm2,-0x2f88(%rbp)
 11ef165:	ff 
 11ef166:	c5 fc 11 8d 60 d0 ff 	vmovups %ymm1,-0x2fa0(%rbp)
 11ef16d:	ff 
 11ef16e:	c5 fc 11 85 40 d0 ff 	vmovups %ymm0,-0x2fc0(%rbp)
 11ef175:	ff 
 11ef176:	48 8d bd 40 d0 ff ff 	lea    -0x2fc0(%rbp),%rdi
 11ef17d:	4c 89 ee             	mov    %r13,%rsi
 11ef180:	c5 f8 77             	vzeroupper 
 11ef183:	e8 b8 1f 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef188:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef18f:	0f 84 bf 0d 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ef195:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef19c:	ff 
 11ef19d:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef1a4:	ff 
 11ef1a5:	c5 fc 11 8d 70 e7 ff 	vmovups %ymm1,-0x1890(%rbp)
 11ef1ac:	ff 
 11ef1ad:	c5 fc 11 85 60 e7 ff 	vmovups %ymm0,-0x18a0(%rbp)
 11ef1b4:	ff 
 11ef1b5:	48 8d bd 60 e7 ff ff 	lea    -0x18a0(%rbp),%rdi
 11ef1bc:	e9 88 0d 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11ef1c1:	48 85 db             	test   %rbx,%rbx
 11ef1c4:	74 17                	je     11ef1dd <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x41bd>
 11ef1c6:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ef1ca:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ef1ce:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef1d2:	4c 89 f6             	mov    %r14,%rsi
 11ef1d5:	48 89 da             	mov    %rbx,%rdx
 11ef1d8:	31 c9                	xor    %ecx,%ecx
 11ef1da:	ff 50 18             	call   *0x18(%rax)
 11ef1dd:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef1e4:	ff 
 11ef1e5:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef1e9:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef1ee:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef1f5:	ff 
 11ef1f6:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef1fd:	ff 
 11ef1fe:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef205:	ff 
 11ef206:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef20d:	ff 
 11ef20e:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef213:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef218:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef21d:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef221:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef228:	4c 89 ee             	mov    %r13,%rsi
 11ef22b:	c5 f8 77             	vzeroupper 
 11ef22e:	e8 dd 1d 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef233:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef23a:	74 42                	je     11ef27e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x425e>
 11ef23c:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef243:	ff 
 11ef244:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef24b:	ff 
 11ef24c:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef253:	ff 
 11ef254:	c5 fc 11 95 18 d0 ff 	vmovups %ymm2,-0x2fe8(%rbp)
 11ef25b:	ff 
 11ef25c:	c5 fc 11 8d 00 d0 ff 	vmovups %ymm1,-0x3000(%rbp)
 11ef263:	ff 
 11ef264:	c5 fc 11 85 e0 cf ff 	vmovups %ymm0,-0x3020(%rbp)
 11ef26b:	ff 
 11ef26c:	48 8d bd e0 cf ff ff 	lea    -0x3020(%rbp),%rdi
 11ef273:	4c 89 ee             	mov    %r13,%rsi
 11ef276:	c5 f8 77             	vzeroupper 
 11ef279:	e8 c2 1e 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef27e:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef285:	0f 84 d5 0d 00 00    	je     11f0060 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5040>
 11ef28b:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef292:	ff 
 11ef293:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef29a:	ff 
 11ef29b:	c5 fc 11 8d 40 e7 ff 	vmovups %ymm1,-0x18c0(%rbp)
 11ef2a2:	ff 
 11ef2a3:	c5 fc 11 85 30 e7 ff 	vmovups %ymm0,-0x18d0(%rbp)
 11ef2aa:	ff 
 11ef2ab:	48 8d bd 30 e7 ff ff 	lea    -0x18d0(%rbp),%rdi
 11ef2b2:	e9 ee 01 00 00       	jmp    11ef4a5 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4485>
 11ef2b7:	4d 85 ed             	test   %r13,%r13
 11ef2ba:	74 1a                	je     11ef2d6 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x42b6>
 11ef2bc:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ef2c0:	48 8b 38             	mov    (%rax),%rdi
 11ef2c3:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ef2c7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef2cb:	4c 89 f6             	mov    %r14,%rsi
 11ef2ce:	4c 89 ea             	mov    %r13,%rdx
 11ef2d1:	31 c9                	xor    %ecx,%ecx
 11ef2d3:	ff 50 18             	call   *0x18(%rax)
 11ef2d6:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef2dd:	ff 
 11ef2de:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef2e2:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef2e7:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef2ee:	ff 
 11ef2ef:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef2f6:	ff 
 11ef2f7:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef2fe:	ff 
 11ef2ff:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef306:	ff 
 11ef307:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef30c:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef311:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef316:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef31a:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef321:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11ef325:	4c 89 f6             	mov    %r14,%rsi
 11ef328:	c5 f8 77             	vzeroupper 
 11ef32b:	e8 e0 1c 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef330:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef337:	74 42                	je     11ef37b <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x435b>
 11ef339:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef340:	ff 
 11ef341:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef348:	ff 
 11ef349:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef350:	ff 
 11ef351:	c5 fc 11 95 58 cf ff 	vmovups %ymm2,-0x30a8(%rbp)
 11ef358:	ff 
 11ef359:	c5 fc 11 8d 40 cf ff 	vmovups %ymm1,-0x30c0(%rbp)
 11ef360:	ff 
 11ef361:	c5 fc 11 85 20 cf ff 	vmovups %ymm0,-0x30e0(%rbp)
 11ef368:	ff 
 11ef369:	48 8d bd 20 cf ff ff 	lea    -0x30e0(%rbp),%rdi
 11ef370:	4c 89 f6             	mov    %r14,%rsi
 11ef373:	c5 f8 77             	vzeroupper 
 11ef376:	e8 c5 1d 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef37b:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef382:	0f 84 cc 0b 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ef388:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef38f:	ff 
 11ef390:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef397:	ff 
 11ef398:	c5 fc 11 8d e0 e6 ff 	vmovups %ymm1,-0x1920(%rbp)
 11ef39f:	ff 
 11ef3a0:	c5 fc 11 85 d0 e6 ff 	vmovups %ymm0,-0x1930(%rbp)
 11ef3a7:	ff 
 11ef3a8:	48 8d bd d0 e6 ff ff 	lea    -0x1930(%rbp),%rdi
 11ef3af:	e9 b9 0f 00 00       	jmp    11f036d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x534d>
 11ef3b4:	48 85 db             	test   %rbx,%rbx
 11ef3b7:	74 17                	je     11ef3d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x43b0>
 11ef3b9:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ef3bd:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ef3c1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef3c5:	4c 89 e6             	mov    %r12,%rsi
 11ef3c8:	48 89 da             	mov    %rbx,%rdx
 11ef3cb:	31 c9                	xor    %ecx,%ecx
 11ef3cd:	ff 50 18             	call   *0x18(%rax)
 11ef3d0:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef3d7:	ff 
 11ef3d8:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef3dc:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef3e1:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef3e8:	ff 
 11ef3e9:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef3f0:	ff 
 11ef3f1:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef3f8:	ff 
 11ef3f9:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef400:	ff 
 11ef401:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef406:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef40b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef410:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef414:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef41b:	4c 89 ee             	mov    %r13,%rsi
 11ef41e:	c5 f8 77             	vzeroupper 
 11ef421:	e8 ea 1b 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef426:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef42d:	74 42                	je     11ef471 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4451>
 11ef42f:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef436:	ff 
 11ef437:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef43e:	ff 
 11ef43f:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef446:	ff 
 11ef447:	c5 fc 11 95 f8 ce ff 	vmovups %ymm2,-0x3108(%rbp)
 11ef44e:	ff 
 11ef44f:	c5 fc 11 8d e0 ce ff 	vmovups %ymm1,-0x3120(%rbp)
 11ef456:	ff 
 11ef457:	c5 fc 11 85 c0 ce ff 	vmovups %ymm0,-0x3140(%rbp)
 11ef45e:	ff 
 11ef45f:	48 8d bd c0 ce ff ff 	lea    -0x3140(%rbp),%rdi
 11ef466:	4c 89 ee             	mov    %r13,%rsi
 11ef469:	c5 f8 77             	vzeroupper 
 11ef46c:	e8 cf 1c 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef471:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef478:	0f 84 e2 0b 00 00    	je     11f0060 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5040>
 11ef47e:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef485:	ff 
 11ef486:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef48d:	ff 
 11ef48e:	c5 fc 11 8d b0 e6 ff 	vmovups %ymm1,-0x1950(%rbp)
 11ef495:	ff 
 11ef496:	c5 fc 11 85 a0 e6 ff 	vmovups %ymm0,-0x1960(%rbp)
 11ef49d:	ff 
 11ef49e:	48 8d bd a0 e6 ff ff 	lea    -0x1960(%rbp),%rdi
 11ef4a5:	4c 89 ee             	mov    %r13,%rsi
 11ef4a8:	e9 ab 0b 00 00       	jmp    11f0058 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5038>
 11ef4ad:	4d 85 ff             	test   %r15,%r15
 11ef4b0:	74 17                	je     11ef4c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x44a9>
 11ef4b2:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ef4b6:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ef4ba:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef4be:	4c 89 f6             	mov    %r14,%rsi
 11ef4c1:	4c 89 fa             	mov    %r15,%rdx
 11ef4c4:	31 c9                	xor    %ecx,%ecx
 11ef4c6:	ff 50 18             	call   *0x18(%rax)
 11ef4c9:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef4d0:	ff 
 11ef4d1:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef4d5:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef4da:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef4e1:	ff 
 11ef4e2:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef4e9:	ff 
 11ef4ea:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef4f1:	ff 
 11ef4f2:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef4f9:	ff 
 11ef4fa:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef4ff:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef504:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef509:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef50d:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef514:	4c 89 ee             	mov    %r13,%rsi
 11ef517:	c5 f8 77             	vzeroupper 
 11ef51a:	e8 f1 1a 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef51f:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef526:	74 42                	je     11ef56a <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x454a>
 11ef528:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef52f:	ff 
 11ef530:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef537:	ff 
 11ef538:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef53f:	ff 
 11ef540:	c5 fc 11 95 98 ce ff 	vmovups %ymm2,-0x3168(%rbp)
 11ef547:	ff 
 11ef548:	c5 fc 11 8d 80 ce ff 	vmovups %ymm1,-0x3180(%rbp)
 11ef54f:	ff 
 11ef550:	c5 fc 11 85 60 ce ff 	vmovups %ymm0,-0x31a0(%rbp)
 11ef557:	ff 
 11ef558:	48 8d bd 60 ce ff ff 	lea    -0x31a0(%rbp),%rdi
 11ef55f:	4c 89 ee             	mov    %r13,%rsi
 11ef562:	c5 f8 77             	vzeroupper 
 11ef565:	e8 d6 1b 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef56a:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef571:	0f 84 dd 09 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ef577:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef57e:	ff 
 11ef57f:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef586:	ff 
 11ef587:	c5 fc 11 8d 80 e6 ff 	vmovups %ymm1,-0x1980(%rbp)
 11ef58e:	ff 
 11ef58f:	c5 fc 11 85 70 e6 ff 	vmovups %ymm0,-0x1990(%rbp)
 11ef596:	ff 
 11ef597:	48 8d bd 70 e6 ff ff 	lea    -0x1990(%rbp),%rdi
 11ef59e:	e9 a6 09 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11ef5a3:	48 85 db             	test   %rbx,%rbx
 11ef5a6:	74 1a                	je     11ef5c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x45a2>
 11ef5a8:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ef5ac:	48 8b 38             	mov    (%rax),%rdi
 11ef5af:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ef5b3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef5b7:	4c 89 ee             	mov    %r13,%rsi
 11ef5ba:	48 89 da             	mov    %rbx,%rdx
 11ef5bd:	31 c9                	xor    %ecx,%ecx
 11ef5bf:	ff 50 18             	call   *0x18(%rax)
 11ef5c2:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef5c9:	ff 
 11ef5ca:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef5ce:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef5d3:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef5da:	ff 
 11ef5db:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef5e2:	ff 
 11ef5e3:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef5ea:	ff 
 11ef5eb:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef5f2:	ff 
 11ef5f3:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef5f8:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef5fd:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef602:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef606:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef60d:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11ef611:	48 89 de             	mov    %rbx,%rsi
 11ef614:	c5 f8 77             	vzeroupper 
 11ef617:	e8 f4 19 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef61c:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef623:	74 42                	je     11ef667 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4647>
 11ef625:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef62c:	ff 
 11ef62d:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef634:	ff 
 11ef635:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef63c:	ff 
 11ef63d:	c5 fc 11 95 38 ce ff 	vmovups %ymm2,-0x31c8(%rbp)
 11ef644:	ff 
 11ef645:	c5 fc 11 8d 20 ce ff 	vmovups %ymm1,-0x31e0(%rbp)
 11ef64c:	ff 
 11ef64d:	c5 fc 11 85 00 ce ff 	vmovups %ymm0,-0x3200(%rbp)
 11ef654:	ff 
 11ef655:	48 8d bd 00 ce ff ff 	lea    -0x3200(%rbp),%rdi
 11ef65c:	48 89 de             	mov    %rbx,%rsi
 11ef65f:	c5 f8 77             	vzeroupper 
 11ef662:	e8 d9 1a 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef667:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef66e:	0f 84 ec 09 00 00    	je     11f0060 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5040>
 11ef674:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef67b:	ff 
 11ef67c:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef683:	ff 
 11ef684:	c5 fc 11 8d 50 e6 ff 	vmovups %ymm1,-0x19b0(%rbp)
 11ef68b:	ff 
 11ef68c:	c5 fc 11 85 40 e6 ff 	vmovups %ymm0,-0x19c0(%rbp)
 11ef693:	ff 
 11ef694:	48 8d bd 40 e6 ff ff 	lea    -0x19c0(%rbp),%rdi
 11ef69b:	e9 b5 09 00 00       	jmp    11f0055 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5035>
 11ef6a0:	4d 85 ff             	test   %r15,%r15
 11ef6a3:	74 1a                	je     11ef6bf <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x469f>
 11ef6a5:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11ef6a9:	48 8b 38             	mov    (%rax),%rdi
 11ef6ac:	48 8b 40 08          	mov    0x8(%rax),%rax
 11ef6b0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef6b4:	4c 89 f6             	mov    %r14,%rsi
 11ef6b7:	4c 89 fa             	mov    %r15,%rdx
 11ef6ba:	31 c9                	xor    %ecx,%ecx
 11ef6bc:	ff 50 18             	call   *0x18(%rax)
 11ef6bf:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef6c6:	ff 
 11ef6c7:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef6cb:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef6d0:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef6d7:	ff 
 11ef6d8:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef6df:	ff 
 11ef6e0:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef6e7:	ff 
 11ef6e8:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef6ef:	ff 
 11ef6f0:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef6f5:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef6fa:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef6ff:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef703:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef70a:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11ef70e:	4c 89 f6             	mov    %r14,%rsi
 11ef711:	c5 f8 77             	vzeroupper 
 11ef714:	e8 f7 18 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef719:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef720:	74 42                	je     11ef764 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4744>
 11ef722:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef729:	ff 
 11ef72a:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef731:	ff 
 11ef732:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef739:	ff 
 11ef73a:	c5 fc 11 95 d8 cd ff 	vmovups %ymm2,-0x3228(%rbp)
 11ef741:	ff 
 11ef742:	c5 fc 11 8d c0 cd ff 	vmovups %ymm1,-0x3240(%rbp)
 11ef749:	ff 
 11ef74a:	c5 fc 11 85 a0 cd ff 	vmovups %ymm0,-0x3260(%rbp)
 11ef751:	ff 
 11ef752:	48 8d bd a0 cd ff ff 	lea    -0x3260(%rbp),%rdi
 11ef759:	4c 89 f6             	mov    %r14,%rsi
 11ef75c:	c5 f8 77             	vzeroupper 
 11ef75f:	e8 dc 19 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef764:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef76b:	0f 84 e3 07 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ef771:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef778:	ff 
 11ef779:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef780:	ff 
 11ef781:	c5 fc 11 8d 20 e6 ff 	vmovups %ymm1,-0x19e0(%rbp)
 11ef788:	ff 
 11ef789:	c5 fc 11 85 10 e6 ff 	vmovups %ymm0,-0x19f0(%rbp)
 11ef790:	ff 
 11ef791:	48 8d bd 10 e6 ff ff 	lea    -0x19f0(%rbp),%rdi
 11ef798:	e9 d0 0b 00 00       	jmp    11f036d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x534d>
 11ef79d:	4d 85 e4             	test   %r12,%r12
 11ef7a0:	74 16                	je     11ef7b8 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4798>
 11ef7a2:	49 8b 3f             	mov    (%r15),%rdi
 11ef7a5:	49 8b 47 08          	mov    0x8(%r15),%rax
 11ef7a9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef7ad:	48 89 de             	mov    %rbx,%rsi
 11ef7b0:	4c 89 e2             	mov    %r12,%rdx
 11ef7b3:	31 c9                	xor    %ecx,%ecx
 11ef7b5:	ff 50 18             	call   *0x18(%rax)
 11ef7b8:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef7bf:	ff 
 11ef7c0:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef7c4:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef7c9:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef7d0:	ff 
 11ef7d1:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef7d8:	ff 
 11ef7d9:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef7e0:	ff 
 11ef7e1:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef7e8:	ff 
 11ef7e9:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef7ee:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef7f3:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef7f8:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef7fc:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef803:	4c 89 fe             	mov    %r15,%rsi
 11ef806:	c5 f8 77             	vzeroupper 
 11ef809:	e8 02 18 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef80e:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef815:	74 42                	je     11ef859 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4839>
 11ef817:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef81e:	ff 
 11ef81f:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef826:	ff 
 11ef827:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef82e:	ff 
 11ef82f:	c5 fc 11 95 78 cd ff 	vmovups %ymm2,-0x3288(%rbp)
 11ef836:	ff 
 11ef837:	c5 fc 11 8d 60 cd ff 	vmovups %ymm1,-0x32a0(%rbp)
 11ef83e:	ff 
 11ef83f:	c5 fc 11 85 40 cd ff 	vmovups %ymm0,-0x32c0(%rbp)
 11ef846:	ff 
 11ef847:	48 8d bd 40 cd ff ff 	lea    -0x32c0(%rbp),%rdi
 11ef84e:	4c 89 fe             	mov    %r15,%rsi
 11ef851:	c5 f8 77             	vzeroupper 
 11ef854:	e8 e7 18 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef859:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef860:	0f 84 07 09 00 00    	je     11f016d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x514d>
 11ef866:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef86d:	ff 
 11ef86e:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef875:	ff 
 11ef876:	c5 fc 11 8d f0 e5 ff 	vmovups %ymm1,-0x1a10(%rbp)
 11ef87d:	ff 
 11ef87e:	c5 fc 11 85 e0 e5 ff 	vmovups %ymm0,-0x1a20(%rbp)
 11ef885:	ff 
 11ef886:	48 8d bd e0 e5 ff ff 	lea    -0x1a20(%rbp),%rdi
 11ef88d:	4c 89 fe             	mov    %r15,%rsi
 11ef890:	e9 d0 08 00 00       	jmp    11f0165 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5145>
 11ef895:	4d 85 ff             	test   %r15,%r15
 11ef898:	74 17                	je     11ef8b1 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4891>
 11ef89a:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ef89e:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ef8a2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef8a6:	4c 89 f6             	mov    %r14,%rsi
 11ef8a9:	4c 89 fa             	mov    %r15,%rdx
 11ef8ac:	31 c9                	xor    %ecx,%ecx
 11ef8ae:	ff 50 18             	call   *0x18(%rax)
 11ef8b1:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef8b8:	ff 
 11ef8b9:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef8bd:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef8c2:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef8c9:	ff 
 11ef8ca:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef8d1:	ff 
 11ef8d2:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef8d9:	ff 
 11ef8da:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef8e1:	ff 
 11ef8e2:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef8e7:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef8ec:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef8f1:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef8f5:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef8fc:	4c 89 ee             	mov    %r13,%rsi
 11ef8ff:	c5 f8 77             	vzeroupper 
 11ef902:	e8 09 17 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef907:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11ef90e:	74 42                	je     11ef952 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4932>
 11ef910:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11ef917:	ff 
 11ef918:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11ef91f:	ff 
 11ef920:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11ef927:	ff 
 11ef928:	c5 fc 11 95 b8 cc ff 	vmovups %ymm2,-0x3348(%rbp)
 11ef92f:	ff 
 11ef930:	c5 fc 11 8d a0 cc ff 	vmovups %ymm1,-0x3360(%rbp)
 11ef937:	ff 
 11ef938:	c5 fc 11 85 80 cc ff 	vmovups %ymm0,-0x3380(%rbp)
 11ef93f:	ff 
 11ef940:	48 8d bd 80 cc ff ff 	lea    -0x3380(%rbp),%rdi
 11ef947:	4c 89 ee             	mov    %r13,%rsi
 11ef94a:	c5 f8 77             	vzeroupper 
 11ef94d:	e8 ee 17 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11ef952:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11ef959:	0f 84 f5 05 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11ef95f:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11ef966:	ff 
 11ef967:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11ef96e:	ff 
 11ef96f:	c5 fc 11 8d 90 e5 ff 	vmovups %ymm1,-0x1a70(%rbp)
 11ef976:	ff 
 11ef977:	c5 fc 11 85 80 e5 ff 	vmovups %ymm0,-0x1a80(%rbp)
 11ef97e:	ff 
 11ef97f:	48 8d bd 80 e5 ff ff 	lea    -0x1a80(%rbp),%rdi
 11ef986:	e9 be 05 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11ef98b:	48 85 db             	test   %rbx,%rbx
 11ef98e:	74 17                	je     11ef9a7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4987>
 11ef990:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11ef994:	49 8b 45 08          	mov    0x8(%r13),%rax
 11ef998:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11ef99c:	4c 89 e6             	mov    %r12,%rsi
 11ef99f:	48 89 da             	mov    %rbx,%rdx
 11ef9a2:	31 c9                	xor    %ecx,%ecx
 11ef9a4:	ff 50 18             	call   *0x18(%rax)
 11ef9a7:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11ef9ae:	ff 
 11ef9af:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11ef9b3:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11ef9b8:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11ef9bf:	ff 
 11ef9c0:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11ef9c7:	ff 
 11ef9c8:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11ef9cf:	ff 
 11ef9d0:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11ef9d7:	ff 
 11ef9d8:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11ef9dd:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11ef9e2:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11ef9e7:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11ef9eb:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11ef9f2:	4c 89 ee             	mov    %r13,%rsi
 11ef9f5:	c5 f8 77             	vzeroupper 
 11ef9f8:	e8 13 16 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11ef9fd:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11efa04:	74 42                	je     11efa48 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4a28>
 11efa06:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11efa0d:	ff 
 11efa0e:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11efa15:	ff 
 11efa16:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11efa1d:	ff 
 11efa1e:	c5 fc 11 95 58 cc ff 	vmovups %ymm2,-0x33a8(%rbp)
 11efa25:	ff 
 11efa26:	c5 fc 11 8d 40 cc ff 	vmovups %ymm1,-0x33c0(%rbp)
 11efa2d:	ff 
 11efa2e:	c5 fc 11 85 20 cc ff 	vmovups %ymm0,-0x33e0(%rbp)
 11efa35:	ff 
 11efa36:	48 8d bd 20 cc ff ff 	lea    -0x33e0(%rbp),%rdi
 11efa3d:	4c 89 ee             	mov    %r13,%rsi
 11efa40:	c5 f8 77             	vzeroupper 
 11efa43:	e8 f8 16 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11efa48:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11efa4f:	0f 84 18 07 00 00    	je     11f016d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x514d>
 11efa55:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11efa5c:	ff 
 11efa5d:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11efa64:	ff 
 11efa65:	c5 fc 11 8d 60 e5 ff 	vmovups %ymm1,-0x1aa0(%rbp)
 11efa6c:	ff 
 11efa6d:	c5 fc 11 85 50 e5 ff 	vmovups %ymm0,-0x1ab0(%rbp)
 11efa74:	ff 
 11efa75:	48 8d bd 50 e5 ff ff 	lea    -0x1ab0(%rbp),%rdi
 11efa7c:	e9 e7 01 00 00       	jmp    11efc68 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4c48>
 11efa81:	4d 85 ff             	test   %r15,%r15
 11efa84:	74 17                	je     11efa9d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4a7d>
 11efa86:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11efa8a:	49 8b 45 08          	mov    0x8(%r13),%rax
 11efa8e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11efa92:	4c 89 f6             	mov    %r14,%rsi
 11efa95:	4c 89 fa             	mov    %r15,%rdx
 11efa98:	31 c9                	xor    %ecx,%ecx
 11efa9a:	ff 50 18             	call   *0x18(%rax)
 11efa9d:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11efaa4:	ff 
 11efaa5:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11efaa9:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11efaae:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11efab5:	ff 
 11efab6:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11efabd:	ff 
 11efabe:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11efac5:	ff 
 11efac6:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11efacd:	ff 
 11eface:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11efad3:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11efad8:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11efadd:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11efae1:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11efae8:	4c 89 ee             	mov    %r13,%rsi
 11efaeb:	c5 f8 77             	vzeroupper 
 11efaee:	e8 1d 15 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11efaf3:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11efafa:	74 42                	je     11efb3e <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4b1e>
 11efafc:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11efb03:	ff 
 11efb04:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11efb0b:	ff 
 11efb0c:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11efb13:	ff 
 11efb14:	c5 fc 11 95 f8 cb ff 	vmovups %ymm2,-0x3408(%rbp)
 11efb1b:	ff 
 11efb1c:	c5 fc 11 8d e0 cb ff 	vmovups %ymm1,-0x3420(%rbp)
 11efb23:	ff 
 11efb24:	c5 fc 11 85 c0 cb ff 	vmovups %ymm0,-0x3440(%rbp)
 11efb2b:	ff 
 11efb2c:	48 8d bd c0 cb ff ff 	lea    -0x3440(%rbp),%rdi
 11efb33:	4c 89 ee             	mov    %r13,%rsi
 11efb36:	c5 f8 77             	vzeroupper 
 11efb39:	e8 02 16 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11efb3e:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11efb45:	0f 84 09 04 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11efb4b:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11efb52:	ff 
 11efb53:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11efb5a:	ff 
 11efb5b:	c5 fc 11 8d 30 e5 ff 	vmovups %ymm1,-0x1ad0(%rbp)
 11efb62:	ff 
 11efb63:	c5 fc 11 85 20 e5 ff 	vmovups %ymm0,-0x1ae0(%rbp)
 11efb6a:	ff 
 11efb6b:	48 8d bd 20 e5 ff ff 	lea    -0x1ae0(%rbp),%rdi
 11efb72:	e9 d2 03 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11efb77:	48 85 db             	test   %rbx,%rbx
 11efb7a:	74 17                	je     11efb93 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4b73>
 11efb7c:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11efb80:	49 8b 45 08          	mov    0x8(%r13),%rax
 11efb84:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11efb88:	4c 89 e6             	mov    %r12,%rsi
 11efb8b:	48 89 da             	mov    %rbx,%rdx
 11efb8e:	31 c9                	xor    %ecx,%ecx
 11efb90:	ff 50 18             	call   *0x18(%rax)
 11efb93:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11efb9a:	ff 
 11efb9b:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11efb9f:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11efba4:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11efbab:	ff 
 11efbac:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11efbb3:	ff 
 11efbb4:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11efbbb:	ff 
 11efbbc:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11efbc3:	ff 
 11efbc4:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11efbc9:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11efbce:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11efbd3:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11efbd7:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11efbde:	4c 89 ee             	mov    %r13,%rsi
 11efbe1:	c5 f8 77             	vzeroupper 
 11efbe4:	e8 27 14 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11efbe9:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11efbf0:	74 42                	je     11efc34 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4c14>
 11efbf2:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11efbf9:	ff 
 11efbfa:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11efc01:	ff 
 11efc02:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11efc09:	ff 
 11efc0a:	c5 fc 11 95 98 cb ff 	vmovups %ymm2,-0x3468(%rbp)
 11efc11:	ff 
 11efc12:	c5 fc 11 8d 80 cb ff 	vmovups %ymm1,-0x3480(%rbp)
 11efc19:	ff 
 11efc1a:	c5 fc 11 85 60 cb ff 	vmovups %ymm0,-0x34a0(%rbp)
 11efc21:	ff 
 11efc22:	48 8d bd 60 cb ff ff 	lea    -0x34a0(%rbp),%rdi
 11efc29:	4c 89 ee             	mov    %r13,%rsi
 11efc2c:	c5 f8 77             	vzeroupper 
 11efc2f:	e8 0c 15 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11efc34:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11efc3b:	0f 84 2c 05 00 00    	je     11f016d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x514d>
 11efc41:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11efc48:	ff 
 11efc49:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11efc50:	ff 
 11efc51:	c5 fc 11 8d 00 e5 ff 	vmovups %ymm1,-0x1b00(%rbp)
 11efc58:	ff 
 11efc59:	c5 fc 11 85 f0 e4 ff 	vmovups %ymm0,-0x1b10(%rbp)
 11efc60:	ff 
 11efc61:	48 8d bd f0 e4 ff ff 	lea    -0x1b10(%rbp),%rdi
 11efc68:	4c 89 ee             	mov    %r13,%rsi
 11efc6b:	e9 f5 04 00 00       	jmp    11f0165 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5145>
 11efc70:	4d 85 ff             	test   %r15,%r15
 11efc73:	74 17                	je     11efc8c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4c6c>
 11efc75:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11efc79:	49 8b 45 08          	mov    0x8(%r13),%rax
 11efc7d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11efc81:	4c 89 f6             	mov    %r14,%rsi
 11efc84:	4c 89 fa             	mov    %r15,%rdx
 11efc87:	31 c9                	xor    %ecx,%ecx
 11efc89:	ff 50 18             	call   *0x18(%rax)
 11efc8c:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11efc93:	ff 
 11efc94:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11efc98:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11efc9d:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11efca4:	ff 
 11efca5:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11efcac:	ff 
 11efcad:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11efcb4:	ff 
 11efcb5:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11efcbc:	ff 
 11efcbd:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11efcc2:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11efcc7:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11efccc:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11efcd0:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11efcd7:	4c 89 ee             	mov    %r13,%rsi
 11efcda:	c5 f8 77             	vzeroupper 
 11efcdd:	e8 2e 13 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11efce2:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11efce9:	74 42                	je     11efd2d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4d0d>
 11efceb:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11efcf2:	ff 
 11efcf3:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11efcfa:	ff 
 11efcfb:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11efd02:	ff 
 11efd03:	c5 fc 11 95 38 cb ff 	vmovups %ymm2,-0x34c8(%rbp)
 11efd0a:	ff 
 11efd0b:	c5 fc 11 8d 20 cb ff 	vmovups %ymm1,-0x34e0(%rbp)
 11efd12:	ff 
 11efd13:	c5 fc 11 85 00 cb ff 	vmovups %ymm0,-0x3500(%rbp)
 11efd1a:	ff 
 11efd1b:	48 8d bd 00 cb ff ff 	lea    -0x3500(%rbp),%rdi
 11efd22:	4c 89 ee             	mov    %r13,%rsi
 11efd25:	c5 f8 77             	vzeroupper 
 11efd28:	e8 13 14 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11efd2d:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11efd34:	0f 84 1a 02 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11efd3a:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11efd41:	ff 
 11efd42:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11efd49:	ff 
 11efd4a:	c5 fc 11 8d d0 e4 ff 	vmovups %ymm1,-0x1b30(%rbp)
 11efd51:	ff 
 11efd52:	c5 fc 11 85 c0 e4 ff 	vmovups %ymm0,-0x1b40(%rbp)
 11efd59:	ff 
 11efd5a:	48 8d bd c0 e4 ff ff 	lea    -0x1b40(%rbp),%rdi
 11efd61:	e9 e3 01 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11efd66:	4d 85 ff             	test   %r15,%r15
 11efd69:	74 17                	je     11efd82 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4d62>
 11efd6b:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11efd6f:	49 8b 45 08          	mov    0x8(%r13),%rax
 11efd73:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11efd77:	4c 89 e6             	mov    %r12,%rsi
 11efd7a:	4c 89 fa             	mov    %r15,%rdx
 11efd7d:	31 c9                	xor    %ecx,%ecx
 11efd7f:	ff 50 18             	call   *0x18(%rax)
 11efd82:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11efd89:	ff 
 11efd8a:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11efd8e:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11efd93:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11efd9a:	ff 
 11efd9b:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11efda2:	ff 
 11efda3:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11efdaa:	ff 
 11efdab:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11efdb2:	ff 
 11efdb3:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11efdb8:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11efdbd:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11efdc2:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11efdc6:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11efdcd:	4c 89 ee             	mov    %r13,%rsi
 11efdd0:	c5 f8 77             	vzeroupper 
 11efdd3:	e8 38 12 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11efdd8:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11efddf:	74 42                	je     11efe23 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4e03>
 11efde1:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11efde8:	ff 
 11efde9:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11efdf0:	ff 
 11efdf1:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11efdf8:	ff 
 11efdf9:	c5 fc 11 95 f8 d1 ff 	vmovups %ymm2,-0x2e08(%rbp)
 11efe00:	ff 
 11efe01:	c5 fc 11 8d e0 d1 ff 	vmovups %ymm1,-0x2e20(%rbp)
 11efe08:	ff 
 11efe09:	c5 fc 11 85 c0 d1 ff 	vmovups %ymm0,-0x2e40(%rbp)
 11efe10:	ff 
 11efe11:	48 8d bd c0 d1 ff ff 	lea    -0x2e40(%rbp),%rdi
 11efe18:	4c 89 ee             	mov    %r13,%rsi
 11efe1b:	c5 f8 77             	vzeroupper 
 11efe1e:	e8 1d 13 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11efe23:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11efe2a:	0f 84 24 01 00 00    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11efe30:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11efe37:	ff 
 11efe38:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11efe3f:	ff 
 11efe40:	c5 fc 11 8d 30 e8 ff 	vmovups %ymm1,-0x17d0(%rbp)
 11efe47:	ff 
 11efe48:	c5 fc 11 85 20 e8 ff 	vmovups %ymm0,-0x17e0(%rbp)
 11efe4f:	ff 
 11efe50:	48 8d bd 20 e8 ff ff 	lea    -0x17e0(%rbp),%rdi
 11efe57:	e9 ed 00 00 00       	jmp    11eff49 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f29>
 11efe5c:	4d 85 ff             	test   %r15,%r15
 11efe5f:	74 17                	je     11efe78 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4e58>
 11efe61:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 11efe65:	49 8b 45 08          	mov    0x8(%r13),%rax
 11efe69:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11efe6d:	4c 89 e6             	mov    %r12,%rsi
 11efe70:	4c 89 fa             	mov    %r15,%rdx
 11efe73:	31 c9                	xor    %ecx,%ecx
 11efe75:	ff 50 18             	call   *0x18(%rax)
 11efe78:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11efe7f:	ff 
 11efe80:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11efe84:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11efe89:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11efe90:	ff 
 11efe91:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11efe98:	ff 
 11efe99:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11efea0:	ff 
 11efea1:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11efea8:	ff 
 11efea9:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11efeae:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11efeb3:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11efeb8:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11efebc:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11efec3:	4c 89 ee             	mov    %r13,%rsi
 11efec6:	c5 f8 77             	vzeroupper 
 11efec9:	e8 42 11 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11efece:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11efed5:	74 42                	je     11eff19 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4ef9>
 11efed7:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11efede:	ff 
 11efedf:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11efee6:	ff 
 11efee7:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11efeee:	ff 
 11efeef:	c5 fc 11 95 b8 cf ff 	vmovups %ymm2,-0x3048(%rbp)
 11efef6:	ff 
 11efef7:	c5 fc 11 8d a0 cf ff 	vmovups %ymm1,-0x3060(%rbp)
 11efefe:	ff 
 11efeff:	c5 fc 11 85 80 cf ff 	vmovups %ymm0,-0x3080(%rbp)
 11eff06:	ff 
 11eff07:	48 8d bd 80 cf ff ff 	lea    -0x3080(%rbp),%rdi
 11eff0e:	4c 89 ee             	mov    %r13,%rsi
 11eff11:	c5 f8 77             	vzeroupper 
 11eff14:	e8 27 12 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11eff19:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11eff20:	74 32                	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11eff22:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11eff29:	ff 
 11eff2a:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11eff31:	ff 
 11eff32:	c5 fc 11 8d 10 e7 ff 	vmovups %ymm1,-0x18f0(%rbp)
 11eff39:	ff 
 11eff3a:	c5 fc 11 85 00 e7 ff 	vmovups %ymm0,-0x1900(%rbp)
 11eff41:	ff 
 11eff42:	48 8d bd 00 e7 ff ff 	lea    -0x1900(%rbp),%rdi
 11eff49:	4c 89 ee             	mov    %r13,%rsi
 11eff4c:	c5 f8 77             	vzeroupper 
 11eff4f:	e8 5c 3b 01 00       	call   1203ab0 <br.encoder.block_split_plan.Plan.deinit>
 11eff54:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11eff58:	66 89 58 10          	mov    %bx,0x10(%rax)
 11eff5c:	e9 78 ed ff ff       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11eff61:	4d 85 ed             	test   %r13,%r13
 11eff64:	74 1a                	je     11eff80 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f60>
 11eff66:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11eff6a:	48 8b 38             	mov    (%rax),%rdi
 11eff6d:	48 8b 40 08          	mov    0x8(%rax),%rax
 11eff71:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11eff75:	4c 89 f6             	mov    %r14,%rsi
 11eff78:	4c 89 ea             	mov    %r13,%rdx
 11eff7b:	31 c9                	xor    %ecx,%ecx
 11eff7d:	ff 50 18             	call   *0x18(%rax)
 11eff80:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11eff87:	ff 
 11eff88:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11eff8c:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11eff91:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11eff98:	ff 
 11eff99:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11effa0:	ff 
 11effa1:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11effa8:	ff 
 11effa9:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11effb0:	ff 
 11effb1:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11effb6:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11effbb:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11effc0:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11effc4:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11effcb:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11effcf:	48 89 de             	mov    %rbx,%rsi
 11effd2:	c5 f8 77             	vzeroupper 
 11effd5:	e8 36 10 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11effda:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11effe1:	74 42                	je     11f0025 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5005>
 11effe3:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11effea:	ff 
 11effeb:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11efff2:	ff 
 11efff3:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11efffa:	ff 
 11efffb:	c5 fc 11 95 18 cd ff 	vmovups %ymm2,-0x32e8(%rbp)
 11f0002:	ff 
 11f0003:	c5 fc 11 8d 00 cd ff 	vmovups %ymm1,-0x3300(%rbp)
 11f000a:	ff 
 11f000b:	c5 fc 11 85 e0 cc ff 	vmovups %ymm0,-0x3320(%rbp)
 11f0012:	ff 
 11f0013:	48 8d bd e0 cc ff ff 	lea    -0x3320(%rbp),%rdi
 11f001a:	48 89 de             	mov    %rbx,%rsi
 11f001d:	c5 f8 77             	vzeroupper 
 11f0020:	e8 1b 11 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11f0025:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11f002c:	74 32                	je     11f0060 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5040>
 11f002e:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11f0035:	ff 
 11f0036:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11f003d:	ff 
 11f003e:	c5 fc 11 8d c0 e5 ff 	vmovups %ymm1,-0x1a40(%rbp)
 11f0045:	ff 
 11f0046:	c5 fc 11 85 b0 e5 ff 	vmovups %ymm0,-0x1a50(%rbp)
 11f004d:	ff 
 11f004e:	48 8d bd b0 e5 ff ff 	lea    -0x1a50(%rbp),%rdi
 11f0055:	48 89 de             	mov    %rbx,%rsi
 11f0058:	c5 f8 77             	vzeroupper 
 11f005b:	e8 50 3a 01 00       	call   1203ab0 <br.encoder.block_split_plan.Plan.deinit>
 11f0060:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11f0064:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 11f0069:	e9 6b ec ff ff       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11f006e:	4d 85 ed             	test   %r13,%r13
 11f0071:	74 1a                	je     11f008d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x506d>
 11f0073:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f0077:	48 8b 38             	mov    (%rax),%rdi
 11f007a:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f007e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f0082:	48 89 de             	mov    %rbx,%rsi
 11f0085:	4c 89 ea             	mov    %r13,%rdx
 11f0088:	31 c9                	xor    %ecx,%ecx
 11f008a:	ff 50 18             	call   *0x18(%rax)
 11f008d:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11f0094:	ff 
 11f0095:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11f0099:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11f009e:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11f00a5:	ff 
 11f00a6:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11f00ad:	ff 
 11f00ae:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11f00b5:	ff 
 11f00b6:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11f00bd:	ff 
 11f00be:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11f00c3:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11f00c8:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11f00cd:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11f00d1:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11f00d8:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11f00dc:	48 89 de             	mov    %rbx,%rsi
 11f00df:	c5 f8 77             	vzeroupper 
 11f00e2:	e8 29 0f 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11f00e7:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11f00ee:	74 42                	je     11f0132 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5112>
 11f00f0:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11f00f7:	ff 
 11f00f8:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11f00ff:	ff 
 11f0100:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11f0107:	ff 
 11f0108:	c5 fc 11 95 d8 ca ff 	vmovups %ymm2,-0x3528(%rbp)
 11f010f:	ff 
 11f0110:	c5 fc 11 8d c0 ca ff 	vmovups %ymm1,-0x3540(%rbp)
 11f0117:	ff 
 11f0118:	c5 fc 11 85 a0 ca ff 	vmovups %ymm0,-0x3560(%rbp)
 11f011f:	ff 
 11f0120:	48 8d bd a0 ca ff ff 	lea    -0x3560(%rbp),%rdi
 11f0127:	48 89 de             	mov    %rbx,%rsi
 11f012a:	c5 f8 77             	vzeroupper 
 11f012d:	e8 0e 10 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11f0132:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11f0139:	74 32                	je     11f016d <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x514d>
 11f013b:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11f0142:	ff 
 11f0143:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11f014a:	ff 
 11f014b:	c5 fc 11 8d a0 e4 ff 	vmovups %ymm1,-0x1b60(%rbp)
 11f0152:	ff 
 11f0153:	c5 fc 11 85 90 e4 ff 	vmovups %ymm0,-0x1b70(%rbp)
 11f015a:	ff 
 11f015b:	48 8d bd 90 e4 ff ff 	lea    -0x1b70(%rbp),%rdi
 11f0162:	48 89 de             	mov    %rbx,%rsi
 11f0165:	c5 f8 77             	vzeroupper 
 11f0168:	e8 43 39 01 00       	call   1203ab0 <br.encoder.block_split_plan.Plan.deinit>
 11f016d:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11f0171:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 11f0176:	e9 5e eb ff ff       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11f017b:	4d 85 ff             	test   %r15,%r15
 11f017e:	74 18                	je     11f0198 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5178>
 11f0180:	49 8b 3c 24          	mov    (%r12),%rdi
 11f0184:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 11f0189:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f018d:	4c 89 f6             	mov    %r14,%rsi
 11f0190:	4c 89 fa             	mov    %r15,%rdx
 11f0193:	31 c9                	xor    %ecx,%ecx
 11f0195:	ff 50 18             	call   *0x18(%rax)
 11f0198:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11f019f:	ff 
 11f01a0:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11f01a4:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11f01a9:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11f01b0:	ff 
 11f01b1:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11f01b8:	ff 
 11f01b9:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11f01c0:	ff 
 11f01c1:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11f01c8:	ff 
 11f01c9:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11f01ce:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11f01d3:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11f01d8:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11f01dc:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11f01e3:	4c 89 e6             	mov    %r12,%rsi
 11f01e6:	c5 f8 77             	vzeroupper 
 11f01e9:	e8 22 0e 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11f01ee:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11f01f5:	74 42                	je     11f0239 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5219>
 11f01f7:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11f01fe:	ff 
 11f01ff:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11f0206:	ff 
 11f0207:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11f020e:	ff 
 11f020f:	c5 fc 11 95 78 ca ff 	vmovups %ymm2,-0x3588(%rbp)
 11f0216:	ff 
 11f0217:	c5 fc 11 8d 60 ca ff 	vmovups %ymm1,-0x35a0(%rbp)
 11f021e:	ff 
 11f021f:	c5 fc 11 85 40 ca ff 	vmovups %ymm0,-0x35c0(%rbp)
 11f0226:	ff 
 11f0227:	48 8d bd 40 ca ff ff 	lea    -0x35c0(%rbp),%rdi
 11f022e:	4c 89 e6             	mov    %r12,%rsi
 11f0231:	c5 f8 77             	vzeroupper 
 11f0234:	e8 07 0f 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11f0239:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11f0240:	0f 84 0e fd ff ff    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11f0246:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11f024d:	ff 
 11f024e:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11f0255:	ff 
 11f0256:	c5 fc 11 8d 70 e4 ff 	vmovups %ymm1,-0x1b90(%rbp)
 11f025d:	ff 
 11f025e:	c5 fc 11 85 60 e4 ff 	vmovups %ymm0,-0x1ba0(%rbp)
 11f0265:	ff 
 11f0266:	48 8d bd 60 e4 ff ff 	lea    -0x1ba0(%rbp),%rdi
 11f026d:	4c 89 e6             	mov    %r12,%rsi
 11f0270:	e9 d7 fc ff ff       	jmp    11eff4c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f2c>
 11f0275:	4d 85 ed             	test   %r13,%r13
 11f0278:	74 1a                	je     11f0294 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5274>
 11f027a:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11f027e:	48 8b 38             	mov    (%rax),%rdi
 11f0281:	48 8b 40 08          	mov    0x8(%rax),%rax
 11f0285:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11f0289:	4c 89 e6             	mov    %r12,%rsi
 11f028c:	4c 89 ea             	mov    %r13,%rdx
 11f028f:	31 c9                	xor    %ecx,%ecx
 11f0291:	ff 50 18             	call   *0x18(%rax)
 11f0294:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11f029b:	ff 
 11f029c:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11f02a0:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11f02a5:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11f02ac:	ff 
 11f02ad:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11f02b4:	ff 
 11f02b5:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11f02bc:	ff 
 11f02bd:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11f02c4:	ff 
 11f02c5:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11f02ca:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11f02cf:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11f02d4:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11f02d8:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11f02df:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11f02e3:	4c 89 f6             	mov    %r14,%rsi
 11f02e6:	c5 f8 77             	vzeroupper 
 11f02e9:	e8 22 0d 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11f02ee:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11f02f5:	74 42                	je     11f0339 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5319>
 11f02f7:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11f02fe:	ff 
 11f02ff:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11f0306:	ff 
 11f0307:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11f030e:	ff 
 11f030f:	c5 fc 11 95 18 ca ff 	vmovups %ymm2,-0x35e8(%rbp)
 11f0316:	ff 
 11f0317:	c5 fc 11 8d 00 ca ff 	vmovups %ymm1,-0x3600(%rbp)
 11f031e:	ff 
 11f031f:	c5 fc 11 85 e0 c9 ff 	vmovups %ymm0,-0x3620(%rbp)
 11f0326:	ff 
 11f0327:	48 8d bd e0 c9 ff ff 	lea    -0x3620(%rbp),%rdi
 11f032e:	4c 89 f6             	mov    %r14,%rsi
 11f0331:	c5 f8 77             	vzeroupper 
 11f0334:	e8 07 0e 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11f0339:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11f0340:	0f 84 0e fc ff ff    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11f0346:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11f034d:	ff 
 11f034e:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11f0355:	ff 
 11f0356:	c5 fc 11 8d 40 e4 ff 	vmovups %ymm1,-0x1bc0(%rbp)
 11f035d:	ff 
 11f035e:	c5 fc 11 85 30 e4 ff 	vmovups %ymm0,-0x1bd0(%rbp)
 11f0365:	ff 
 11f0366:	48 8d bd 30 e4 ff ff 	lea    -0x1bd0(%rbp),%rdi
 11f036d:	4c 89 f6             	mov    %r14,%rsi
 11f0370:	e9 d7 fb ff ff       	jmp    11eff4c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f2c>
 11f0375:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11f037c:	74 32                	je     11f03b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x5390>
 11f037e:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11f0385:	ff 
 11f0386:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11f038d:	ff 
 11f038e:	c5 fc 11 8d b0 e9 ff 	vmovups %ymm1,-0x1650(%rbp)
 11f0395:	ff 
 11f0396:	c5 fc 11 85 a0 e9 ff 	vmovups %ymm0,-0x1660(%rbp)
 11f039d:	ff 
 11f039e:	48 8d bd a0 e9 ff ff 	lea    -0x1660(%rbp),%rdi
 11f03a5:	4c 89 ee             	mov    %r13,%rsi
 11f03a8:	c5 f8 77             	vzeroupper 
 11f03ab:	e8 00 37 01 00       	call   1203ab0 <br.encoder.block_split_plan.Plan.deinit>
 11f03b0:	c5 f8 10 05 98 12 e5 	vmovups -0x1aed68(%rip),%xmm0        # 1041650 <__anon_72921>
 11f03b7:	ff 
 11f03b8:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11f03bc:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 11f03c0:	48 c7 40 10 1a 00 00 	movq   $0x1a,0x10(%rax)
 11f03c7:	00 
 11f03c8:	e9 0c e9 ff ff       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11f03cd:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11f03d4:	74 32                	je     11f0408 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x53e8>
 11f03d6:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11f03dd:	ff 
 11f03de:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11f03e5:	ff 
 11f03e6:	c5 fc 11 8d 50 e9 ff 	vmovups %ymm1,-0x16b0(%rbp)
 11f03ed:	ff 
 11f03ee:	c5 fc 11 85 40 e9 ff 	vmovups %ymm0,-0x16c0(%rbp)
 11f03f5:	ff 
 11f03f6:	48 8d bd 40 e9 ff ff 	lea    -0x16c0(%rbp),%rdi
 11f03fd:	4c 89 ee             	mov    %r13,%rsi
 11f0400:	c5 f8 77             	vzeroupper 
 11f0403:	e8 a8 36 01 00       	call   1203ab0 <br.encoder.block_split_plan.Plan.deinit>
 11f0408:	c5 f8 10 05 58 12 e5 	vmovups -0x1aeda8(%rip),%xmm0        # 1041668 <__anon_72923>
 11f040f:	ff 
 11f0410:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11f0414:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 11f0418:	48 c7 40 10 1f 00 00 	movq   $0x1f,0x10(%rax)
 11f041f:	00 
 11f0420:	e9 b4 e8 ff ff       	jmp    11eecd9 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x3cb9>
 11f0425:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 11f042c:	ff 
 11f042d:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11f0431:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 11f0436:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 11f043d:	ff 
 11f043e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 11f0445:	ff 
 11f0446:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 11f044d:	ff 
 11f044e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 11f0455:	ff 
 11f0456:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 11f045b:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 11f0460:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 11f0465:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11f0469:	48 8d bd 60 dd ff ff 	lea    -0x22a0(%rbp),%rdi
 11f0470:	4c 89 ee             	mov    %r13,%rsi
 11f0473:	c5 f8 77             	vzeroupper 
 11f0476:	e8 95 0b 00 00       	call   11f1010 <br.EntropySymbolSplits.deinit>
 11f047b:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 11f0482:	74 43                	je     11f04c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x54a7>
 11f0484:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 11f048b:	ff 
 11f048c:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 11f0493:	ff 
 11f0494:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 11f049b:	ff 
 11f049c:	c5 fc 11 95 58 d2 ff 	vmovups %ymm2,-0x2da8(%rbp)
 11f04a3:	ff 
 11f04a4:	c5 fc 11 8d 40 d2 ff 	vmovups %ymm1,-0x2dc0(%rbp)
 11f04ab:	ff 
 11f04ac:	c5 fc 11 85 20 d2 ff 	vmovups %ymm0,-0x2de0(%rbp)
 11f04b3:	ff 
 11f04b4:	48 8d bd 20 d2 ff ff 	lea    -0x2de0(%rbp),%rdi
 11f04bb:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11f04bf:	c5 f8 77             	vzeroupper 
 11f04c2:	e8 79 0c 00 00       	call   11f1140 <br.encoder.literal_entropy_plan.Plan.deinit>
 11f04c7:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 11f04ce:	0f 84 80 fa ff ff    	je     11eff54 <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f34>
 11f04d4:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 11f04db:	ff 
 11f04dc:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 11f04e3:	ff 
 11f04e4:	c5 fc 11 8d 60 e8 ff 	vmovups %ymm1,-0x17a0(%rbp)
 11f04eb:	ff 
 11f04ec:	c5 fc 11 85 50 e8 ff 	vmovups %ymm0,-0x17b0(%rbp)
 11f04f3:	ff 
 11f04f4:	48 8d bd 50 e8 ff ff 	lea    -0x17b0(%rbp),%rdi
 11f04fb:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11f04ff:	e9 48 fa ff ff       	jmp    11eff4c <br.encodeEntropySplitCandidateAllocRecorded__anon_43527+0x4f2c>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
