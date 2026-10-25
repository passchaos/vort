 1091de0:	44 09 c7             	or     %r8d,%edi
 1091de3:	69 ff bd a7 35 1e    	imul   $0x1e35a7bd,%edi,%edi
 1091de9:	0f b7 f6             	movzwl %si,%esi
 1091dec:	4d 8b 45 00          	mov    0x0(%r13),%r8
 1091df0:	4d 8b 4d 10          	mov    0x10(%r13),%r9
 1091df4:	c1 ef 11             	shr    $0x11,%edi
 1091df7:	45 8b 04 b8          	mov    (%r8,%rdi,4),%r8d
 1091dfb:	45 89 04 b1          	mov    %r8d,(%r9,%rsi,4)
 1091dff:	49 8b 75 00          	mov    0x0(%r13),%rsi
 1091e03:	45 8d 04 17          	lea    (%r15,%rdx,1),%r8d
 1091e07:	44 89 04 be          	mov    %r8d,(%rsi,%rdi,4)
 1091e0b:	48 ff c2             	inc    %rdx
 1091e0e:	48 39 d0             	cmp    %rdx,%rax
 1091e11:	0f 84 69 fe ff ff    	je     1091c80 <deflate64.stream_blocks.fixedPlan+0x140>
