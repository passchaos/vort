 109173a:	41 0f b6 31          	movzbl (%r9),%esi
 109173e:	09 fe                	or     %edi,%esi
 1091740:	69 f6 bd a7 35 1e    	imul   $0x1e35a7bd,%esi,%esi
 1091746:	49 8b 7d 18          	mov    0x18(%r13),%rdi
 109174a:	4c 01 f7             	add    %r14,%rdi
 109174d:	48 21 d7             	and    %rdx,%rdi
 1091750:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091754:	4d 8b 45 10          	mov    0x10(%r13),%r8
 1091758:	c1 ee 11             	shr    $0x11,%esi
 109175b:	8b 14 b2             	mov    (%rdx,%rsi,4),%edx
 109175e:	41 89 14 b8          	mov    %edx,(%r8,%rdi,4)
 1091762:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091766:	41 8d 3c 0f          	lea    (%r15,%rcx,1),%edi
 109176a:	89 3c b2             	mov    %edi,(%rdx,%rsi,4)
 109176d:	48 ff c1             	inc    %rcx
 1091770:	48 39 c8             	cmp    %rcx,%rax
 1091773:	0f 84 f7 fb ff ff    	je     1091370 <deflate64.stream_blocks.writeFixed+0x1b0>
