 1174a00:	55                   	push   %rbp
 1174a01:	48 89 e5             	mov    %rsp,%rbp
 1174a04:	41 57                	push   %r15
 1174a06:	41 56                	push   %r14
 1174a08:	41 55                	push   %r13
 1174a0a:	41 54                	push   %r12
 1174a0c:	53                   	push   %rbx
 1174a0d:	48 83 ec 78          	sub    $0x78,%rsp
 1174a11:	49 89 ff             	mov    %rdi,%r15
 1174a14:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1174a18:	48 8b 80 08 02 00 00 	mov    0x208(%rax),%rax
 1174a1f:	48 01 c8             	add    %rcx,%rax
 1174a22:	73 0c                	jae    1174a30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307+0x30>
 1174a24:	66 41 c7 47 10 4f 00 	movw   $0x4f,0x10(%r15)
 1174a2b:	e9 f4 00 00 00       	jmp    1174b24 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307+0x124>
 1174a30:	49 89 f2             	mov    %rsi,%r10
 1174a33:	48 89 c8             	mov    %rcx,%rax
 1174a36:	48 c1 e8 03          	shr    $0x3,%rax
 1174a3a:	48 83 f8 41          	cmp    $0x41,%rax
 1174a3e:	be 40 00 00 00       	mov    $0x40,%esi
 1174a43:	48 0f 43 f0          	cmovae %rax,%rsi
 1174a47:	48 81 fe 00 10 00 00 	cmp    $0x1000,%rsi
 1174a4e:	41 bc 00 10 00 00    	mov    $0x1000,%r12d
 1174a54:	4c 0f 42 e6          	cmovb  %rsi,%r12
 1174a58:	31 c0                	xor    %eax,%eax
 1174a5a:	84 c0                	test   %al,%al
 1174a5c:	0f 85 bb 00 00 00    	jne    1174b1d <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307+0x11d>
 1174a62:	49 8b 3a             	mov    (%r10),%rdi
 1174a65:	49 8b 42 08          	mov    0x8(%r10),%rax
 1174a69:	4c 8b 5d 08          	mov    0x8(%rbp),%r11
 1174a6d:	4c 89 e6             	mov    %r12,%rsi
 1174a70:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 1174a74:	31 d2                	xor    %edx,%edx
 1174a76:	49 89 cd             	mov    %rcx,%r13
 1174a79:	4c 89 5d c0          	mov    %r11,-0x40(%rbp)
 1174a7d:	4c 89 d9             	mov    %r11,%rcx
 1174a80:	4c 89 cb             	mov    %r9,%rbx
 1174a83:	4c 89 55 a0          	mov    %r10,-0x60(%rbp)
 1174a87:	4d 89 c6             	mov    %r8,%r14
 1174a8a:	ff 10                	call   *(%rax)
 1174a8c:	4c 8b 5d 18          	mov    0x18(%rbp),%r11
 1174a90:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 1174a94:	4d 89 f0             	mov    %r14,%r8
 1174a97:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 1174a9b:	48 85 c0             	test   %rax,%rax
 1174a9e:	74 7d                	je     1174b1d <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307+0x11d>
 1174aa0:	49 89 d9             	mov    %rbx,%r9
 1174aa3:	4c 8b 55 10          	mov    0x10(%rbp),%r10
 1174aa7:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 1174aab:	48 c7 45 b0 00 00 00 	movq   $0x0,-0x50(%rbp)
 1174ab2:	00 
 1174ab3:	4c 89 65 b8          	mov    %r12,-0x48(%rbp)
 1174ab7:	c6 45 d0 00          	movb   $0x0,-0x30(%rbp)
 1174abb:	c6 45 cf 00          	movb   $0x0,-0x31(%rbp)
 1174abf:	48 8d 45 a8          	lea    -0x58(%rbp),%rax
 1174ac3:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 1174ac7:	66 c7 45 90 00 00    	movw   $0x0,-0x70(%rbp)
 1174acd:	48 8d 75 88          	lea    -0x78(%rbp),%rsi
 1174ad1:	4c 89 f7             	mov    %r14,%rdi
 1174ad4:	4c 89 e9             	mov    %r13,%rcx
 1174ad7:	41 53                	push   %r11
 1174ad9:	41 52                	push   %r10
 1174adb:	e8 c0 48 00 00       	call   11793a0 <br.encodeCommandPlanWithOptionsWrite>
 1174ae0:	48 83 c4 10          	add    $0x10,%rsp
 1174ae4:	66 85 c0             	test   %ax,%ax
 1174ae7:	75 4a                	jne    1174b33 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307+0x133>
 1174ae9:	48 8d bd 70 ff ff ff 	lea    -0x90(%rbp),%rdi
 1174af0:	48 8d 75 a8          	lea    -0x58(%rbp),%rsi
 1174af4:	4c 89 f2             	mov    %r14,%rdx
 1174af7:	e8 74 00 00 00       	call   1174b70 <array_list.Aligned(u8,null).toOwnedSlice>
 1174afc:	44 0f b7 65 80       	movzwl -0x80(%rbp),%r12d
 1174b01:	66 45 85 e4          	test   %r12w,%r12w
 1174b05:	75 53                	jne    1174b5a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307+0x15a>
