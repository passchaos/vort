 1091ae3:	4c 89 f7             	mov    %r14,%rdi
 1091ae6:	4d 89 e3             	mov    %r12,%r11
 1091ae9:	4d 39 c4             	cmp    %r8,%r12
 1091aec:	73 34                	jae    1091b22 <deflate64.stream_match.Matcher.find+0x1b2>
 1091aee:	41 0f b7 df          	movzwl %r15w,%ebx
 1091af2:	4c 8b 76 10          	mov    0x10(%rsi),%r14
 1091af6:	45 8b 3c 9e          	mov    (%r14,%rbx,4),%r15d
 1091afa:	41 83 ff ff          	cmp    $0xffffffff,%r15d
 1091afe:	74 14                	je     1091b14 <deflate64.stream_match.Matcher.find+0x1a4>
 1091b00:	49 ff c2             	inc    %r10
 1091b03:	49 89 fe             	mov    %rdi,%r14
 1091b06:	4d 89 dc             	mov    %r11,%r12
 1091b09:	49 39 ca             	cmp    %rcx,%r10
 1091b0c:	0f 82 3e ff ff ff    	jb     1091a50 <deflate64.stream_match.Matcher.find+0xe0>
 1091b12:	eb 0e                	jmp    1091b22 <deflate64.stream_match.Matcher.find+0x1b2>
