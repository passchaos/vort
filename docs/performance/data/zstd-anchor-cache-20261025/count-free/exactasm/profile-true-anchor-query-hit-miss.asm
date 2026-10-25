 1064b29:	4d 29 d4             	sub    %r10,%r12
 1064b2c:	49 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%r15
 1064b33:	45 31 ed             	xor    %r13d,%r13d
 1064b36:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 1064b3d:	4c 89 f7             	mov    %r14,%rdi
 1064b40:	45 31 f6             	xor    %r14d,%r14d
 1064b43:	4c 89 8d 38 ff ff ff 	mov    %r9,-0xc8(%rbp)
 1064b4a:	4c 89 9d 40 ff ff ff 	mov    %r11,-0xc0(%rbp)
 1064b51:	eb 2b                	jmp    1064b7e <multi_duplicate_profile.main+0x3ffe>
 1064b53:	43 8d 0c 2a          	lea    (%r10,%r13,1),%ecx
 1064b57:	89 8c 85 60 3b fd ff 	mov    %ecx,-0x2c4a0(%rbp,%rax,4)
 1064b5e:	c6 84 05 60 3b ff ff 	movb   $0x1,-0xc4a0(%rbp,%rax,1)
 1064b65:	01 
 1064b66:	4c 89 f8             	mov    %r15,%rax
 1064b69:	49 ff c5             	inc    %r13
 1064b6c:	49 ff cc             	dec    %r12
 1064b6f:	4c 89 c9             	mov    %r9,%rcx
 1064b72:	49 89 c7             	mov    %rax,%r15
 1064b75:	4c 01 e9             	add    %r13,%rcx
 1064b78:	0f 84 40 03 00 00    	je     1064ebe <multi_duplicate_profile.main+0x433e>
 1064b7e:	45 84 f6             	test   %r14b,%r14b
 1064b81:	74 09                	je     1064b8c <multi_duplicate_profile.main+0x400c>
 1064b83:	49 39 d4             	cmp    %rdx,%r12
 1064b86:	0f 82 22 03 00 00    	jb     1064eae <multi_duplicate_profile.main+0x432e>
 1064b8c:	48 ff c7             	inc    %rdi
 1064b8f:	48 0f 44 fe          	cmove  %rsi,%rdi
 1064b93:	43 0f b7 04 6b       	movzwl (%r11,%r13,2),%eax
 1064b98:	80 bc 05 60 3b ff ff 	cmpb   $0x0,-0xc4a0(%rbp,%rax,1)
 1064b9f:	00 
 1064ba0:	74 b1                	je     1064b53 <multi_duplicate_profile.main+0x3fd3>
 1064ba2:	8b 9c 85 60 3b fd ff 	mov    -0x2c4a0(%rbp,%rax,4),%ebx
 1064ba9:	c6 84 05 60 3b ff ff 	movb   $0x0,-0xc4a0(%rbp,%rax,1)
 1064bb0:	00 
 1064bb1:	49 39 da             	cmp    %rbx,%r10
 1064bb4:	77 b0                	ja     1064b66 <multi_duplicate_profile.main+0x3fe6>
 1064bb6:	4c 89 75 98          	mov    %r14,-0x68(%rbp)
 1064bba:	4b 8d 0c 2a          	lea    (%r10,%r13,1),%rcx
 1064bbe:	49 89 ce             	mov    %rcx,%r14
 1064bc1:	49 29 de             	sub    %rbx,%r14
 1064bc4:	0f 86 d3 00 00 00    	jbe    1064c9d <multi_duplicate_profile.main+0x411d>
 1064bca:	80 7d 98 00          	cmpb   $0x0,-0x68(%rbp)
 1064bce:	74 0d                	je     1064bdd <multi_duplicate_profile.main+0x405d>
 1064bd0:	49 39 d4             	cmp    %rdx,%r12
 1064bd3:	77 08                	ja     1064bdd <multi_duplicate_profile.main+0x405d>
 1064bd5:	4c 89 f8             	mov    %r15,%rax
 1064bd8:	41 b6 01             	mov    $0x1,%r14b
 1064bdb:	eb 8c                	jmp    1064b69 <multi_duplicate_profile.main+0x3fe9>
 1064bdd:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 1064be1:	46 8b 04 a8          	mov    (%rax,%r13,4),%r8d
 1064be5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
 1064bea:	49 39 c0             	cmp    %rax,%r8
 1064bed:	74 1d                	je     1064c0c <multi_duplicate_profile.main+0x408c>
 1064bef:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 1064bf6:	48 ff c0             	inc    %rax
 1064bf9:	48 0f 44 c6          	cmove  %rsi,%rax
 1064bfd:	48 89 85 80 fe ff ff 	mov    %rax,-0x180(%rbp)
 1064c04:	4c 89 c0             	mov    %r8,%rax
 1064c07:	e9 80 00 00 00       	jmp    1064c8c <multi_duplicate_profile.main+0x410c>
 1064c0c:	48 8b 85 20 fe ff ff 	mov    -0x1e0(%rbp),%rax
 1064c13:	48 ff c0             	inc    %rax
 1064c16:	48 0f 44 c6          	cmove  %rsi,%rax
 1064c1a:	48 89 85 20 fe ff ff 	mov    %rax,-0x1e0(%rbp)
 1064c21:	48 89 bd 10 ff ff ff 	mov    %rdi,-0xf0(%rbp)
 1064c28:	48 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%rdi
 1064c2f:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 1064c36:	48 89 95 68 ff ff ff 	mov    %rdx,-0x98(%rbp)
 1064c3d:	48 89 da             	mov    %rbx,%rdx
 1064c40:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 1064c47:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 1064c4e:	e8 0d 1c 09 00       	call   10f6860 <zstd.duplicateMatchLength>
 1064c53:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 1064c5a:	4c 8b 9d 40 ff ff ff 	mov    -0xc0(%rbp),%r11
 1064c61:	4c 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%r9
 1064c68:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 1064c6f:	4c 8b 95 88 fe ff ff 	mov    -0x178(%rbp),%r10
 1064c76:	48 8b bd 10 ff ff ff 	mov    -0xf0(%rbp),%rdi
 1064c7d:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 1064c84:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 1064c88:	43 89 04 a8          	mov    %eax,(%r8,%r13,4)
