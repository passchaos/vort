
/tmp/vort-zstd-anchor-cache-20261025/count-free/anchor-count-free:     file format elf64-x86-64


Disassembly of section .text:

00000000010beed0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091>:
 10beed0:	55                   	push   %rbp
 10beed1:	48 89 e5             	mov    %rsp,%rbp
 10beed4:	41 57                	push   %r15
 10beed6:	41 56                	push   %r14
 10beed8:	41 55                	push   %r13
 10beeda:	41 54                	push   %r12
 10beedc:	53                   	push   %rbx
 10beedd:	48 81 ec 28 b1 02 00 	sub    $0x2b128,%rsp
 10beee4:	48 89 fb             	mov    %rdi,%rbx
 10beee7:	49 8d 80 ff ff fd ff 	lea    -0x20001(%r8),%rax
 10beeee:	48 3d ff ff fe ff    	cmp    $0xfffffffffffeffff,%rax
 10beef4:	73 0b                	jae    10bef01 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x31>
 10beef6:	c7 03 4d 00 00 00    	movl   $0x4d,(%rbx)
 10beefc:	e9 98 01 00 00       	jmp    10bf099 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1c9>
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
 10bf1f2:	41 0f b6 55 00       	movzbl 0x0(%r13),%edx
 10bf1f7:	b9 01 00 00 00       	mov    $0x1,%ecx
 10bf1fc:	41 38 54 0d 00       	cmp    %dl,0x0(%r13,%rcx,1)
 10bf201:	75 14                	jne    10bf217 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x347>
 10bf203:	48 ff c1             	inc    %rcx
 10bf206:	49 39 cc             	cmp    %rcx,%r12
 10bf209:	75 f1                	jne    10bf1fc <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x32c>
 10bf20b:	0f b6 0d b0 0d f8 ff 	movzbl -0x7f250(%rip),%ecx        # 103ffc2 <__anon_14421+0x2>
 10bf212:	e9 ad 05 00 00       	jmp    10bf7c4 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x8f4>
 10bf217:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 10bf21b:	48 8d bd f8 ce ff ff 	lea    -0x3108(%rbp),%rdi
 10bf222:	ba 50 10 00 00       	mov    $0x1050,%edx
 10bf227:	31 f6                	xor    %esi,%esi
 10bf229:	e8 72 de 03 00       	call   10fd0a0 <compiler_rt.memset>
 10bf22e:	48 8d bd 58 df ff ff 	lea    -0x20a8(%rbp),%rdi
 10bf235:	ba 10 07 00 00       	mov    $0x710,%edx
 10bf23a:	31 f6                	xor    %esi,%esi
 10bf23c:	e8 5f de 03 00       	call   10fd0a0 <compiler_rt.memset>
 10bf241:	31 c9                	xor    %ecx,%ecx
 10bf243:	4c 89 ad d8 ce ff ff 	mov    %r13,-0x3128(%rbp)
 10bf24a:	4c 89 a5 e0 ce ff ff 	mov    %r12,-0x3120(%rbp)
 10bf251:	48 c7 85 e8 ce ff ff 	movq   $0x0,-0x3118(%rbp)
 10bf258:	00 00 00 00 
 10bf25c:	48 c7 85 f0 ce ff ff 	movq   $0x1,-0x3110(%rbp)
 10bf263:	01 00 00 00 
 10bf267:	4c 89 ad 48 df ff ff 	mov    %r13,-0x20b8(%rbp)
 10bf26e:	4c 89 a5 50 df ff ff 	mov    %r12,-0x20b0(%rbp)
 10bf275:	c6 85 68 e6 ff ff 01 	movb   $0x1,-0x1998(%rbp)
 10bf27c:	b8 07 00 00 00       	mov    $0x7,%eax
 10bf281:	4c 29 e0             	sub    %r12,%rax
 10bf284:	48 89 85 f8 fe ff ff 	mov    %rax,-0x108(%rbp)
 10bf28b:	31 d2                	xor    %edx,%edx
 10bf28d:	48 89 55 88          	mov    %rdx,-0x78(%rbp)
 10bf291:	80 bd 68 e6 ff ff 00 	cmpb   $0x0,-0x1998(%rbp)
 10bf298:	48 89 4d c8          	mov    %rcx,-0x38(%rbp)
 10bf29c:	0f 84 fa 02 00 00    	je     10bf59c <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x6cc>
 10bf2a2:	ba 00 80 00 00       	mov    $0x8000,%edx
 10bf2a7:	48 8d bd d8 4e ff ff 	lea    -0xb128(%rbp),%rdi
 10bf2ae:	31 f6                	xor    %esi,%esi
 10bf2b0:	c5 f8 77             	vzeroupper 
 10bf2b3:	e8 e8 dd 03 00       	call   10fd0a0 <compiler_rt.memset>
 10bf2b8:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf2bc:	48 3b 8d f0 fe ff ff 	cmp    -0x110(%rbp),%rcx
 10bf2c3:	0f 87 bd 03 00 00    	ja     10bf686 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7b6>
 10bf2c9:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10bf2cd:	48 8d 04 88          	lea    (%rax,%rcx,4),%rax
 10bf2d1:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 10bf2d8:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 10bf2df:	48 01 c8             	add    %rcx,%rax
 10bf2e2:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 10bf2e9:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10bf2f0:	48 8d 14 48          	lea    (%rax,%rcx,2),%rdx
 10bf2f4:	4d 89 e3             	mov    %r12,%r11
 10bf2f7:	49 29 cb             	sub    %rcx,%r11
 10bf2fa:	48 c7 45 90 ff ff ff 	movq   $0xffffffffffffffff,-0x70(%rbp)
 10bf301:	ff 
 10bf302:	45 31 d2             	xor    %r10d,%r10d
 10bf305:	31 f6                	xor    %esi,%esi
 10bf307:	49 89 d1             	mov    %rdx,%r9
 10bf30a:	48 89 55 a0          	mov    %rdx,-0x60(%rbp)
 10bf30e:	eb 2d                	jmp    10bf33d <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x46d>
 10bf310:	42 8d 14 11          	lea    (%rcx,%r10,1),%edx
 10bf314:	89 94 85 d8 4e fd ff 	mov    %edx,-0x2b128(%rbp,%rax,4)
 10bf31b:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 10bf31f:	c6 84 05 d8 4e ff ff 	movb   $0x1,-0xb128(%rbp,%rax,1)
 10bf326:	01 
 10bf327:	49 ff c2             	inc    %r10
 10bf32a:	49 ff cb             	dec    %r11
 10bf32d:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 10bf334:	4c 01 d0             	add    %r10,%rax
 10bf337:	0f 84 c5 02 00 00    	je     10bf602 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x732>
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
 10bf430:	4c 89 5d b0          	mov    %r11,-0x50(%rbp)
 10bf434:	4e 8d 0c 11          	lea    (%rcx,%r10,1),%r9
 10bf438:	4c 89 c9             	mov    %r9,%rcx
 10bf43b:	48 89 95 48 ff ff ff 	mov    %rdx,-0xb8(%rbp)
 10bf442:	48 29 d1             	sub    %rdx,%rcx
 10bf445:	4c 89 c2             	mov    %r8,%rdx
 10bf448:	4c 8b 45 80          	mov    -0x80(%rbp),%r8
 10bf44c:	4d 01 c1             	add    %r8,%r9
 10bf44f:	48 89 75 c0          	mov    %rsi,-0x40(%rbp)
 10bf453:	40 84 f6             	test   %sil,%sil
 10bf456:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 10bf45a:	48 89 85 08 ff ff ff 	mov    %rax,-0xf8(%rbp)
 10bf461:	48 89 95 10 ff ff ff 	mov    %rdx,-0xf0(%rbp)
 10bf468:	0f 95 85 18 ff ff ff 	setne  -0xe8(%rbp)
 10bf46f:	48 8d 85 19 ff ff ff 	lea    -0xe7(%rbp),%rax
 10bf476:	c7 40 03 00 00 00 00 	movl   $0x0,0x3(%rax)
 10bf47d:	c7 00 00 00 00 00    	movl   $0x0,(%rax)
 10bf483:	48 83 ec 08          	sub    $0x8,%rsp
 10bf487:	48 8d bd 70 fa ff ff 	lea    -0x590(%rbp),%rdi
 10bf48e:	48 8d b5 d8 ce ff ff 	lea    -0x3128(%rbp),%rsi
 10bf495:	4c 89 55 b8          	mov    %r10,-0x48(%rbp)
 10bf499:	4c 89 d2             	mov    %r10,%rdx
 10bf49c:	48 8d 85 08 ff ff ff 	lea    -0xf8(%rbp),%rax
 10bf4a3:	50                   	push   %rax
 10bf4a4:	e8 97 23 03 00       	call   10f1840 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner>
 10bf4a9:	48 83 c4 10          	add    $0x10,%rsp
 10bf4ad:	66 83 bd 80 fa ff ff 	cmpw   $0x0,-0x580(%rbp)
 10bf4b4:	00 
 10bf4b5:	74 1d                	je     10bf4d4 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x604>
 10bf4b7:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf4bb:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10bf4bf:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 10bf4c3:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 10bf4c7:	4c 8b 55 b8          	mov    -0x48(%rbp),%r10
 10bf4cb:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10bf4cf:	e9 53 fe ff ff       	jmp    10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf4d4:	80 bd 78 fa ff ff 00 	cmpb   $0x0,-0x588(%rbp)
 10bf4db:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 10bf4df:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 10bf4e3:	0f 84 a6 00 00 00    	je     10bf58f <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x6bf>
 10bf4e9:	48 8b 85 70 fa ff ff 	mov    -0x590(%rbp),%rax
 10bf4f0:	48 3b 45 90          	cmp    -0x70(%rbp),%rax
 10bf4f4:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf4f8:	4c 8b 55 b8          	mov    -0x48(%rbp),%r10
 10bf4fc:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10bf500:	72 2d                	jb     10bf52f <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x65f>
 10bf502:	40 84 f6             	test   %sil,%sil
 10bf505:	74 b0                	je     10bf4b7 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x5e7>
 10bf507:	48 3b 45 90          	cmp    -0x70(%rbp),%rax
 10bf50b:	75 aa                	jne    10bf4b7 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x5e7>
 10bf50d:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10bf511:	4c 3b 45 80          	cmp    -0x80(%rbp),%r8
 10bf515:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf519:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 10bf51d:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 10bf521:	4c 8b 55 b8          	mov    -0x48(%rbp),%r10
 10bf525:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10bf529:	0f 83 f8 fd ff ff    	jae    10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf52f:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 10bf533:	4c 8b 45 80          	mov    -0x80(%rbp),%r8
 10bf537:	40 b6 01             	mov    $0x1,%sil
 10bf53a:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 10bf541:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 10bf548:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 10bf54f:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10bf556:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 10bf55d:	e9 c5 fd ff ff       	jmp    10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf562:	48 3b 85 50 ff ff ff 	cmp    -0xb0(%rbp),%rax
 10bf569:	0f 82 c1 fe ff ff    	jb     10bf430 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x560>
 10bf56f:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 10bf576:	48 2b 85 30 ff ff ff 	sub    -0xd0(%rbp),%rax
 10bf57d:	48 39 85 e8 fe ff ff 	cmp    %rax,-0x118(%rbp)
 10bf584:	0f 83 9d fd ff ff    	jae    10bf327 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x457>
 10bf58a:	e9 a1 fe ff ff       	jmp    10bf430 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x560>
 10bf58f:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf593:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10bf597:	e9 2b ff ff ff       	jmp    10bf4c7 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x5f7>
 10bf59c:	48 8d bd 70 fe ff ff 	lea    -0x190(%rbp),%rdi
 10bf5a3:	4c 89 ee             	mov    %r13,%rsi
 10bf5a6:	4c 89 e2             	mov    %r12,%rdx
 10bf5a9:	c5 f8 77             	vzeroupper 
 10bf5ac:	e8 1f 0f 03 00       	call   10f04d0 <zstd.findBestDuplicateMatchIn>
 10bf5b1:	0f b7 8d 98 fe ff ff 	movzwl -0x168(%rbp),%ecx
 10bf5b8:	66 85 c9             	test   %cx,%cx
 10bf5bb:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10bf5bf:	0f 85 04 02 00 00    	jne    10bf7c9 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x8f9>
 10bf5c5:	80 bd 90 fe ff ff 00 	cmpb   $0x0,-0x170(%rbp)
 10bf5cc:	0f 84 ba 00 00 00    	je     10bf68c <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7bc>
 10bf5d2:	c5 fc 10 85 70 fe ff 	vmovups -0x190(%rbp),%ymm0
 10bf5d9:	ff 
 10bf5da:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 10bf5e1:	ff 
 10bf5e2:	4c 8b 85 a8 fe ff ff 	mov    -0x158(%rbp),%r8
 10bf5e9:	4c 8b 8d b0 fe ff ff 	mov    -0x150(%rbp),%r9
 10bf5f0:	48 8d 85 a0 fe ff ff 	lea    -0x160(%rbp),%rax
 10bf5f7:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf5fb:	eb 45                	jmp    10bf642 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x772>
 10bf5fd:	4d 89 c1             	mov    %r8,%r9
 10bf600:	eb 08                	jmp    10bf60a <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x73a>
 10bf602:	4d 89 c1             	mov    %r8,%r9
 10bf605:	40 84 f6             	test   %sil,%sil
 10bf608:	74 7c                	je     10bf686 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7b6>
 10bf60a:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 10bf611:	48 89 85 c0 fe ff ff 	mov    %rax,-0x140(%rbp)
 10bf618:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 10bf61f:	4c 89 85 c8 fe ff ff 	mov    %r8,-0x138(%rbp)
 10bf626:	4c 89 8d d0 fe ff ff 	mov    %r9,-0x130(%rbp)
 10bf62d:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 10bf634:	48 89 85 d8 fe ff ff 	mov    %rax,-0x128(%rbp)
 10bf63b:	48 8d 85 c0 fe ff ff 	lea    -0x140(%rbp),%rax
 10bf642:	4c 89 c6             	mov    %r8,%rsi
 10bf645:	48 29 ce             	sub    %rcx,%rsi
 10bf648:	48 8b 7d 88          	mov    -0x78(%rbp),%rdi
 10bf64c:	48 89 fa             	mov    %rdi,%rdx
 10bf64f:	48 c1 e2 05          	shl    $0x5,%rdx
 10bf653:	c5 fc 10 00          	vmovups (%rax),%ymm0
 10bf657:	c5 fc 11 84 15 70 ea 	vmovups %ymm0,-0x1590(%rbp,%rdx,1)
 10bf65e:	ff ff 
 10bf660:	48 89 b4 fd 70 e6 ff 	mov    %rsi,-0x1990(%rbp,%rdi,8)
 10bf667:	ff 
 10bf668:	48 8d 47 01          	lea    0x1(%rdi),%rax
 10bf66c:	4c 89 c9             	mov    %r9,%rcx
 10bf66f:	4c 01 c1             	add    %r8,%rcx
 10bf672:	48 83 ff 7e          	cmp    $0x7e,%rdi
 10bf676:	77 1c                	ja     10bf694 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7c4>
 10bf678:	48 89 c2             	mov    %rax,%rdx
 10bf67b:	4c 39 e1             	cmp    %r12,%rcx
 10bf67e:	0f 82 09 fc ff ff    	jb     10bf28d <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x3bd>
 10bf684:	eb 0e                	jmp    10bf694 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7c4>
 10bf686:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 10bf68a:	eb 08                	jmp    10bf694 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7c4>
 10bf68c:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 10bf690:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bf694:	48 83 f8 02          	cmp    $0x2,%rax
 10bf698:	73 15                	jae    10bf6af <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7df>
 10bf69a:	0f b6 05 21 09 f8 ff 	movzbl -0x7f6df(%rip),%eax        # 103ffc2 <__anon_14421+0x2>
 10bf6a1:	88 45 d6             	mov    %al,-0x2a(%rbp)
 10bf6a4:	31 c9                	xor    %ecx,%ecx
 10bf6a6:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10bf6aa:	e9 1a 01 00 00       	jmp    10bf7c9 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x8f9>
 10bf6af:	49 89 cb             	mov    %rcx,%r11
 10bf6b2:	48 8d 14 c5 00 00 00 	lea    0x0(,%rax,8),%rdx
 10bf6b9:	00 
 10bf6ba:	48 83 e2 f0          	and    $0xfffffffffffffff0,%rdx
 10bf6be:	31 c9                	xor    %ecx,%ecx
 10bf6c0:	48 8b b4 8d 78 ea ff 	mov    -0x1588(%rbp,%rcx,4),%rsi
 10bf6c7:	ff 
 10bf6c8:	48 8b bc 8d 80 ea ff 	mov    -0x1580(%rbp,%rcx,4),%rdi
 10bf6cf:	ff 
 10bf6d0:	48 89 bc 0d d8 4e ff 	mov    %rdi,-0xb128(%rbp,%rcx,1)
 10bf6d7:	ff 
 10bf6d8:	48 01 f7             	add    %rsi,%rdi
 10bf6db:	48 2b b4 8d 70 ea ff 	sub    -0x1590(%rbp,%rcx,4),%rsi
 10bf6e2:	ff 
 10bf6e3:	48 89 b4 0d 70 fa ff 	mov    %rsi,-0x590(%rbp,%rcx,1)
 10bf6ea:	ff 
 10bf6eb:	48 89 bc 0d d8 4e fd 	mov    %rdi,-0x2b128(%rbp,%rcx,1)
 10bf6f2:	ff 
 10bf6f3:	48 8b b4 8d 98 ea ff 	mov    -0x1568(%rbp,%rcx,4),%rsi
 10bf6fa:	ff 
 10bf6fb:	48 8b bc 8d a0 ea ff 	mov    -0x1560(%rbp,%rcx,4),%rdi
 10bf702:	ff 
 10bf703:	48 89 bc 0d e0 4e ff 	mov    %rdi,-0xb120(%rbp,%rcx,1)
 10bf70a:	ff 
 10bf70b:	48 01 f7             	add    %rsi,%rdi
 10bf70e:	48 2b b4 8d 90 ea ff 	sub    -0x1570(%rbp,%rcx,4),%rsi
 10bf715:	ff 
 10bf716:	48 89 b4 0d 78 fa ff 	mov    %rsi,-0x588(%rbp,%rcx,1)
 10bf71d:	ff 
 10bf71e:	48 89 bc 0d e0 4e fd 	mov    %rdi,-0x2b120(%rbp,%rcx,1)
 10bf725:	ff 
 10bf726:	48 83 c1 10          	add    $0x10,%rcx
 10bf72a:	48 39 ca             	cmp    %rcx,%rdx
 10bf72d:	75 91                	jne    10bf6c0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x7f0>
 10bf72f:	a8 01                	test   $0x1,%al
 10bf731:	74 33                	je     10bf766 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x896>
 10bf733:	48 8b 94 8d 78 ea ff 	mov    -0x1588(%rbp,%rcx,4),%rdx
 10bf73a:	ff 
 10bf73b:	48 8b b4 8d 80 ea ff 	mov    -0x1580(%rbp,%rcx,4),%rsi
 10bf742:	ff 
 10bf743:	48 89 b4 0d d8 4e ff 	mov    %rsi,-0xb128(%rbp,%rcx,1)
 10bf74a:	ff 
 10bf74b:	48 01 d6             	add    %rdx,%rsi
 10bf74e:	48 2b 94 8d 70 ea ff 	sub    -0x1590(%rbp,%rcx,4),%rdx
 10bf755:	ff 
 10bf756:	48 89 94 0d 70 fa ff 	mov    %rdx,-0x590(%rbp,%rcx,1)
 10bf75d:	ff 
 10bf75e:	48 89 b4 0d d8 4e fd 	mov    %rsi,-0x2b128(%rbp,%rcx,1)
 10bf765:	ff 
 10bf766:	4c 8d 95 d8 4e fd ff 	lea    -0x2b128(%rbp),%r10
 10bf76d:	48 8d bd 08 ff ff ff 	lea    -0xf8(%rbp),%rdi
 10bf774:	4c 8d 8d 70 e6 ff ff 	lea    -0x1990(%rbp),%r9
 10bf77b:	4c 89 fe             	mov    %r15,%rsi
 10bf77e:	4c 89 f2             	mov    %r14,%rdx
 10bf781:	4c 89 e9             	mov    %r13,%rcx
 10bf784:	4d 89 e0             	mov    %r12,%r8
 10bf787:	41 53                	push   %r11
 10bf789:	50                   	push   %rax
 10bf78a:	41 52                	push   %r10
 10bf78c:	50                   	push   %rax
 10bf78d:	4c 8d 95 d8 4e ff ff 	lea    -0xb128(%rbp),%r10
 10bf794:	41 52                	push   %r10
 10bf796:	50                   	push   %rax
 10bf797:	4c 8d 95 70 fa ff ff 	lea    -0x590(%rbp),%r10
 10bf79e:	41 52                	push   %r10
 10bf7a0:	50                   	push   %rax
 10bf7a1:	c5 f8 77             	vzeroupper 
 10bf7a4:	e8 97 00 00 00       	call   10bf840 <zstd.emitBestSequenceCompressedBlock>
 10bf7a9:	48 83 c4 40          	add    $0x40,%rsp
 10bf7ad:	0f b7 8d 08 ff ff ff 	movzwl -0xf8(%rbp),%ecx
 10bf7b4:	66 85 c9             	test   %cx,%cx
 10bf7b7:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10bf7bb:	75 0c                	jne    10bf7c9 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x8f9>
 10bf7bd:	0f b6 8d 0a ff ff ff 	movzbl -0xf6(%rbp),%ecx
 10bf7c4:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 10bf7c7:	31 c9                	xor    %ecx,%ecx
 10bf7c9:	41 89 cd             	mov    %ecx,%r13d
 10bf7cc:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10bf7d3:	00 
 10bf7d4:	74 4e                	je     10bf824 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x954>
 10bf7d6:	4c 8b a5 68 ff ff ff 	mov    -0x98(%rbp),%r12
 10bf7dd:	4c 89 e7             	mov    %r12,%rdi
 10bf7e0:	48 89 c6             	mov    %rax,%rsi
 10bf7e3:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 10bf7ea:	b9 02 00 00 00       	mov    $0x2,%ecx
 10bf7ef:	4c 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%r15
 10bf7f6:	4d 89 f8             	mov    %r15,%r8
 10bf7f9:	4c 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%r14
 10bf800:	c5 f8 77             	vzeroupper 
 10bf803:	41 ff 56 18          	call   *0x18(%r14)
 10bf807:	4c 89 e7             	mov    %r12,%rdi
 10bf80a:	48 8b b5 38 ff ff ff 	mov    -0xc8(%rbp),%rsi
 10bf811:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 10bf818:	b9 01 00 00 00       	mov    $0x1,%ecx
 10bf81d:	4d 89 f8             	mov    %r15,%r8
 10bf820:	41 ff 56 18          	call   *0x18(%r14)
 10bf824:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 10bf828:	66 44 89 2b          	mov    %r13w,(%rbx)
 10bf82c:	88 43 02             	mov    %al,0x2(%rbx)
 10bf82f:	e9 65 f8 ff ff       	jmp    10bf099 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x1c9>

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_dense_huffman:
