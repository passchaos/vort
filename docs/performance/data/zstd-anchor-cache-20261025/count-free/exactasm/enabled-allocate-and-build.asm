 10bef01:	4d 89 c4             	mov    %r8,%r12
 10bef04:	49 89 f7             	mov    %rsi,%r15
 10bef07:	48 8b 3e             	mov    (%rsi),%rdi
 10bef0a:	4c 8b 46 08          	mov    0x8(%rsi),%r8
 10bef0e:	c6 85 d8 4e fd ff 00 	movb   $0x0,-0x2b128(%rbp)
 10bef15:	31 c0                	xor    %eax,%eax
 10bef17:	84 c0                	test   %al,%al
 10bef19:	0f 85 75 01 00 00    	jne    10bf094 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1c4>
 10bef1f:	49 89 cd             	mov    %rcx,%r13
 10bef22:	49 89 d6             	mov    %rdx,%r14
 10bef25:	49 8d 44 24 f9       	lea    -0x7(%r12),%rax
 10bef2a:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 10bef2e:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 10bef35:	48 8d 34 00          	lea    (%rax,%rax,1),%rsi
 10bef39:	48 89 bd 68 ff ff ff 	mov    %rdi,-0x98(%rbp)
 10bef40:	48 89 b5 70 ff ff ff 	mov    %rsi,-0x90(%rbp)
 10bef47:	ba 01 00 00 00       	mov    $0x1,%edx
 10bef4c:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 10bef53:	4c 89 85 58 ff ff ff 	mov    %r8,-0xa8(%rbp)
 10bef5a:	41 ff 10             	call   *(%r8)
 10bef5d:	48 85 c0             	test   %rax,%rax
 10bef60:	0f 84 2e 01 00 00    	je     10bf094 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1c4>
 10bef66:	49 89 c1             	mov    %rax,%r9
 10bef69:	c6 85 d8 4e fd ff 00 	movb   $0x0,-0x2b128(%rbp)
 10bef70:	31 c0                	xor    %eax,%eax
 10bef72:	84 c0                	test   %al,%al
 10bef74:	0f 85 f3 00 00 00    	jne    10bf06d <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x19d>
 10bef7a:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 10bef81:	48 8d 34 85 00 00 00 	lea    0x0(,%rax,4),%rsi
 10bef88:	00 
 10bef89:	48 8b bd 68 ff ff ff 	mov    -0x98(%rbp),%rdi
 10bef90:	48 89 b5 20 ff ff ff 	mov    %rsi,-0xe0(%rbp)
 10bef97:	ba 02 00 00 00       	mov    $0x2,%edx
 10bef9c:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 10befa3:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 10befaa:	4c 89 8d 38 ff ff ff 	mov    %r9,-0xc8(%rbp)
 10befb1:	ff 10                	call   *(%rax)
 10befb3:	4c 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%r9
 10befba:	48 85 c0             	test   %rax,%rax
 10befbd:	0f 84 aa 00 00 00    	je     10bf06d <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x19d>
 10befc3:	31 c9                	xor    %ecx,%ecx
 10befc5:	84 c9                	test   %cl,%cl
 10befc7:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 10befce:	75 52                	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10befd0:	4d 89 e8             	mov    %r13,%r8
 10befd3:	4d 01 e0             	add    %r12,%r8
 10befd6:	0f 92 c1             	setb   %cl
 10befd9:	0f 92 85 d8 4e fd ff 	setb   -0x2b128(%rbp)
 10befe0:	84 c9                	test   %cl,%cl
 10befe2:	75 3e                	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10befe4:	31 c9                	xor    %ecx,%ecx
 10befe6:	84 c9                	test   %cl,%cl
 10befe8:	75 38                	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10befea:	4c 89 cf             	mov    %r9,%rdi
 10befed:	48 03 bd 70 ff ff ff 	add    -0x90(%rbp),%rdi
 10beff4:	0f 92 c1             	setb   %cl
 10beff7:	0f 92 85 d8 4e fd ff 	setb   -0x2b128(%rbp)
 10beffe:	84 c9                	test   %cl,%cl
 10bf000:	75 20                	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10bf002:	31 c9                	xor    %ecx,%ecx
 10bf004:	84 c9                	test   %cl,%cl
 10bf006:	75 1a                	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10bf008:	48 89 c1             	mov    %rax,%rcx
 10bf00b:	48 01 d1             	add    %rdx,%rcx
 10bf00e:	40 0f 92 c6          	setb   %sil
 10bf012:	0f 92 85 d8 4e fd ff 	setb   -0x2b128(%rbp)
 10bf019:	40 84 f6             	test   %sil,%sil
 10bf01c:	0f 84 8c 00 00 00    	je     10bf0ae <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1de>
 10bf022:	4c 8b a5 68 ff ff ff 	mov    -0x98(%rbp),%r12
 10bf029:	4c 89 e7             	mov    %r12,%rdi
 10bf02c:	48 89 c6             	mov    %rax,%rsi
 10bf02f:	b9 02 00 00 00       	mov    $0x2,%ecx
 10bf034:	4c 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%r15
 10bf03b:	4d 89 f8             	mov    %r15,%r8
 10bf03e:	4c 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%r14
 10bf045:	4d 89 cd             	mov    %r9,%r13
 10bf048:	41 ff 56 18          	call   *0x18(%r14)
 10bf04c:	4c 89 e7             	mov    %r12,%rdi
 10bf04f:	4c 89 ee             	mov    %r13,%rsi
 10bf052:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 10bf059:	b9 01 00 00 00       	mov    $0x1,%ecx
 10bf05e:	4d 89 f8             	mov    %r15,%r8
 10bf061:	41 ff 56 18          	call   *0x18(%r14)
 10bf065:	c7 03 4d 00 00 00    	movl   $0x4d,(%rbx)
 10bf06b:	eb 2c                	jmp    10bf099 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1c9>
 10bf06d:	48 8b bd 68 ff ff ff 	mov    -0x98(%rbp),%rdi
 10bf074:	4c 89 ce             	mov    %r9,%rsi
 10bf077:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 10bf07e:	b9 01 00 00 00       	mov    $0x1,%ecx
 10bf083:	4c 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%r8
 10bf08a:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 10bf091:	ff 50 18             	call   *0x18(%rax)
 10bf094:	66 c7 03 1a 00       	movw   $0x1a,(%rbx)
 10bf099:	48 81 c4 28 b1 02 00 	add    $0x2b128,%rsp
 10bf0a0:	5b                   	pop    %rbx
 10bf0a1:	41 5c                	pop    %r12
 10bf0a3:	41 5d                	pop    %r13
 10bf0a5:	41 5e                	pop    %r14
 10bf0a7:	41 5f                	pop    %r15
 10bf0a9:	5d                   	pop    %rbp
 10bf0aa:	c5 f8 77             	vzeroupper 
 10bf0ad:	c3                   	ret    
 10bf0ae:	4c 39 cf             	cmp    %r9,%rdi
 10bf0b1:	74 13                	je     10bf0c6 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1f6>
 10bf0b3:	48 39 c1             	cmp    %rax,%rcx
 10bf0b6:	74 0e                	je     10bf0c6 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1f6>
 10bf0b8:	4c 39 c9             	cmp    %r9,%rcx
 10bf0bb:	76 09                	jbe    10bf0c6 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1f6>
 10bf0bd:	48 39 c7             	cmp    %rax,%rdi
 10bf0c0:	0f 87 5c ff ff ff    	ja     10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10bf0c6:	4d 39 e8             	cmp    %r13,%r8
 10bf0c9:	74 1c                	je     10bf0e7 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x217>
 10bf0cb:	4c 39 cf             	cmp    %r9,%rdi
 10bf0ce:	74 17                	je     10bf0e7 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x217>
 10bf0d0:	4c 39 ef             	cmp    %r13,%rdi
 10bf0d3:	40 0f 97 c7          	seta   %dil
 10bf0d7:	4d 39 c8             	cmp    %r9,%r8
 10bf0da:	40 0f 97 c6          	seta   %sil
 10bf0de:	40 84 f7             	test   %sil,%dil
 10bf0e1:	0f 85 3b ff ff ff    	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10bf0e7:	4d 39 e8             	cmp    %r13,%r8
 10bf0ea:	74 1b                	je     10bf107 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x237>
 10bf0ec:	48 39 c1             	cmp    %rax,%rcx
 10bf0ef:	74 16                	je     10bf107 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x237>
 10bf0f1:	4c 39 e9             	cmp    %r13,%rcx
 10bf0f4:	0f 97 c1             	seta   %cl
 10bf0f7:	49 39 c0             	cmp    %rax,%r8
 10bf0fa:	40 0f 97 c6          	seta   %sil
 10bf0fe:	40 84 f1             	test   %sil,%cl
 10bf101:	0f 85 1b ff ff ff    	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10bf107:	31 c9                	xor    %ecx,%ecx
 10bf109:	84 c9                	test   %cl,%cl
 10bf10b:	0f 85 11 ff ff ff    	jne    10bf022 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x152>
 10bf111:	49 ba 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r10
 10bf118:	79 37 9e 
 10bf11b:	49 8d 54 24 f8       	lea    -0x8(%r12),%rdx
 10bf120:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 10bf127:	83 e1 03             	and    $0x3,%ecx
 10bf12a:	48 89 95 f0 fe ff ff 	mov    %rdx,-0x110(%rbp)
 10bf131:	48 83 fa 03          	cmp    $0x3,%rdx
 10bf135:	73 07                	jae    10bf13e <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x26e>
 10bf137:	31 d2                	xor    %edx,%edx
 10bf139:	e9 80 00 00 00       	jmp    10bf1be <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x2ee>
 10bf13e:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 10bf145:	48 83 e6 fc          	and    $0xfffffffffffffffc,%rsi
 10bf149:	31 d2                	xor    %edx,%edx
 10bf14b:	49 8b 7c 15 00       	mov    0x0(%r13,%rdx,1),%rdi
 10bf150:	49 0f af fa          	imul   %r10,%rdi
 10bf154:	48 c1 ef 31          	shr    $0x31,%rdi
 10bf158:	66 41 89 3c 51       	mov    %di,(%r9,%rdx,2)
 10bf15d:	c7 04 90 ff ff ff ff 	movl   $0xffffffff,(%rax,%rdx,4)
 10bf164:	49 8b 7c 15 01       	mov    0x1(%r13,%rdx,1),%rdi
 10bf169:	49 0f af fa          	imul   %r10,%rdi
 10bf16d:	48 c1 ef 31          	shr    $0x31,%rdi
 10bf171:	66 41 89 7c 51 02    	mov    %di,0x2(%r9,%rdx,2)
 10bf177:	c7 44 90 04 ff ff ff 	movl   $0xffffffff,0x4(%rax,%rdx,4)
 10bf17e:	ff 
 10bf17f:	49 8b 7c 15 02       	mov    0x2(%r13,%rdx,1),%rdi
 10bf184:	49 0f af fa          	imul   %r10,%rdi
 10bf188:	48 c1 ef 31          	shr    $0x31,%rdi
 10bf18c:	66 41 89 7c 51 04    	mov    %di,0x4(%r9,%rdx,2)
 10bf192:	c7 44 90 08 ff ff ff 	movl   $0xffffffff,0x8(%rax,%rdx,4)
 10bf199:	ff 
 10bf19a:	49 8b 7c 15 03       	mov    0x3(%r13,%rdx,1),%rdi
 10bf19f:	49 0f af fa          	imul   %r10,%rdi
 10bf1a3:	48 c1 ef 31          	shr    $0x31,%rdi
 10bf1a7:	66 41 89 7c 51 06    	mov    %di,0x6(%r9,%rdx,2)
 10bf1ad:	c7 44 90 0c ff ff ff 	movl   $0xffffffff,0xc(%rax,%rdx,4)
 10bf1b4:	ff 
 10bf1b5:	48 83 c2 04          	add    $0x4,%rdx
 10bf1b9:	48 39 d6             	cmp    %rdx,%rsi
 10bf1bc:	75 8d                	jne    10bf14b <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x27b>
 10bf1be:	48 85 c9             	test   %rcx,%rcx
 10bf1c1:	74 2f                	je     10bf1f2 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x322>
 10bf1c3:	48 8d 34 90          	lea    (%rax,%rdx,4),%rsi
 10bf1c7:	49 8d 3c 51          	lea    (%r9,%rdx,2),%rdi
 10bf1cb:	4c 01 ea             	add    %r13,%rdx
 10bf1ce:	45 31 c0             	xor    %r8d,%r8d
 10bf1d1:	4e 8b 0c 02          	mov    (%rdx,%r8,1),%r9
 10bf1d5:	4d 0f af ca          	imul   %r10,%r9
 10bf1d9:	49 c1 e9 31          	shr    $0x31,%r9
 10bf1dd:	66 46 89 0c 47       	mov    %r9w,(%rdi,%r8,2)
 10bf1e2:	42 c7 04 86 ff ff ff 	movl   $0xffffffff,(%rsi,%r8,4)
 10bf1e9:	ff 
 10bf1ea:	49 ff c0             	inc    %r8
 10bf1ed:	4c 39 c1             	cmp    %r8,%rcx
 10bf1f0:	75 df                	jne    10bf1d1 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x301>
