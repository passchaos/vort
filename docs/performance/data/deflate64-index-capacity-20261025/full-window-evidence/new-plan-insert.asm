 1091d7c:	41 0f b6 3a          	movzbl (%r10),%edi
 1091d80:	44 09 c7             	or     %r8d,%edi
 1091d83:	69 ff bd a7 35 1e    	imul   $0x1e35a7bd,%edi,%edi
 1091d89:	4d 8b 45 18          	mov    0x18(%r13),%r8
 1091d8d:	49 01 d8             	add    %rbx,%r8
 1091d90:	49 21 f0             	and    %rsi,%r8
 1091d93:	49 8b 75 00          	mov    0x0(%r13),%rsi
 1091d97:	4d 8b 4d 10          	mov    0x10(%r13),%r9
 1091d9b:	c1 ef 11             	shr    $0x11,%edi
 1091d9e:	8b 34 be             	mov    (%rsi,%rdi,4),%esi
 1091da1:	43 89 34 81          	mov    %esi,(%r9,%r8,4)
 1091da5:	49 8b 75 00          	mov    0x0(%r13),%rsi
 1091da9:	45 8d 04 17          	lea    (%r15,%rdx,1),%r8d
 1091dad:	44 89 04 be          	mov    %r8d,(%rsi,%rdi,4)
 1091db1:	48 ff c2             	inc    %rdx
 1091db4:	48 39 d0             	cmp    %rdx,%rax
 1091db7:	0f 84 63 fe ff ff    	je     1091c20 <deflate64.stream_blocks.fixedPlan+0x150>
