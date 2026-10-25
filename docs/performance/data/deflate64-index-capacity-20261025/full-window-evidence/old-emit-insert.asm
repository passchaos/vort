 10917be:	09 fe                	or     %edi,%esi
 10917c0:	69 f6 bd a7 35 1e    	imul   $0x1e35a7bd,%esi,%esi
 10917c6:	0f b7 d2             	movzwl %dx,%edx
 10917c9:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 10917cd:	4d 8b 45 10          	mov    0x10(%r13),%r8
 10917d1:	c1 ee 11             	shr    $0x11,%esi
 10917d4:	8b 3c b7             	mov    (%rdi,%rsi,4),%edi
 10917d7:	41 89 3c 90          	mov    %edi,(%r8,%rdx,4)
 10917db:	49 8b 55 00          	mov    0x0(%r13),%rdx
 10917df:	41 8d 3c 0f          	lea    (%r15,%rcx,1),%edi
 10917e3:	89 3c b2             	mov    %edi,(%rdx,%rsi,4)
 10917e6:	48 ff c1             	inc    %rcx
 10917e9:	48 39 c8             	cmp    %rcx,%rax
 10917ec:	0f 84 0e fc ff ff    	je     1091400 <deflate64.stream_blocks.writeFixed+0x1a0>
