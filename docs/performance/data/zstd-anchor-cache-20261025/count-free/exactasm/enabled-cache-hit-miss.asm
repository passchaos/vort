 10bf33d:	40 84 f6             	test   %sil,%sil
 10bf340:	74 09                	je     10bf34b <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x47b>
 10bf342:	4d 39 c3             	cmp    %r8,%r11
 10bf345:	0f 82 b2 02 00 00    	jb     10bf5fd <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x72d>
 10bf34b:	43 0f b7 04 51       	movzwl (%r9,%r10,2),%eax
 10bf350:	80 bc 05 d8 4e ff ff 	cmpb   $0x0,-0xb128(%rbp,%rax,1)
 10bf357:	00 
 10bf358:	74 b6                	je     10bf310 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x440>
 10bf35a:	8b 94 85 d8 4e fd ff 	mov    -0x2b128(%rbp,%rax,4),%edx
 10bf361:	c6 84 05 d8 4e ff ff 	movb   $0x0,-0xb128(%rbp,%rax,1)
 10bf368:	00 
 10bf369:	48 39 d1             	cmp    %rdx,%rcx
 10bf36c:	77 b9                	ja     10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf36e:	4a 8d 04 11          	lea    (%rcx,%r10,1),%rax
 10bf372:	48 89 c7             	mov    %rax,%rdi
 10bf375:	48 29 d7             	sub    %rdx,%rdi
 10bf378:	48 89 bd e8 fe ff ff 	mov    %rdi,-0x118(%rbp)
 10bf37f:	76 a6                	jbe    10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf381:	40 84 f6             	test   %sil,%sil
 10bf384:	74 0a                	je     10bf390 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x4c0>
 10bf386:	4d 39 c3             	cmp    %r8,%r11
 10bf389:	77 05                	ja     10bf390 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x4c0>
 10bf38b:	40 b6 01             	mov    $0x1,%sil
 10bf38e:	eb 97                	jmp    10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf390:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 10bf397:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 10bf39e:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 10bf3a2:	42 8b 3c 90          	mov    (%rax,%r10,4),%edi
 10bf3a6:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
 10bf3ab:	48 39 c7             	cmp    %rax,%rdi
 10bf3ae:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10bf3b2:	75 52                	jne    10bf406 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x536>
 10bf3b4:	4c 89 ef             	mov    %r13,%rdi
 10bf3b7:	48 89 75 c0          	mov    %rsi,-0x40(%rbp)
 10bf3bb:	4c 89 e6             	mov    %r12,%rsi
 10bf3be:	4c 89 55 b8          	mov    %r10,-0x48(%rbp)
 10bf3c2:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 10bf3c9:	4c 89 5d b0          	mov    %r11,-0x50(%rbp)
 10bf3cd:	48 89 95 48 ff ff ff 	mov    %rdx,-0xb8(%rbp)
 10bf3d4:	e8 d7 47 03 00       	call   10f3bb0 <zstd.duplicateMatchLength>
 10bf3d9:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 10bf3e0:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10bf3e4:	4c 8b 55 b8          	mov    -0x48(%rbp),%r10
 10bf3e8:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 10bf3ec:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 10bf3f0:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10bf3f4:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf3f8:	48 89 c7             	mov    %rax,%rdi
 10bf3fb:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 10bf402:	42 89 3c 90          	mov    %edi,(%rax,%r10,4)
 10bf406:	48 89 7d 80          	mov    %rdi,-0x80(%rbp)
 10bf40a:	48 83 ff 08          	cmp    $0x8,%rdi
 10bf40e:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10bf415:	0f 82 0c ff ff ff    	jb     10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf41b:	40 84 f6             	test   %sil,%sil
 10bf41e:	74 10                	je     10bf430 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x560>
 10bf420:	4c 39 45 80          	cmp    %r8,-0x80(%rbp)
 10bf424:	0f 82 fd fe ff ff    	jb     10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf42a:	0f 86 32 01 00 00    	jbe    10bf562 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x692>
