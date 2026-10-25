 114ac7f:	49 83 fc 09          	cmp    $0x9,%r12
 114ac83:	0f 82 5e ff ff ff    	jb     114abe7 <quality_stage_profile.main+0x3227>
 114ac89:	be d8 44 02 00       	mov    $0x244d8,%esi
 114ac8e:	4c 89 ef             	mov    %r13,%rdi
 114ac91:	ba 03 00 00 00       	mov    $0x3,%edx
 114ac96:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 114ac9a:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 114ac9e:	41 ff 14 24          	call   *(%r12)
 114aca2:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 114aca9:	48 85 c0             	test   %rax,%rax
 114acac:	0f 84 dd 1b 00 00    	je     114c88f <quality_stage_profile.main+0x4ecf>
