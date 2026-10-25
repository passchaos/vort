 1062ec2:	e9 73 ff ff ff       	jmp    1062e3a <start.posixCallMainAndExit+0x50ba>
 1062ec7:	45 31 e4             	xor    %r12d,%r12d
 1062eca:	4c 8b ad 18 ff ff ff 	mov    -0xe8(%rbp),%r13
 1062ed1:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 1062ed8:	4a 8d 1c 20          	lea    (%rax,%r12,1),%rbx
 1062edc:	48 89 df             	mov    %rbx,%rdi
 1062edf:	48 8d b5 e0 e8 ff ff 	lea    -0x1720(%rbp),%rsi
 1062ee6:	c5 f8 77             	vzeroupper 
 1062ee9:	e8 42 95 05 00       	call   10bc430 <frequency_merge_bench.query__anon_2966>
 1062eee:	49 89 c6             	mov    %rax,%r14
 1062ef1:	48 89 df             	mov    %rbx,%rdi
 1062ef4:	48 8d b5 e0 e4 ff ff 	lea    -0x1b20(%rbp),%rsi
 1062efb:	e8 70 93 05 00       	call   10bc270 <frequency_merge_bench.query__anon_2967>
 1062f00:	49 39 c6             	cmp    %rax,%r14
 1062f03:	0f 85 48 0a 00 00    	jne    1063951 <start.posixCallMainAndExit+0x5bd1>
 1062f09:	c5 fe 6f 85 e0 e8 ff 	vmovdqu -0x1720(%rbp),%ymm0
 1062f10:	ff 
 1062f11:	c5 fd ef 85 e0 e4 ff 	vpxor  -0x1b20(%rbp),%ymm0,%ymm0
 1062f18:	ff 
 1062f19:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0

 1062ed8:	4a 8d 1c 20          	lea    (%rax,%r12,1),%rbx
 1062edc:	48 89 df             	mov    %rbx,%rdi
 1062edf:	48 8d b5 e0 e8 ff ff 	lea    -0x1720(%rbp),%rsi
 1062ee6:	c5 f8 77             	vzeroupper 
 1062ee9:	e8 42 95 05 00       	call   10bc430 <frequency_merge_bench.query__anon_2966>
 1062eee:	49 89 c6             	mov    %rax,%r14
 1062ef1:	48 89 df             	mov    %rbx,%rdi
 1062ef4:	48 8d b5 e0 e4 ff ff 	lea    -0x1b20(%rbp),%rsi
 1062efb:	e8 70 93 05 00       	call   10bc270 <frequency_merge_bench.query__anon_2967>
 1062f00:	49 39 c6             	cmp    %rax,%r14
 1062f03:	0f 85 48 0a 00 00    	jne    1063951 <start.posixCallMainAndExit+0x5bd1>
 1062f09:	c5 fe 6f 85 e0 e8 ff 	vmovdqu -0x1720(%rbp),%ymm0
 1062f10:	ff 
 1062f11:	c5 fd ef 85 e0 e4 ff 	vpxor  -0x1b20(%rbp),%ymm0,%ymm0
 1062f18:	ff 
 1062f19:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1062f1e:	0f 85 2d 0a 00 00    	jne    1063951 <start.posixCallMainAndExit+0x5bd1>
 1062f24:	c5 fe 6f 85 00 e9 ff 	vmovdqu -0x1700(%rbp),%ymm0
 1062f2b:	ff 
 1062f2c:	c5 fd ef 85 00 e5 ff 	vpxor  -0x1b00(%rbp),%ymm0,%ymm0

 10633cf:	45 31 f6             	xor    %r14d,%r14d
 10633d2:	69 db 0d 66 19 00    	imul   $0x19660d,%ebx,%ebx
 10633d8:	81 c3 5f f3 6e 3c    	add    $0x3c6ef35f,%ebx
 10633de:	89 df                	mov    %ebx,%edi
 10633e0:	c1 ef 04             	shr    $0x4,%edi
 10633e3:	81 e7 00 f0 03 00    	and    $0x3f000,%edi
 10633e9:	4c 01 ff             	add    %r15,%rdi
 10633ec:	4c 89 ee             	mov    %r13,%rsi
 10633ef:	e8 3c 90 05 00       	call   10bc430 <frequency_merge_bench.query__anon_2966>
 10633f4:	0f b6 cf             	movzbl %bh,%ecx
 10633f7:	8b 8c 8d 40 54 ff ff 	mov    -0xabc0(%rbp,%rcx,4),%ecx
 10633fe:	49 01 c6             	add    %rax,%r14
 1063401:	49 01 ce             	add    %rcx,%r14
 1063404:	49 ff cc             	dec    %r12
 1063407:	75 c9                	jne    10633d2 <start.posixCallMainAndExit+0x5652>
 1063409:	4c 89 ad 40 94 ff ff 	mov    %r13,-0x6bc0(%rbp)
 1063410:	48 8d bd 40 94 ff ff 	lea    -0x6bc0(%rbp),%rdi
 1063417:	48 89 bd 08 fc ff ff 	mov    %rdi,-0x3f8(%rbp)
 106341e:	ba 01 00 00 00       	mov    $0x1,%edx
 1063423:	e8 98 2e 04 00       	call   10a62c0 <Io.Threaded.now>

 1063440:	45 31 f6             	xor    %r14d,%r14d
 1063443:	69 db 0d 66 19 00    	imul   $0x19660d,%ebx,%ebx
 1063449:	81 c3 5f f3 6e 3c    	add    $0x3c6ef35f,%ebx
 106344f:	89 df                	mov    %ebx,%edi
 1063451:	c1 ef 04             	shr    $0x4,%edi
 1063454:	81 e7 00 f0 03 00    	and    $0x3f000,%edi
 106345a:	4c 01 ff             	add    %r15,%rdi
 106345d:	4c 89 ee             	mov    %r13,%rsi
 1063460:	e8 0b 8e 05 00       	call   10bc270 <frequency_merge_bench.query__anon_2967>
 1063465:	0f b6 cf             	movzbl %bh,%ecx
 1063468:	8b 8c 8d 40 54 ff ff 	mov    -0xabc0(%rbp,%rcx,4),%ecx
 106346f:	49 01 c6             	add    %rax,%r14
 1063472:	49 01 ce             	add    %rcx,%r14
 1063475:	49 ff cc             	dec    %r12
 1063478:	75 c9                	jne    1063443 <start.posixCallMainAndExit+0x56c3>
 106347a:	4c 89 ad 40 94 ff ff 	mov    %r13,-0x6bc0(%rbp)
 1063481:	48 8d bd 40 94 ff ff 	lea    -0x6bc0(%rbp),%rdi
 1063488:	48 89 bd 10 fc ff ff 	mov    %rdi,-0x3f0(%rbp)
 106348f:	ba 01 00 00 00       	mov    $0x1,%edx
 1063494:	e8 27 2e 04 00       	call   10a62c0 <Io.Threaded.now>

 10634cc:	45 31 e4             	xor    %r12d,%r12d
 10634cf:	69 db 0d 66 19 00    	imul   $0x19660d,%ebx,%ebx
 10634d5:	81 c3 5f f3 6e 3c    	add    $0x3c6ef35f,%ebx
 10634db:	89 df                	mov    %ebx,%edi
 10634dd:	c1 ef 04             	shr    $0x4,%edi
 10634e0:	81 e7 00 f0 03 00    	and    $0x3f000,%edi
 10634e6:	4c 01 ff             	add    %r15,%rdi
 10634e9:	48 8d b5 40 54 ff ff 	lea    -0xabc0(%rbp),%rsi
 10634f0:	e8 3b 8f 05 00       	call   10bc430 <frequency_merge_bench.query__anon_2966>
 10634f5:	0f b6 cf             	movzbl %bh,%ecx
 10634f8:	8b 8c 8d 40 54 ff ff 	mov    -0xabc0(%rbp,%rcx,4),%ecx
 10634ff:	49 01 c4             	add    %rax,%r12
 1063502:	49 01 cc             	add    %rcx,%r12
 1063505:	49 ff cd             	dec    %r13
 1063508:	75 c5                	jne    10634cf <start.posixCallMainAndExit+0x574f>
 106350a:	48 8d 9d 40 54 ff ff 	lea    -0xabc0(%rbp),%rbx
 1063511:	48 89 9d 40 94 ff ff 	mov    %rbx,-0x6bc0(%rbp)
 1063518:	48 8d bd 40 94 ff ff 	lea    -0x6bc0(%rbp),%rdi
 106351f:	48 89 bd 28 fc ff ff 	mov    %rdi,-0x3d8(%rbp)
 1063526:	ba 01 00 00 00       	mov    $0x1,%edx

 1063562:	45 31 f6             	xor    %r14d,%r14d
 1063565:	69 db 0d 66 19 00    	imul   $0x19660d,%ebx,%ebx
 106356b:	81 c3 5f f3 6e 3c    	add    $0x3c6ef35f,%ebx
 1063571:	89 df                	mov    %ebx,%edi
 1063573:	c1 ef 04             	shr    $0x4,%edi
 1063576:	81 e7 00 f0 03 00    	and    $0x3f000,%edi
 106357c:	4c 01 ff             	add    %r15,%rdi
 106357f:	48 8d b5 40 54 ff ff 	lea    -0xabc0(%rbp),%rsi
 1063586:	e8 e5 8c 05 00       	call   10bc270 <frequency_merge_bench.query__anon_2967>
 106358b:	0f b6 cf             	movzbl %bh,%ecx
 106358e:	8b 8c 8d 40 54 ff ff 	mov    -0xabc0(%rbp,%rcx,4),%ecx
 1063595:	49 01 c6             	add    %rax,%r14
 1063598:	49 01 ce             	add    %rcx,%r14
 106359b:	49 ff cd             	dec    %r13
 106359e:	75 c5                	jne    1063565 <start.posixCallMainAndExit+0x57e5>
 10635a0:	48 8d 85 40 54 ff ff 	lea    -0xabc0(%rbp),%rax
 10635a7:	48 89 85 40 94 ff ff 	mov    %rax,-0x6bc0(%rbp)
 10635ae:	48 8d bd 40 94 ff ff 	lea    -0x6bc0(%rbp),%rdi
 10635b5:	48 89 bd 30 fc ff ff 	mov    %rdi,-0x3d0(%rbp)
 10635bc:	ba 01 00 00 00       	mov    $0x1,%edx

 10635f2:	45 31 e4             	xor    %r12d,%r12d
 10635f5:	69 db 0d 66 19 00    	imul   $0x19660d,%ebx,%ebx
 10635fb:	81 c3 5f f3 6e 3c    	add    $0x3c6ef35f,%ebx
 1063601:	89 df                	mov    %ebx,%edi
 1063603:	c1 ef 04             	shr    $0x4,%edi
 1063606:	81 e7 00 f0 03 00    	and    $0x3f000,%edi
 106360c:	4c 01 ff             	add    %r15,%rdi
 106360f:	48 8d b5 40 54 ff ff 	lea    -0xabc0(%rbp),%rsi
 1063616:	e8 55 8c 05 00       	call   10bc270 <frequency_merge_bench.query__anon_2967>
 106361b:	0f b6 cf             	movzbl %bh,%ecx
 106361e:	8b 8c 8d 40 54 ff ff 	mov    -0xabc0(%rbp,%rcx,4),%ecx
 1063625:	49 01 c4             	add    %rax,%r12
 1063628:	49 01 cc             	add    %rcx,%r12
 106362b:	49 ff ce             	dec    %r14
 106362e:	75 c5                	jne    10635f5 <start.posixCallMainAndExit+0x5875>
 1063630:	48 8d 9d 40 54 ff ff 	lea    -0xabc0(%rbp),%rbx
 1063637:	48 89 9d 40 94 ff ff 	mov    %rbx,-0x6bc0(%rbp)
 106363e:	48 8d bd 40 94 ff ff 	lea    -0x6bc0(%rbp),%rdi
 1063645:	48 89 bd 18 fc ff ff 	mov    %rdi,-0x3e8(%rbp)
 106364c:	ba 01 00 00 00       	mov    $0x1,%edx

 1063688:	45 31 f6             	xor    %r14d,%r14d
 106368b:	69 db 0d 66 19 00    	imul   $0x19660d,%ebx,%ebx
 1063691:	81 c3 5f f3 6e 3c    	add    $0x3c6ef35f,%ebx
 1063697:	89 df                	mov    %ebx,%edi
 1063699:	c1 ef 04             	shr    $0x4,%edi
 106369c:	81 e7 00 f0 03 00    	and    $0x3f000,%edi
 10636a2:	4c 01 ff             	add    %r15,%rdi
 10636a5:	48 8d b5 40 54 ff ff 	lea    -0xabc0(%rbp),%rsi
 10636ac:	e8 7f 8d 05 00       	call   10bc430 <frequency_merge_bench.query__anon_2966>
 10636b1:	0f b6 cf             	movzbl %bh,%ecx
 10636b4:	8b 8c 8d 40 54 ff ff 	mov    -0xabc0(%rbp,%rcx,4),%ecx
 10636bb:	49 01 c6             	add    %rax,%r14
 10636be:	49 01 ce             	add    %rcx,%r14
 10636c1:	49 ff cd             	dec    %r13
 10636c4:	75 c5                	jne    106368b <start.posixCallMainAndExit+0x590b>
 10636c6:	48 8d 85 40 54 ff ff 	lea    -0xabc0(%rbp),%rax
 10636cd:	48 89 85 40 94 ff ff 	mov    %rax,-0x6bc0(%rbp)
 10636d4:	48 8d bd 40 94 ff ff 	lea    -0x6bc0(%rbp),%rdi
 10636db:	48 89 bd 20 fc ff ff 	mov    %rdi,-0x3e0(%rbp)
 10636e2:	ba 01 00 00 00       	mov    $0x1,%edx
