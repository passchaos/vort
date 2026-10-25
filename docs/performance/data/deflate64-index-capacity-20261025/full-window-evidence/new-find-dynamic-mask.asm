 1091a73:	4c 89 f7             	mov    %r14,%rdi
 1091a76:	4d 89 e3             	mov    %r12,%r11
 1091a79:	4d 39 c4             	cmp    %r8,%r12
 1091a7c:	73 38                	jae    1091ab6 <deflate64.stream_match.Matcher.find+0x1b6>
 1091a7e:	8b 5e 18             	mov    0x18(%rsi),%ebx
 1091a81:	ff cb                	dec    %ebx
 1091a83:	41 21 df             	and    %ebx,%r15d
 1091a86:	48 8b 5e 10          	mov    0x10(%rsi),%rbx
 1091a8a:	46 8b 3c bb          	mov    (%rbx,%r15,4),%r15d
 1091a8e:	41 83 ff ff          	cmp    $0xffffffff,%r15d
 1091a92:	74 14                	je     1091aa8 <deflate64.stream_match.Matcher.find+0x1a8>
 1091a94:	49 ff c2             	inc    %r10
 1091a97:	49 89 fe             	mov    %rdi,%r14
 1091a9a:	4d 89 dc             	mov    %r11,%r12
 1091a9d:	49 39 ca             	cmp    %rcx,%r10
 1091aa0:	0f 82 3a ff ff ff    	jb     10919e0 <deflate64.stream_match.Matcher.find+0xe0>
 1091aa6:	eb 0e                	jmp    1091ab6 <deflate64.stream_match.Matcher.find+0x1b6>
