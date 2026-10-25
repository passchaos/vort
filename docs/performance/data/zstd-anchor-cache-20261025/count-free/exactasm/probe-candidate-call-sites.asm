0000000001060a20 <probe.timed__anon_3112>:
 1060a7c:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 1060a83:	48 8d 7d d4          	lea    -0x2c(%rbp),%rdi
 1060a87:	48 8d 55 a0          	lea    -0x60(%rbp),%rdx
 1060a8b:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 1060a8f:	4c 89 f6             	mov    %r14,%rsi
 1060a92:	48 89 d9             	mov    %rbx,%rcx
 1060a95:	4d 89 e8             	mov    %r13,%r8
 1060a98:	e8 03 40 09 00       	call   10f4aa0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085>
 1060a9d:	0f b7 5d d4          	movzwl -0x2c(%rbp),%ebx
 1060aa1:	66 85 db             	test   %bx,%bx
 1060aa4:	0f 85 23 01 00 00    	jne    1060bcd <probe.timed__anon_3112+0x1ad>
 1060aaa:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 1060aae:	44 0f b6 75 18       	movzbl 0x18(%rbp),%r14d
 1060ab3:	49 8b 34 24          	mov    (%r12),%rsi
 1060ab7:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1060abc:	44 0f b6 65 d6       	movzbl -0x2a(%rbp),%r12d
 1060ac1:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1060ac5:	ba 01 00 00 00       	mov    $0x1,%edx
 1060aca:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 1060ad0:	48 8b 5d 90          	mov    -0x70(%rbp),%rbx
 1060ad4:	4c 8b 6d 98          	mov    -0x68(%rbp),%r13
 1060ad8:	48 2b 5d 80          	sub    -0x80(%rbp),%rbx
 1060adc:	4c 1b ad 78 ff ff ff 	sbb    -0x88(%rbp),%r13

0000000001060c00 <probe.timed__anon_3146>:
 1060c5c:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 1060c63:	48 8d 7d d4          	lea    -0x2c(%rbp),%rdi
 1060c67:	48 8d 55 a0          	lea    -0x60(%rbp),%rdx
 1060c6b:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 1060c6f:	4c 89 f6             	mov    %r14,%rsi
 1060c72:	48 89 d9             	mov    %rbx,%rcx
 1060c75:	4d 89 e8             	mov    %r13,%r8
 1060c78:	e8 53 e2 05 00       	call   10beed0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091>
 1060c7d:	0f b7 5d d4          	movzwl -0x2c(%rbp),%ebx
 1060c81:	66 85 db             	test   %bx,%bx
 1060c84:	0f 85 23 01 00 00    	jne    1060dad <probe.timed__anon_3146+0x1ad>
 1060c8a:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 1060c8e:	44 0f b6 75 18       	movzbl 0x18(%rbp),%r14d
 1060c93:	49 8b 34 24          	mov    (%r12),%rsi
 1060c97:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1060c9c:	44 0f b6 65 d6       	movzbl -0x2a(%rbp),%r12d
 1060ca1:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1060ca5:	ba 01 00 00 00       	mov    $0x1,%edx
 1060caa:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 1060cb0:	48 8b 5d 90          	mov    -0x70(%rbp),%rbx
 1060cb4:	4c 8b 6d 98          	mov    -0x68(%rbp),%r13
 1060cb8:	48 2b 5d 80          	sub    -0x80(%rbp),%rbx
 1060cbc:	4c 1b ad 78 ff ff ff 	sbb    -0x88(%rbp),%r13

0000000001060de0 <probe.main>:
 10634b2:	41 b8 00 00 01 00    	mov    $0x10000,%r8d
 10634b8:	48 8d bd 14 fe ff ff 	lea    -0x1ec(%rbp),%rdi
 10634bf:	48 8d 9d 00 ff ff ff 	lea    -0x100(%rbp),%rbx
 10634c6:	48 89 de             	mov    %rbx,%rsi
 10634c9:	48 8d 95 50 fd ff ff 	lea    -0x2b0(%rbp),%rdx
 10634d0:	4c 8b a5 60 ff ff ff 	mov    -0xa0(%rbp),%r12
 10634d7:	4c 89 e1             	mov    %r12,%rcx
 10634da:	e8 c1 15 09 00       	call   10f4aa0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085>
 10634df:	44 0f b7 bd 14 fe ff 	movzwl -0x1ec(%rbp),%r15d
 10634e6:	ff 
 10634e7:	66 45 85 ff          	test   %r15w,%r15w
 10634eb:	0f 85 7e 30 00 00    	jne    106656f <probe.main+0x578f>
 10634f1:	44 0f b6 b5 16 fe ff 	movzbl -0x1ea(%rbp),%r14d
 10634f8:	ff 
 10634f9:	41 b8 00 00 01 00    	mov    $0x10000,%r8d
 10634ff:	48 8d bd 10 fe ff ff 	lea    -0x1f0(%rbp),%rdi
 1063506:	48 89 de             	mov    %rbx,%rsi
 1063509:	48 8d 95 d0 fc ff ff 	lea    -0x330(%rbp),%rdx
 1063510:	4c 89 e1             	mov    %r12,%rcx
 1063513:	e8 b8 b9 05 00       	call   10beed0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091>
 1063518:	44 0f b7 bd 10 fe ff 	movzwl -0x1f0(%rbp),%r15d
 106351f:	ff 
 1063520:	66 45 85 ff          	test   %r15w,%r15w

0000000001060de0 <probe.main>:
 10634f1:	44 0f b6 b5 16 fe ff 	movzbl -0x1ea(%rbp),%r14d
 10634f8:	ff 
 10634f9:	41 b8 00 00 01 00    	mov    $0x10000,%r8d
 10634ff:	48 8d bd 10 fe ff ff 	lea    -0x1f0(%rbp),%rdi
 1063506:	48 89 de             	mov    %rbx,%rsi
 1063509:	48 8d 95 d0 fc ff ff 	lea    -0x330(%rbp),%rdx
 1063510:	4c 89 e1             	mov    %r12,%rcx
 1063513:	e8 b8 b9 05 00       	call   10beed0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091>
 1063518:	44 0f b7 bd 10 fe ff 	movzwl -0x1f0(%rbp),%r15d
 106351f:	ff 
 1063520:	66 45 85 ff          	test   %r15w,%r15w
 1063524:	0f 85 1b 30 00 00    	jne    1066545 <probe.main+0x5765>
 106352a:	45 89 f7             	mov    %r14d,%r15d
 106352d:	41 80 e7 01          	and    $0x1,%r15b
 1063531:	44 3a bd 12 fe ff ff 	cmp    -0x1ee(%rbp),%r15b
 1063538:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 106353c:	0f 85 30 09 00 00    	jne    1063e72 <probe.main+0x3092>
 1063542:	48 8b bd 50 fd ff ff 	mov    -0x2b0(%rbp),%rdi
 1063549:	48 8b b5 58 fd ff ff 	mov    -0x2a8(%rbp),%rsi
 1063550:	48 8b 95 d0 fc ff ff 	mov    -0x330(%rbp),%rdx
 1063557:	48 8b 9d d8 fc ff ff 	mov    -0x328(%rbp),%rbx
 106355e:	48 85 f6             	test   %rsi,%rsi
 1063561:	48 89 bd 70 ff ff ff 	mov    %rdi,-0x90(%rbp)
