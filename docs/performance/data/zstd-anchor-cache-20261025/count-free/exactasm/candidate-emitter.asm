
/tmp/vort-zstd-anchor-cache-20261025/count-free/anchor-count-free:     file format elf64-x86-64


Disassembly of section .text:

00000000010bf840 <zstd.emitBestSequenceCompressedBlock>:
 10bf840:	55                   	push   %rbp
 10bf841:	48 89 e5             	mov    %rsp,%rbp
 10bf844:	41 57                	push   %r15
 10bf846:	41 56                	push   %r14
 10bf848:	41 55                	push   %r13
 10bf84a:	41 54                	push   %r12
 10bf84c:	53                   	push   %rbx
 10bf84d:	48 81 ec 58 25 00 00 	sub    $0x2558,%rsp
 10bf854:	48 89 8d 18 ff ff ff 	mov    %rcx,-0xe8(%rbp)
 10bf85b:	48 89 bd 28 fe ff ff 	mov    %rdi,-0x1d8(%rbp)
 10bf862:	48 8b 7d 48          	mov    0x48(%rbp),%rdi
 10bf866:	48 8b 45 10          	mov    0x10(%rbp),%rax
 10bf86a:	c5 f8 10 05 d6 04 f5 	vmovups -0xafb2a(%rip),%xmm0        # 100fd48 <__anon_3065>
 10bf871:	ff 
 10bf872:	c5 f8 29 85 d0 fe ff 	vmovaps %xmm0,-0x130(%rbp)
 10bf879:	ff 
 10bf87a:	48 3b 45 40          	cmp    0x40(%rbp),%rax
 10bf87e:	48 c7 85 e0 fe ff ff 	movq   $0x0,-0x120(%rbp)
 10bf885:	00 00 00 00 
 10bf889:	0f 95 c0             	setne  %al
 10bf88c:	4d 89 c2             	mov    %r8,%r10
 10bf88f:	49 29 fa             	sub    %rdi,%r10
 10bf892:	0f 92 c1             	setb   %cl
 10bf895:	08 c1                	or     %al,%cl
 10bf897:	66 b9 3b 00          	mov    $0x3b,%cx
 10bf89b:	0f 85 a1 01 00 00    	jne    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bf8a1:	48 89 f8             	mov    %rdi,%rax
 10bf8a4:	b1 01                	mov    $0x1,%cl
 10bf8a6:	31 ff                	xor    %edi,%edi
 10bf8a8:	45 31 db             	xor    %r11d,%r11d
 10bf8ab:	4c 89 95 20 ff ff ff 	mov    %r10,-0xe0(%rbp)
 10bf8b2:	4d 89 d4             	mov    %r10,%r12
 10bf8b5:	45 31 ff             	xor    %r15d,%r15d
 10bf8b8:	45 31 d2             	xor    %r10d,%r10d
 10bf8bb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 10bf8c0:	4d 8b 34 f9          	mov    (%r9,%rdi,8),%r14
 10bf8c4:	4c 89 c3             	mov    %r8,%rbx
 10bf8c7:	4c 29 db             	sub    %r11,%rbx
 10bf8ca:	49 39 de             	cmp    %rbx,%r14
 10bf8cd:	0f 87 65 01 00 00    	ja     10bfa38 <zstd.emitBestSequenceCompressedBlock+0x1f8>
 10bf8d3:	4d 89 e5             	mov    %r12,%r13
 10bf8d6:	4c 89 e3             	mov    %r12,%rbx
 10bf8d9:	4c 01 f3             	add    %r14,%rbx
 10bf8dc:	0f 92 85 b0 ed ff ff 	setb   -0x1250(%rbp)
 10bf8e3:	0f 82 55 01 00 00    	jb     10bfa3e <zstd.emitBestSequenceCompressedBlock+0x1fe>
 10bf8e9:	48 89 5d 98          	mov    %rbx,-0x68(%rbp)
 10bf8ed:	4d 85 f6             	test   %r14,%r14
 10bf8f0:	0f 94 c3             	sete   %bl
 10bf8f3:	41 89 cc             	mov    %ecx,%r12d
 10bf8f6:	41 f6 d4             	not    %r12b
 10bf8f9:	41 08 dc             	or     %bl,%r12b
 10bf8fc:	41 f6 c4 01          	test   $0x1,%r12b
 10bf900:	74 0e                	je     10bf910 <zstd.emitBestSequenceCompressedBlock+0xd0>
 10bf902:	20 d9                	and    %bl,%cl
 10bf904:	eb 5c                	jmp    10bf962 <zstd.emitBestSequenceCompressedBlock+0x122>
 10bf906:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 10bf90d:	00 00 00 
 10bf910:	48 8b 9d 18 ff ff ff 	mov    -0xe8(%rbp),%rbx
 10bf917:	4c 01 db             	add    %r11,%rbx
 10bf91a:	41 f6 c2 01          	test   $0x1,%r10b
 10bf91e:	74 10                	je     10bf930 <zstd.emitBestSequenceCompressedBlock+0xf0>
 10bf920:	45 31 e4             	xor    %r12d,%r12d
 10bf923:	eb 1b                	jmp    10bf940 <zstd.emitBestSequenceCompressedBlock+0x100>
 10bf925:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 10bf92c:	00 00 00 00 
 10bf930:	44 0f b6 3b          	movzbl (%rbx),%r15d
 10bf934:	45 31 e4             	xor    %r12d,%r12d
 10bf937:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 10bf93e:	00 00 
 10bf940:	41 b2 01             	mov    $0x1,%r10b
 10bf943:	46 38 3c 23          	cmp    %r15b,(%rbx,%r12,1)
 10bf947:	75 17                	jne    10bf960 <zstd.emitBestSequenceCompressedBlock+0x120>
 10bf949:	49 ff c4             	inc    %r12
 10bf94c:	4d 39 e6             	cmp    %r12,%r14
 10bf94f:	75 ef                	jne    10bf940 <zstd.emitBestSequenceCompressedBlock+0x100>
 10bf951:	eb 0f                	jmp    10bf962 <zstd.emitBestSequenceCompressedBlock+0x122>
 10bf953:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10bf95a:	84 00 00 00 00 00 
 10bf960:	31 c9                	xor    %ecx,%ecx
 10bf962:	48 8b 5d 38          	mov    0x38(%rbp),%rbx
 10bf966:	48 8b 1c fb          	mov    (%rbx,%rdi,8),%rbx
 10bf96a:	4d 01 f3             	add    %r14,%r11
 10bf96d:	4c 39 db             	cmp    %r11,%rbx
 10bf970:	4c 8b 65 98          	mov    -0x68(%rbp),%r12
 10bf974:	0f 82 be 00 00 00    	jb     10bfa38 <zstd.emitBestSequenceCompressedBlock+0x1f8>
 10bf97a:	4c 39 c3             	cmp    %r8,%rbx
 10bf97d:	0f 87 b5 00 00 00    	ja     10bfa38 <zstd.emitBestSequenceCompressedBlock+0x1f8>
 10bf983:	48 ff c7             	inc    %rdi
 10bf986:	49 89 db             	mov    %rbx,%r11
 10bf989:	48 3b 7d 10          	cmp    0x10(%rbp),%rdi
 10bf98d:	0f 85 2d ff ff ff    	jne    10bf8c0 <zstd.emitBestSequenceCompressedBlock+0x80>
 10bf993:	48 8b 5d 48          	mov    0x48(%rbp),%rbx
 10bf997:	48 03 9d 18 ff ff ff 	add    -0xe8(%rbp),%rbx
 10bf99e:	4c 8b 9d 20 ff ff ff 	mov    -0xe0(%rbp),%r11
 10bf9a5:	4d 85 db             	test   %r11,%r11
 10bf9a8:	40 0f 94 c7          	sete   %dil
 10bf9ac:	40 20 cf             	and    %cl,%dil
 10bf9af:	4d 85 db             	test   %r11,%r11
 10bf9b2:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 10bf9b6:	4c 89 8d e8 fe ff ff 	mov    %r9,-0x118(%rbp)
 10bf9bd:	4c 89 85 08 ff ff ff 	mov    %r8,-0xf8(%rbp)
 10bf9c4:	74 3e                	je     10bfa04 <zstd.emitBestSequenceCompressedBlock+0x1c4>
 10bf9c6:	41 89 cb             	mov    %ecx,%r11d
 10bf9c9:	41 80 f3 01          	xor    $0x1,%r11b
 10bf9cd:	41 f6 c3 01          	test   $0x1,%r11b
 10bf9d1:	75 31                	jne    10bfa04 <zstd.emitBestSequenceCompressedBlock+0x1c4>
 10bf9d3:	41 f6 c2 01          	test   $0x1,%r10b
 10bf9d7:	75 04                	jne    10bf9dd <zstd.emitBestSequenceCompressedBlock+0x19d>
 10bf9d9:	44 0f b6 3b          	movzbl (%rbx),%r15d
 10bf9dd:	48 8b bd 18 ff ff ff 	mov    -0xe8(%rbp),%rdi
 10bf9e4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 10bf9eb:	00 00 00 00 00 
 10bf9f0:	44 38 3c 07          	cmp    %r15b,(%rdi,%rax,1)
 10bf9f4:	0f 85 8f 00 00 00    	jne    10bfa89 <zstd.emitBestSequenceCompressedBlock+0x249>
 10bf9fa:	48 ff c0             	inc    %rax
 10bf9fd:	49 39 c0             	cmp    %rax,%r8
 10bfa00:	75 ee                	jne    10bf9f0 <zstd.emitBestSequenceCompressedBlock+0x1b0>
 10bfa02:	89 cf                	mov    %ecx,%edi
 10bfa04:	4d 85 e4             	test   %r12,%r12
 10bfa07:	0f 95 c0             	setne  %al
 10bfa0a:	40 20 f8             	and    %dil,%al
 10bfa0d:	3c 01                	cmp    $0x1,%al
 10bfa0f:	75 78                	jne    10bfa89 <zstd.emitBestSequenceCompressedBlock+0x249>
 10bfa11:	66 b9 3e 00          	mov    $0x3e,%cx
 10bfa15:	49 81 fc ff ff 0f 00 	cmp    $0xfffff,%r12
 10bfa1c:	77 24                	ja     10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bfa1e:	49 83 fc 20          	cmp    $0x20,%r12
 10bfa22:	0f 83 4c 03 00 00    	jae    10bfd74 <zstd.emitBestSequenceCompressedBlock+0x534>
 10bfa28:	46 8d 24 e5 00 00 00 	lea    0x0(,%r12,8),%r12d
 10bfa2f:	00 
 10bfa30:	41 fe c4             	inc    %r12b
 10bfa33:	e9 c1 03 00 00       	jmp    10bfdf9 <zstd.emitBestSequenceCompressedBlock+0x5b9>
 10bfa38:	66 b9 3b 00          	mov    $0x3b,%cx
 10bfa3c:	eb 04                	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bfa3e:	66 b9 3e 00          	mov    $0x3e,%cx
 10bfa42:	48 8b 95 e0 fe ff ff 	mov    -0x120(%rbp),%rdx
 10bfa49:	48 85 d2             	test   %rdx,%rdx
 10bfa4c:	74 1f                	je     10bfa6d <zstd.emitBestSequenceCompressedBlock+0x22d>
 10bfa4e:	48 8b 85 d0 fe ff ff 	mov    -0x130(%rbp),%rax
 10bfa55:	48 8b 3e             	mov    (%rsi),%rdi
 10bfa58:	4c 8b 4e 08          	mov    0x8(%rsi),%r9
 10bfa5c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 10bfa60:	48 89 c6             	mov    %rax,%rsi
 10bfa63:	89 cb                	mov    %ecx,%ebx
 10bfa65:	31 c9                	xor    %ecx,%ecx
 10bfa67:	41 ff 51 18          	call   *0x18(%r9)
 10bfa6b:	89 d9                	mov    %ebx,%ecx
 10bfa6d:	48 8b 85 28 fe ff ff 	mov    -0x1d8(%rbp),%rax
 10bfa74:	66 89 08             	mov    %cx,(%rax)
 10bfa77:	48 81 c4 58 25 00 00 	add    $0x2558,%rsp
 10bfa7e:	5b                   	pop    %rbx
 10bfa7f:	41 5c                	pop    %r12
 10bfa81:	41 5d                	pop    %r13
 10bfa83:	41 5e                	pop    %r14
 10bfa85:	41 5f                	pop    %r15
 10bfa87:	5d                   	pop    %rbp
 10bfa88:	c3                   	ret    
 10bfa89:	48 89 9d 68 fe ff ff 	mov    %rbx,-0x198(%rbp)
 10bfa90:	bb c2 ff 03 01       	mov    $0x103ffc2,%ebx
 10bfa95:	49 83 fc 40          	cmp    $0x40,%r12
 10bfa99:	73 34                	jae    10bfacf <zstd.emitBestSequenceCompressedBlock+0x28f>
 10bfa9b:	f6 03 01             	testb  $0x1,(%rbx)
 10bfa9e:	0f 85 d1 09 00 00    	jne    10c0475 <zstd.emitBestSequenceCompressedBlock+0xc35>
 10bfaa4:	66 b9 3e 00          	mov    $0x3e,%cx
 10bfaa8:	49 81 fc ff ff 0f 00 	cmp    $0xfffff,%r12
 10bfaaf:	77 91                	ja     10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bfab1:	49 83 fc 20          	cmp    $0x20,%r12
 10bfab5:	48 89 95 f0 fe ff ff 	mov    %rdx,-0x110(%rbp)
 10bfabc:	0f 83 e0 03 00 00    	jae    10bfea2 <zstd.emitBestSequenceCompressedBlock+0x662>
 10bfac2:	46 8d 24 e5 00 00 00 	lea    0x0(,%r12,8),%r12d
 10bfac9:	00 
 10bfaca:	e9 61 04 00 00       	jmp    10bff30 <zstd.emitBestSequenceCompressedBlock+0x6f0>
 10bfacf:	66 b9 1a 00          	mov    $0x1a,%cx
 10bfad3:	31 c0                	xor    %eax,%eax
 10bfad5:	84 c0                	test   %al,%al
 10bfad7:	0f 85 65 ff ff ff    	jne    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bfadd:	48 89 95 f0 fe ff ff 	mov    %rdx,-0x110(%rbp)
 10bfae4:	48 8b 3e             	mov    (%rsi),%rdi
 10bfae7:	48 8b 46 08          	mov    0x8(%rsi),%rax
 10bfaeb:	4c 89 e6             	mov    %r12,%rsi
 10bfaee:	48 d1 ee             	shr    %rsi
 10bfaf1:	48 83 ee 80          	sub    $0xffffffffffffff80,%rsi
 10bfaf5:	4c 01 e6             	add    %r12,%rsi
 10bfaf8:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 10bfaff:	48 0f 42 f1          	cmovb  %rcx,%rsi
 10bfb03:	4c 8b 7d 08          	mov    0x8(%rbp),%r15
 10bfb07:	48 89 f3             	mov    %rsi,%rbx
 10bfb0a:	31 d2                	xor    %edx,%edx
 10bfb0c:	4c 89 f9             	mov    %r15,%rcx
 10bfb0f:	ff 10                	call   *(%rax)
 10bfb11:	66 b9 1a 00          	mov    $0x1a,%cx
 10bfb15:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bfb19:	48 85 c0             	test   %rax,%rax
 10bfb1c:	0f 84 20 ff ff ff    	je     10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bfb22:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 10bfb26:	4c 89 7d c8          	mov    %r15,-0x38(%rbp)
 10bfb2a:	45 31 ff             	xor    %r15d,%r15d
 10bfb2d:	45 31 c9             	xor    %r9d,%r9d
 10bfb30:	45 31 c0             	xor    %r8d,%r8d
 10bfb33:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 10bfb3a:	48 89 da             	mov    %rbx,%rdx
 10bfb3d:	48 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%rcx
 10bfb44:	4a 8b 1c c9          	mov    (%rcx,%r9,8),%rbx
 10bfb48:	4c 29 c0             	sub    %r8,%rax
 10bfb4b:	66 b9 3b 00          	mov    $0x3b,%cx
 10bfb4f:	48 39 c3             	cmp    %rax,%rbx
 10bfb52:	0f 87 a0 0a 00 00    	ja     10c05f8 <zstd.emitBestSequenceCompressedBlock+0xdb8>
 10bfb58:	4d 89 fc             	mov    %r15,%r12
 10bfb5b:	49 01 dc             	add    %rbx,%r12
 10bfb5e:	0f 92 85 b0 ed ff ff 	setb   -0x1250(%rbp)
 10bfb65:	0f 92 c0             	setb   %al
 10bfb68:	0f 92 85 a0 e4 ff ff 	setb   -0x1b60(%rbp)
 10bfb6f:	84 c0                	test   %al,%al
 10bfb71:	0f 85 61 03 00 00    	jne    10bfed8 <zstd.emitBestSequenceCompressedBlock+0x698>
 10bfb77:	4c 39 e2             	cmp    %r12,%rdx
 10bfb7a:	4c 89 4d 90          	mov    %r9,-0x70(%rbp)
 10bfb7e:	73 43                	jae    10bfbc3 <zstd.emitBestSequenceCompressedBlock+0x383>
 10bfb80:	4d 89 e2             	mov    %r12,%r10
 10bfb83:	49 d1 ea             	shr    %r10
 10bfb86:	49 83 ea 80          	sub    $0xffffffffffffff80,%r10
 10bfb8a:	4d 01 e2             	add    %r12,%r10
 10bfb8d:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10bfb94:	4c 0f 42 d0          	cmovb  %rax,%r10
 10bfb98:	48 8b 3e             	mov    (%rsi),%rdi
 10bfb9b:	4c 8b 5e 08          	mov    0x8(%rsi),%r11
 10bfb9f:	48 85 d2             	test   %rdx,%rdx
 10bfba2:	74 06                	je     10bfbaa <zstd.emitBestSequenceCompressedBlock+0x36a>
 10bfba4:	31 c0                	xor    %eax,%eax
 10bfba6:	84 c0                	test   %al,%al
 10bfba8:	74 26                	je     10bfbd0 <zstd.emitBestSequenceCompressedBlock+0x390>
 10bfbaa:	31 c0                	xor    %eax,%eax
 10bfbac:	31 c9                	xor    %ecx,%ecx
 10bfbae:	48 85 c0             	test   %rax,%rax
 10bfbb1:	0f 84 9b 00 00 00    	je     10bfc52 <zstd.emitBestSequenceCompressedBlock+0x412>
 10bfbb7:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 10bfbbb:	48 89 c1             	mov    %rax,%rcx
 10bfbbe:	e9 09 01 00 00       	jmp    10bfccc <zstd.emitBestSequenceCompressedBlock+0x48c>
 10bfbc3:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 10bfbc7:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 10bfbcb:	e9 fc 00 00 00       	jmp    10bfccc <zstd.emitBestSequenceCompressedBlock+0x48c>
 10bfbd0:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 10bfbd4:	4c 89 85 10 ff ff ff 	mov    %r8,-0xf0(%rbp)
 10bfbdb:	4c 89 65 b0          	mov    %r12,-0x50(%rbp)
 10bfbdf:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 10bfbe3:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10bfbe7:	49 89 d4             	mov    %rdx,%r12
 10bfbea:	31 c9                	xor    %ecx,%ecx
 10bfbec:	4d 89 d0             	mov    %r10,%r8
 10bfbef:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10bfbf3:	4c 89 55 a0          	mov    %r10,-0x60(%rbp)
 10bfbf7:	4c 89 5d 88          	mov    %r11,-0x78(%rbp)
 10bfbfb:	41 ff 53 10          	call   *0x10(%r11)
 10bfbff:	48 85 c0             	test   %rax,%rax
 10bfc02:	74 1f                	je     10bfc23 <zstd.emitBestSequenceCompressedBlock+0x3e3>
 10bfc04:	4c 8b 55 a0          	mov    -0x60(%rbp),%r10
 10bfc08:	4c 89 d1             	mov    %r10,%rcx
 10bfc0b:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bfc0f:	4c 89 e2             	mov    %r12,%rdx
 10bfc12:	4c 8b 65 b0          	mov    -0x50(%rbp),%r12
 10bfc16:	4c 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%r8
 10bfc1d:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 10bfc21:	eb 1e                	jmp    10bfc41 <zstd.emitBestSequenceCompressedBlock+0x401>
 10bfc23:	31 c0                	xor    %eax,%eax
 10bfc25:	31 c9                	xor    %ecx,%ecx
 10bfc27:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bfc2b:	4c 89 e2             	mov    %r12,%rdx
 10bfc2e:	4c 8b 65 b0          	mov    -0x50(%rbp),%r12
 10bfc32:	4c 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%r8
 10bfc39:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 10bfc3d:	4c 8b 55 a0          	mov    -0x60(%rbp),%r10
 10bfc41:	4c 8b 5d 88          	mov    -0x78(%rbp),%r11
 10bfc45:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 10bfc49:	48 85 c0             	test   %rax,%rax
 10bfc4c:	0f 85 65 ff ff ff    	jne    10bfbb7 <zstd.emitBestSequenceCompressedBlock+0x377>
 10bfc52:	31 c0                	xor    %eax,%eax
 10bfc54:	84 c0                	test   %al,%al
 10bfc56:	0f 85 7c 02 00 00    	jne    10bfed8 <zstd.emitBestSequenceCompressedBlock+0x698>
 10bfc5c:	4c 89 85 10 ff ff ff 	mov    %r8,-0xf0(%rbp)
 10bfc63:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 10bfc67:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 10bfc6b:	4c 89 55 a0          	mov    %r10,-0x60(%rbp)
 10bfc6f:	4c 89 d6             	mov    %r10,%rsi
 10bfc72:	31 d2                	xor    %edx,%edx
 10bfc74:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10bfc78:	4c 89 5d 88          	mov    %r11,-0x78(%rbp)
 10bfc7c:	41 ff 13             	call   *(%r11)
 10bfc7f:	48 85 c0             	test   %rax,%rax
 10bfc82:	0f 84 64 09 00 00    	je     10c05ec <zstd.emitBestSequenceCompressedBlock+0xdac>
 10bfc88:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 10bfc8c:	48 89 c7             	mov    %rax,%rdi
 10bfc8f:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10bfc93:	4c 89 fa             	mov    %r15,%rdx
 10bfc96:	e8 25 d8 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10bfc9b:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 10bfc9f:	48 85 d2             	test   %rdx,%rdx
 10bfca2:	74 15                	je     10bfcb9 <zstd.emitBestSequenceCompressedBlock+0x479>
 10bfca4:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 10bfca8:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10bfcac:	31 c9                	xor    %ecx,%ecx
 10bfcae:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10bfcb2:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 10bfcb6:	ff 50 18             	call   *0x18(%rax)
 10bfcb9:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 10bfcbd:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 10bfcc1:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 10bfcc5:	4c 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%r8
 10bfccc:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 10bfcd3:	4a 8d 34 00          	lea    (%rax,%r8,1),%rsi
 10bfcd7:	48 89 4d a8          	mov    %rcx,-0x58(%rbp)
 10bfcdb:	49 01 cf             	add    %rcx,%r15
 10bfcde:	4c 89 ff             	mov    %r15,%rdi
 10bfce1:	48 89 da             	mov    %rbx,%rdx
 10bfce4:	4d 89 c7             	mov    %r8,%r15
 10bfce7:	e8 d4 d7 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10bfcec:	48 8b 45 38          	mov    0x38(%rbp),%rax
 10bfcf0:	4c 8b 4d 90          	mov    -0x70(%rbp),%r9
 10bfcf4:	4a 8b 0c c8          	mov    (%rax,%r9,8),%rcx
 10bfcf8:	4c 01 fb             	add    %r15,%rbx
 10bfcfb:	48 39 d9             	cmp    %rbx,%rcx
 10bfcfe:	0f 82 bb 04 00 00    	jb     10c01bf <zstd.emitBestSequenceCompressedBlock+0x97f>
 10bfd04:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 10bfd0b:	48 39 c1             	cmp    %rax,%rcx
 10bfd0e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bfd12:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 10bfd16:	0f 87 b0 04 00 00    	ja     10c01cc <zstd.emitBestSequenceCompressedBlock+0x98c>
 10bfd1c:	49 ff c1             	inc    %r9
 10bfd1f:	4d 89 e7             	mov    %r12,%r15
 10bfd22:	49 89 c8             	mov    %rcx,%r8
 10bfd25:	4c 39 4d 10          	cmp    %r9,0x10(%rbp)
 10bfd29:	0f 85 0e fe ff ff    	jne    10bfb3d <zstd.emitBestSequenceCompressedBlock+0x2fd>
 10bfd2f:	4c 89 e7             	mov    %r12,%rdi
 10bfd32:	49 89 d2             	mov    %rdx,%r10
 10bfd35:	4d 89 e7             	mov    %r12,%r15
 10bfd38:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 10bfd3f:	49 01 d7             	add    %rdx,%r15
 10bfd42:	0f 92 85 b0 ed ff ff 	setb   -0x1250(%rbp)
 10bfd49:	0f 92 c0             	setb   %al
 10bfd4c:	0f 92 85 a0 e4 ff ff 	setb   -0x1b60(%rbp)
 10bfd53:	84 c0                	test   %al,%al
 10bfd55:	0f 84 3d 06 00 00    	je     10c0398 <zstd.emitBestSequenceCompressedBlock+0xb58>
 10bfd5b:	66 b9 1a 00          	mov    $0x1a,%cx
 10bfd5f:	4c 89 d2             	mov    %r10,%rdx
 10bfd62:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10bfd66:	48 85 d2             	test   %rdx,%rdx
 10bfd69:	0f 85 96 08 00 00    	jne    10c0605 <zstd.emitBestSequenceCompressedBlock+0xdc5>
 10bfd6f:	e9 ce fc ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bfd74:	48 89 d3             	mov    %rdx,%rbx
 10bfd77:	44 89 e0             	mov    %r12d,%eax
 10bfd7a:	c0 e0 04             	shl    $0x4,%al
 10bfd7d:	49 81 fc 00 10 00 00 	cmp    $0x1000,%r12
 10bfd84:	73 20                	jae    10bfda6 <zstd.emitBestSequenceCompressedBlock+0x566>
 10bfd86:	0c 05                	or     $0x5,%al
 10bfd88:	0f b6 d0             	movzbl %al,%edx
 10bfd8b:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10bfd92:	e8 89 64 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10bfd97:	66 85 c0             	test   %ax,%ax
 10bfd9a:	0f 85 47 26 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10bfda0:	41 c1 ec 04          	shr    $0x4,%r12d
 10bfda4:	eb 3e                	jmp    10bfde4 <zstd.emitBestSequenceCompressedBlock+0x5a4>
 10bfda6:	0c 0d                	or     $0xd,%al
 10bfda8:	0f b6 d0             	movzbl %al,%edx
 10bfdab:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10bfdb2:	e8 69 64 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10bfdb7:	66 85 c0             	test   %ax,%ax
 10bfdba:	0f 85 27 26 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10bfdc0:	4c 89 e2             	mov    %r12,%rdx
 10bfdc3:	48 c1 ea 04          	shr    $0x4,%rdx
 10bfdc7:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10bfdce:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bfdd2:	e8 49 64 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10bfdd7:	66 85 c0             	test   %ax,%ax
 10bfdda:	0f 85 07 26 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10bfde0:	41 c1 ec 0c          	shr    $0xc,%r12d
 10bfde4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bfde8:	4c 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%r9
 10bfdef:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 10bfdf6:	48 89 da             	mov    %rbx,%rdx
 10bfdf9:	4c 8b 95 d0 fe ff ff 	mov    -0x130(%rbp),%r10
 10bfe00:	4c 8b b5 d8 fe ff ff 	mov    -0x128(%rbp),%r14
 10bfe07:	48 8b 8d e0 fe ff ff 	mov    -0x120(%rbp),%rcx
 10bfe0e:	4d 8d 6e 01          	lea    0x1(%r14),%r13
 10bfe12:	4c 39 f1             	cmp    %r14,%rcx
 10bfe15:	0f 87 15 04 00 00    	ja     10c0230 <zstd.emitBestSequenceCompressedBlock+0x9f0>
 10bfe1b:	4c 89 e8             	mov    %r13,%rax
 10bfe1e:	48 d1 e8             	shr    %rax
 10bfe21:	48 83 e8 80          	sub    $0xffffffffffffff80,%rax
 10bfe25:	4c 01 e8             	add    %r13,%rax
 10bfe28:	49 c7 c3 ff ff ff ff 	mov    $0xffffffffffffffff,%r11
 10bfe2f:	4c 0f 43 d8          	cmovae %rax,%r11
 10bfe33:	48 8b 3e             	mov    (%rsi),%rdi
 10bfe36:	48 8b 46 08          	mov    0x8(%rsi),%rax
 10bfe3a:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 10bfe3e:	31 db                	xor    %ebx,%ebx
 10bfe40:	48 85 c9             	test   %rcx,%rcx
 10bfe43:	0f 84 88 00 00 00    	je     10bfed1 <zstd.emitBestSequenceCompressedBlock+0x691>
 10bfe49:	b8 00 00 00 00       	mov    $0x0,%eax
 10bfe4e:	84 db                	test   %bl,%bl
 10bfe50:	0f 85 c0 03 00 00    	jne    10c0216 <zstd.emitBestSequenceCompressedBlock+0x9d6>
 10bfe56:	4c 89 6d a8          	mov    %r13,-0x58(%rbp)
 10bfe5a:	48 89 95 f0 fe ff ff 	mov    %rdx,-0x110(%rbp)
 10bfe61:	4c 8b 4d 08          	mov    0x8(%rbp),%r9
 10bfe65:	31 db                	xor    %ebx,%ebx
 10bfe67:	48 89 bd 18 ff ff ff 	mov    %rdi,-0xe8(%rbp)
 10bfe6e:	4c 89 55 b8          	mov    %r10,-0x48(%rbp)
 10bfe72:	4c 89 d6             	mov    %r10,%rsi
 10bfe75:	48 89 8d 20 ff ff ff 	mov    %rcx,-0xe0(%rbp)
 10bfe7c:	48 89 ca             	mov    %rcx,%rdx
 10bfe7f:	31 c9                	xor    %ecx,%ecx
 10bfe81:	4d 89 d8             	mov    %r11,%r8
 10bfe84:	4d 89 dd             	mov    %r11,%r13
 10bfe87:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10bfe8b:	ff 50 10             	call   *0x10(%rax)
 10bfe8e:	48 85 c0             	test   %rax,%rax
 10bfe91:	0f 84 4b 03 00 00    	je     10c01e2 <zstd.emitBestSequenceCompressedBlock+0x9a2>
 10bfe97:	48 89 c3             	mov    %rax,%rbx
 10bfe9a:	4c 89 e8             	mov    %r13,%rax
 10bfe9d:	e9 42 03 00 00       	jmp    10c01e4 <zstd.emitBestSequenceCompressedBlock+0x9a4>
 10bfea2:	44 89 e0             	mov    %r12d,%eax
 10bfea5:	c0 e0 04             	shl    $0x4,%al
 10bfea8:	49 81 fc 00 10 00 00 	cmp    $0x1000,%r12
 10bfeaf:	73 3d                	jae    10bfeee <zstd.emitBestSequenceCompressedBlock+0x6ae>
 10bfeb1:	0c 04                	or     $0x4,%al
 10bfeb3:	0f b6 d0             	movzbl %al,%edx
 10bfeb6:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10bfebd:	e8 5e 63 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10bfec2:	66 85 c0             	test   %ax,%ax
 10bfec5:	0f 85 1c 25 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10bfecb:	41 c1 ec 04          	shr    $0x4,%r12d
 10bfecf:	eb 5b                	jmp    10bff2c <zstd.emitBestSequenceCompressedBlock+0x6ec>
 10bfed1:	31 c0                	xor    %eax,%eax
 10bfed3:	e9 3e 03 00 00       	jmp    10c0216 <zstd.emitBestSequenceCompressedBlock+0x9d6>
 10bfed8:	66 b9 1a 00          	mov    $0x1a,%cx
 10bfedc:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10bfee0:	48 85 d2             	test   %rdx,%rdx
 10bfee3:	0f 85 1c 07 00 00    	jne    10c0605 <zstd.emitBestSequenceCompressedBlock+0xdc5>
 10bfee9:	e9 54 fb ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10bfeee:	0c 0c                	or     $0xc,%al
 10bfef0:	0f b6 d0             	movzbl %al,%edx
 10bfef3:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10bfefa:	e8 21 63 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10bfeff:	66 85 c0             	test   %ax,%ax
 10bff02:	0f 85 df 24 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10bff08:	4c 89 e2             	mov    %r12,%rdx
 10bff0b:	48 c1 ea 04          	shr    $0x4,%rdx
 10bff0f:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10bff16:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bff1a:	e8 01 63 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10bff1f:	66 85 c0             	test   %ax,%ax
 10bff22:	0f 85 bf 24 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10bff28:	41 c1 ec 0c          	shr    $0xc,%r12d
 10bff2c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bff30:	41 0f b6 d4          	movzbl %r12b,%edx
 10bff34:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10bff3b:	e8 e0 62 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10bff40:	66 85 c0             	test   %ax,%ax
 10bff43:	0f 85 9e 24 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10bff49:	4c 8b 85 d0 fe ff ff 	mov    -0x130(%rbp),%r8
 10bff50:	48 8b bd d8 fe ff ff 	mov    -0x128(%rbp),%rdi
 10bff57:	48 8b 95 e0 fe ff ff 	mov    -0x120(%rbp),%rdx
 10bff5e:	31 db                	xor    %ebx,%ebx
 10bff60:	45 31 c9             	xor    %r9d,%r9d
 10bff63:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10bff67:	48 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%rcx
 10bff6e:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 10bff75:	4c 8b 3c d9          	mov    (%rcx,%rbx,8),%r15
 10bff79:	4c 29 c8             	sub    %r9,%rax
 10bff7c:	66 b9 3b 00          	mov    $0x3b,%cx
 10bff80:	49 39 c7             	cmp    %rax,%r15
 10bff83:	0f 87 39 06 00 00    	ja     10c05c2 <zstd.emitBestSequenceCompressedBlock+0xd82>
 10bff89:	49 89 fd             	mov    %rdi,%r13
 10bff8c:	4d 01 fd             	add    %r15,%r13
 10bff8f:	0f 92 85 b0 ed ff ff 	setb   -0x1250(%rbp)
 10bff96:	0f 92 c0             	setb   %al
 10bff99:	0f 92 85 a0 e4 ff ff 	setb   -0x1b60(%rbp)
 10bffa0:	84 c0                	test   %al,%al
 10bffa2:	0f 85 00 02 00 00    	jne    10c01a8 <zstd.emitBestSequenceCompressedBlock+0x968>
 10bffa8:	4c 39 ea             	cmp    %r13,%rdx
 10bffab:	73 43                	jae    10bfff0 <zstd.emitBestSequenceCompressedBlock+0x7b0>
 10bffad:	4c 89 45 b8          	mov    %r8,-0x48(%rbp)
 10bffb1:	4d 89 ec             	mov    %r13,%r12
 10bffb4:	49 d1 ec             	shr    %r12
 10bffb7:	49 83 ec 80          	sub    $0xffffffffffffff80,%r12
 10bffbb:	4d 01 ec             	add    %r13,%r12
 10bffbe:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10bffc5:	4c 0f 42 e0          	cmovb  %rax,%r12
 10bffc9:	4c 8b 06             	mov    (%rsi),%r8
 10bffcc:	4c 8b 56 08          	mov    0x8(%rsi),%r10
 10bffd0:	48 85 d2             	test   %rdx,%rdx
 10bffd3:	74 06                	je     10bffdb <zstd.emitBestSequenceCompressedBlock+0x79b>
 10bffd5:	31 c0                	xor    %eax,%eax
 10bffd7:	84 c0                	test   %al,%al
 10bffd9:	74 1e                	je     10bfff9 <zstd.emitBestSequenceCompressedBlock+0x7b9>
 10bffdb:	31 c0                	xor    %eax,%eax
 10bffdd:	31 c9                	xor    %ecx,%ecx
 10bffdf:	48 85 c0             	test   %rax,%rax
 10bffe2:	74 66                	je     10c004a <zstd.emitBestSequenceCompressedBlock+0x80a>
 10bffe4:	49 89 c0             	mov    %rax,%r8
 10bffe7:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 10bffeb:	e9 d9 00 00 00       	jmp    10c00c9 <zstd.emitBestSequenceCompressedBlock+0x889>
 10bfff0:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 10bfff4:	e9 d0 00 00 00       	jmp    10c00c9 <zstd.emitBestSequenceCompressedBlock+0x889>
 10bfff9:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 10bfffd:	4c 89 4d a8          	mov    %r9,-0x58(%rbp)
 10c0001:	4c 8b 4d 08          	mov    0x8(%rbp),%r9
 10c0005:	4c 89 45 90          	mov    %r8,-0x70(%rbp)
 10c0009:	4c 89 c7             	mov    %r8,%rdi
 10c000c:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c0010:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 10c0014:	31 c9                	xor    %ecx,%ecx
 10c0016:	4d 89 e0             	mov    %r12,%r8
 10c0019:	4d 89 d6             	mov    %r10,%r14
 10c001c:	41 ff 52 10          	call   *0x10(%r10)
 10c0020:	48 85 c0             	test   %rax,%rax
 10c0023:	74 05                	je     10c002a <zstd.emitBestSequenceCompressedBlock+0x7ea>
 10c0025:	4c 89 e1             	mov    %r12,%rcx
 10c0028:	eb 04                	jmp    10c002e <zstd.emitBestSequenceCompressedBlock+0x7ee>
 10c002a:	31 c0                	xor    %eax,%eax
 10c002c:	31 c9                	xor    %ecx,%ecx
 10c002e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0032:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 10c0036:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 10c003a:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 10c003e:	4d 89 f2             	mov    %r14,%r10
 10c0041:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 10c0045:	48 85 c0             	test   %rax,%rax
 10c0048:	75 9a                	jne    10bffe4 <zstd.emitBestSequenceCompressedBlock+0x7a4>
 10c004a:	31 c0                	xor    %eax,%eax
 10c004c:	84 c0                	test   %al,%al
 10c004e:	0f 85 ce 05 00 00    	jne    10c0622 <zstd.emitBestSequenceCompressedBlock+0xde2>
 10c0054:	49 89 fe             	mov    %rdi,%r14
 10c0057:	4c 89 4d a8          	mov    %r9,-0x58(%rbp)
 10c005b:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 10c005f:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 10c0063:	4c 89 45 90          	mov    %r8,-0x70(%rbp)
 10c0067:	4c 89 c7             	mov    %r8,%rdi
 10c006a:	4c 89 e6             	mov    %r12,%rsi
 10c006d:	31 d2                	xor    %edx,%edx
 10c006f:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 10c0073:	4c 89 95 10 ff ff ff 	mov    %r10,-0xf0(%rbp)
 10c007a:	41 ff 12             	call   *(%r10)
 10c007d:	48 85 c0             	test   %rax,%rax
 10c0080:	0f 84 a6 05 00 00    	je     10c062c <zstd.emitBestSequenceCompressedBlock+0xdec>
 10c0086:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 10c008a:	48 89 c7             	mov    %rax,%rdi
 10c008d:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c0091:	4c 89 f2             	mov    %r14,%rdx
 10c0094:	e8 27 d4 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c0099:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 10c009d:	48 85 d2             	test   %rdx,%rdx
 10c00a0:	74 18                	je     10c00ba <zstd.emitBestSequenceCompressedBlock+0x87a>
 10c00a2:	48 8b 7d 90          	mov    -0x70(%rbp),%rdi
 10c00a6:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c00aa:	31 c9                	xor    %ecx,%ecx
 10c00ac:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 10c00b0:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 10c00b7:	ff 50 18             	call   *0x18(%rax)
 10c00ba:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c00be:	4c 89 65 98          	mov    %r12,-0x68(%rbp)
 10c00c2:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 10c00c6:	4c 89 f7             	mov    %r14,%rdi
 10c00c9:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 10c00d0:	4a 8d 34 08          	lea    (%rax,%r9,1),%rsi
 10c00d4:	4d 89 c6             	mov    %r8,%r14
 10c00d7:	4c 01 c7             	add    %r8,%rdi
 10c00da:	4d 89 cc             	mov    %r9,%r12
 10c00dd:	4c 89 fa             	mov    %r15,%rdx
 10c00e0:	e8 db d3 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c00e5:	48 8b 45 38          	mov    0x38(%rbp),%rax
 10c00e9:	48 8b 0c d8          	mov    (%rax,%rbx,8),%rcx
 10c00ed:	4d 01 e7             	add    %r12,%r15
 10c00f0:	4c 39 f9             	cmp    %r15,%rcx
 10c00f3:	0f 82 ba 04 00 00    	jb     10c05b3 <zstd.emitBestSequenceCompressedBlock+0xd73>
 10c00f9:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 10c0100:	48 39 c1             	cmp    %rax,%rcx
 10c0103:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0107:	0f 87 aa 04 00 00    	ja     10c05b7 <zstd.emitBestSequenceCompressedBlock+0xd77>
 10c010d:	48 ff c3             	inc    %rbx
 10c0110:	4c 89 ef             	mov    %r13,%rdi
 10c0113:	49 89 c9             	mov    %rcx,%r9
 10c0116:	48 39 5d 10          	cmp    %rbx,0x10(%rbp)
 10c011a:	48 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%rcx
 10c0121:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 10c0125:	4d 89 f0             	mov    %r14,%r8
 10c0128:	0f 85 47 fe ff ff    	jne    10bff75 <zstd.emitBestSequenceCompressedBlock+0x735>
 10c012e:	4c 89 ad d8 fe ff ff 	mov    %r13,-0x128(%rbp)
 10c0135:	48 89 95 e0 fe ff ff 	mov    %rdx,-0x120(%rbp)
 10c013c:	4c 89 85 d0 fe ff ff 	mov    %r8,-0x130(%rbp)
 10c0143:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10c014a:	48 8b 9d 20 ff ff ff 	mov    -0xe0(%rbp),%rbx
 10c0151:	48 89 da             	mov    %rbx,%rdx
 10c0154:	e8 f7 81 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c0159:	66 85 c0             	test   %ax,%ax
 10c015c:	0f 85 85 22 00 00    	jne    10c23e7 <zstd.emitBestSequenceCompressedBlock+0x2ba7>
 10c0162:	48 8b bd d8 fe ff ff 	mov    -0x128(%rbp),%rdi
 10c0169:	48 8d 04 1f          	lea    (%rdi,%rbx,1),%rax
 10c016d:	48 89 85 d8 fe ff ff 	mov    %rax,-0x128(%rbp)
 10c0174:	48 03 bd d0 fe ff ff 	add    -0x130(%rbp),%rdi
 10c017b:	48 8b b5 68 fe ff ff 	mov    -0x198(%rbp),%rsi
 10c0182:	48 89 da             	mov    %rbx,%rdx
 10c0185:	e8 36 d3 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c018a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c018e:	4c 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%r9
 10c0195:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 10c019c:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 10c01a3:	e9 cd 02 00 00       	jmp    10c0475 <zstd.emitBestSequenceCompressedBlock+0xc35>
 10c01a8:	48 89 95 e0 fe ff ff 	mov    %rdx,-0x120(%rbp)
 10c01af:	4c 89 85 d0 fe ff ff 	mov    %r8,-0x130(%rbp)
 10c01b6:	66 b9 1a 00          	mov    $0x1a,%cx
 10c01ba:	e9 83 f8 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c01bf:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c01c3:	66 b9 3b 00          	mov    $0x3b,%cx
 10c01c7:	e9 28 04 00 00       	jmp    10c05f4 <zstd.emitBestSequenceCompressedBlock+0xdb4>
 10c01cc:	66 b9 3b 00          	mov    $0x3b,%cx
 10c01d0:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c01d4:	48 85 d2             	test   %rdx,%rdx
 10c01d7:	0f 85 28 04 00 00    	jne    10c0605 <zstd.emitBestSequenceCompressedBlock+0xdc5>
 10c01dd:	e9 60 f8 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c01e2:	31 c0                	xor    %eax,%eax
 10c01e4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c01e8:	4c 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%r9
 10c01ef:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 10c01f6:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 10c01fd:	4d 89 eb             	mov    %r13,%r11
 10c0200:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 10c0204:	4c 8b 55 b8          	mov    -0x48(%rbp),%r10
 10c0208:	48 8b bd 18 ff ff ff 	mov    -0xe8(%rbp),%rdi
 10c020f:	48 8b 8d 20 ff ff ff 	mov    -0xe0(%rbp),%rcx
 10c0216:	48 85 db             	test   %rbx,%rbx
 10c0219:	0f 84 be 00 00 00    	je     10c02dd <zstd.emitBestSequenceCompressedBlock+0xa9d>
 10c021f:	48 89 9d d0 fe ff ff 	mov    %rbx,-0x130(%rbp)
 10c0226:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 10c022d:	49 89 da             	mov    %rbx,%r10
 10c0230:	4c 89 ad d8 fe ff ff 	mov    %r13,-0x128(%rbp)
 10c0237:	47 88 24 32          	mov    %r12b,(%r10,%r14,1)
 10c023b:	4c 8b 95 d0 fe ff ff 	mov    -0x130(%rbp),%r10
 10c0242:	4c 8b b5 d8 fe ff ff 	mov    -0x128(%rbp),%r14
 10c0249:	4c 8b ad e0 fe ff ff 	mov    -0x120(%rbp),%r13
 10c0250:	4d 8d 5e 01          	lea    0x1(%r14),%r11
 10c0254:	4d 39 f5             	cmp    %r14,%r13
 10c0257:	0f 87 0d 02 00 00    	ja     10c046a <zstd.emitBestSequenceCompressedBlock+0xc2a>
 10c025d:	4c 89 d8             	mov    %r11,%rax
 10c0260:	48 d1 e8             	shr    %rax
 10c0263:	48 83 e8 80          	sub    $0xffffffffffffff80,%rax
 10c0267:	4c 01 d8             	add    %r11,%rax
 10c026a:	49 c7 c4 ff ff ff ff 	mov    $0xffffffffffffffff,%r12
 10c0271:	4c 0f 43 e0          	cmovae %rax,%r12
 10c0275:	48 8b 3e             	mov    (%rsi),%rdi
 10c0278:	48 8b 4e 08          	mov    0x8(%rsi),%rcx
 10c027c:	31 db                	xor    %ebx,%ebx
 10c027e:	4d 85 ed             	test   %r13,%r13
 10c0281:	0f 84 0a 01 00 00    	je     10c0391 <zstd.emitBestSequenceCompressedBlock+0xb51>
 10c0287:	b8 00 00 00 00       	mov    $0x0,%eax
 10c028c:	84 db                	test   %bl,%bl
 10c028e:	0f 85 b9 01 00 00    	jne    10c044d <zstd.emitBestSequenceCompressedBlock+0xc0d>
 10c0294:	4c 89 9d 20 ff ff ff 	mov    %r11,-0xe0(%rbp)
 10c029b:	48 89 95 f0 fe ff ff 	mov    %rdx,-0x110(%rbp)
 10c02a2:	4c 8b 4d 08          	mov    0x8(%rbp),%r9
 10c02a6:	31 db                	xor    %ebx,%ebx
 10c02a8:	48 89 7d 98          	mov    %rdi,-0x68(%rbp)
 10c02ac:	4c 89 95 18 ff ff ff 	mov    %r10,-0xe8(%rbp)
 10c02b3:	4c 89 d6             	mov    %r10,%rsi
 10c02b6:	4c 89 ea             	mov    %r13,%rdx
 10c02b9:	49 89 cb             	mov    %rcx,%r11
 10c02bc:	31 c9                	xor    %ecx,%ecx
 10c02be:	4d 89 e0             	mov    %r12,%r8
 10c02c1:	4c 89 5d b8          	mov    %r11,-0x48(%rbp)
 10c02c5:	41 ff 53 10          	call   *0x10(%r11)
 10c02c9:	48 85 c0             	test   %rax,%rax
 10c02cc:	0f 84 4a 01 00 00    	je     10c041c <zstd.emitBestSequenceCompressedBlock+0xbdc>
 10c02d2:	48 89 c3             	mov    %rax,%rbx
 10c02d5:	4c 89 e0             	mov    %r12,%rax
 10c02d8:	e9 41 01 00 00       	jmp    10c041e <zstd.emitBestSequenceCompressedBlock+0xbde>
 10c02dd:	48 89 8d 20 ff ff ff 	mov    %rcx,-0xe0(%rbp)
 10c02e4:	48 89 bd 18 ff ff ff 	mov    %rdi,-0xe8(%rbp)
 10c02eb:	66 b9 1a 00          	mov    $0x1a,%cx
 10c02ef:	31 c0                	xor    %eax,%eax
 10c02f1:	84 c0                	test   %al,%al
 10c02f3:	0f 85 49 f7 ff ff    	jne    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c02f9:	4c 89 55 b8          	mov    %r10,-0x48(%rbp)
 10c02fd:	4c 89 6d a8          	mov    %r13,-0x58(%rbp)
 10c0301:	4c 8b 6d 08          	mov    0x8(%rbp),%r13
 10c0305:	48 8b bd 18 ff ff ff 	mov    -0xe8(%rbp),%rdi
 10c030c:	4c 89 5d 90          	mov    %r11,-0x70(%rbp)
 10c0310:	4c 89 de             	mov    %r11,%rsi
 10c0313:	48 89 95 f0 fe ff ff 	mov    %rdx,-0x110(%rbp)
 10c031a:	31 d2                	xor    %edx,%edx
 10c031c:	4c 89 e9             	mov    %r13,%rcx
 10c031f:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10c0323:	ff 10                	call   *(%rax)
 10c0325:	66 b9 1a 00          	mov    $0x1a,%cx
 10c0329:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c032d:	48 85 c0             	test   %rax,%rax
 10c0330:	0f 84 0c f7 ff ff    	je     10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c0336:	48 89 c3             	mov    %rax,%rbx
 10c0339:	48 89 c7             	mov    %rax,%rdi
 10c033c:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c0340:	4c 89 f2             	mov    %r14,%rdx
 10c0343:	e8 78 d1 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c0348:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 10c034f:	48 85 d2             	test   %rdx,%rdx
 10c0352:	74 17                	je     10c036b <zstd.emitBestSequenceCompressedBlock+0xb2b>
 10c0354:	48 8b bd 18 ff ff ff 	mov    -0xe8(%rbp),%rdi
 10c035b:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c035f:	31 c9                	xor    %ecx,%ecx
 10c0361:	4d 89 e8             	mov    %r13,%r8
 10c0364:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10c0368:	ff 50 18             	call   *0x18(%rax)
 10c036b:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c036f:	4c 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%r9
 10c0376:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 10c037d:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 10c0384:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 10c0388:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 10c038c:	e9 8e fe ff ff       	jmp    10c021f <zstd.emitBestSequenceCompressedBlock+0x9df>
 10c0391:	31 c0                	xor    %eax,%eax
 10c0393:	e9 b5 00 00 00       	jmp    10c044d <zstd.emitBestSequenceCompressedBlock+0xc0d>
 10c0398:	4d 39 fa             	cmp    %r15,%r10
 10c039b:	0f 83 34 02 00 00    	jae    10c05d5 <zstd.emitBestSequenceCompressedBlock+0xd95>
 10c03a1:	4c 89 f8             	mov    %r15,%rax
 10c03a4:	48 d1 e8             	shr    %rax
 10c03a7:	48 83 e8 80          	sub    $0xffffffffffffff80,%rax
 10c03ab:	4c 01 f8             	add    %r15,%rax
 10c03ae:	49 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%r8
 10c03b5:	4c 0f 43 c0          	cmovae %rax,%r8
 10c03b9:	4c 8b 26             	mov    (%rsi),%r12
 10c03bc:	4c 8b 5e 08          	mov    0x8(%rsi),%r11
 10c03c0:	4d 85 d2             	test   %r10,%r10
 10c03c3:	4c 8b 8d 68 fe ff ff 	mov    -0x198(%rbp),%r9
 10c03ca:	0f 84 6e 02 00 00    	je     10c063e <zstd.emitBestSequenceCompressedBlock+0xdfe>
 10c03d0:	31 c9                	xor    %ecx,%ecx
 10c03d2:	b8 00 00 00 00       	mov    $0x0,%eax
 10c03d7:	84 c9                	test   %cl,%cl
 10c03d9:	0f 85 8d 02 00 00    	jne    10c066c <zstd.emitBestSequenceCompressedBlock+0xe2c>
 10c03df:	48 89 7d b0          	mov    %rdi,-0x50(%rbp)
 10c03e3:	4c 89 65 a0          	mov    %r12,-0x60(%rbp)
 10c03e7:	4c 89 e7             	mov    %r12,%rdi
 10c03ea:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10c03ee:	4c 89 d2             	mov    %r10,%rdx
 10c03f1:	31 c9                	xor    %ecx,%ecx
 10c03f3:	4c 89 c3             	mov    %r8,%rbx
 10c03f6:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c03fa:	4d 89 dc             	mov    %r11,%r12
 10c03fd:	41 ff 53 10          	call   *0x10(%r11)
 10c0401:	48 85 c0             	test   %rax,%rax
 10c0404:	0f 84 3a 02 00 00    	je     10c0644 <zstd.emitBestSequenceCompressedBlock+0xe04>
 10c040a:	48 89 c1             	mov    %rax,%rcx
 10c040d:	48 89 d8             	mov    %rbx,%rax
 10c0410:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0414:	49 89 d8             	mov    %rbx,%r8
 10c0417:	e9 33 02 00 00       	jmp    10c064f <zstd.emitBestSequenceCompressedBlock+0xe0f>
 10c041c:	31 c0                	xor    %eax,%eax
 10c041e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0422:	4c 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%r9
 10c0429:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 10c0430:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 10c0437:	4c 8b 9d 20 ff ff ff 	mov    -0xe0(%rbp),%r11
 10c043e:	4c 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%r10
 10c0445:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 10c0449:	48 8b 7d 98          	mov    -0x68(%rbp),%rdi
 10c044d:	48 85 db             	test   %rbx,%rbx
 10c0450:	0f 84 b0 00 00 00    	je     10c0506 <zstd.emitBestSequenceCompressedBlock+0xcc6>
 10c0456:	49 89 c4             	mov    %rax,%r12
 10c0459:	48 89 9d d0 fe ff ff 	mov    %rbx,-0x130(%rbp)
 10c0460:	4c 89 a5 e0 fe ff ff 	mov    %r12,-0x120(%rbp)
 10c0467:	49 89 da             	mov    %rbx,%r10
 10c046a:	4c 89 9d d8 fe ff ff 	mov    %r11,-0x128(%rbp)
 10c0471:	47 88 3c 32          	mov    %r15b,(%r10,%r14,1)
 10c0475:	48 8b 9d d0 fe ff ff 	mov    -0x130(%rbp),%rbx
 10c047c:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 10c0483:	48 8d bd 24 fe ff ff 	lea    -0x1dc(%rbp),%rdi
 10c048a:	4c 89 c1             	mov    %r8,%rcx
 10c048d:	49 89 d8             	mov    %rbx,%r8
 10c0490:	4d 89 ca             	mov    %r9,%r10
 10c0493:	49 89 c1             	mov    %rax,%r9
 10c0496:	ff 75 30             	push   0x30(%rbp)
 10c0499:	ff 75 28             	push   0x28(%rbp)
 10c049c:	ff 75 20             	push   0x20(%rbp)
 10c049f:	ff 75 18             	push   0x18(%rbp)
 10c04a2:	ff 75 10             	push   0x10(%rbp)
 10c04a5:	41 52                	push   %r10
 10c04a7:	e8 94 d3 03 00       	call   10fd840 <zstd.emitBestMultiSequenceCompressedBlockWinnerOnly>
 10c04ac:	48 83 c4 30          	add    $0x30,%rsp
 10c04b0:	44 0f b7 b5 24 fe ff 	movzwl -0x1dc(%rbp),%r14d
 10c04b7:	ff 
 10c04b8:	66 45 85 f6          	test   %r14w,%r14w
 10c04bc:	0f 85 f2 1e 00 00    	jne    10c23b4 <zstd.emitBestSequenceCompressedBlock+0x2b74>
 10c04c2:	44 0f b6 b5 26 fe ff 	movzbl -0x1da(%rbp),%r14d
 10c04c9:	ff 
 10c04ca:	48 8b 95 e0 fe ff ff 	mov    -0x120(%rbp),%rdx
 10c04d1:	48 85 d2             	test   %rdx,%rdx
 10c04d4:	74 17                	je     10c04ed <zstd.emitBestSequenceCompressedBlock+0xcad>
 10c04d6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c04da:	48 8b 38             	mov    (%rax),%rdi
 10c04dd:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c04e1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 10c04e5:	48 89 de             	mov    %rbx,%rsi
 10c04e8:	31 c9                	xor    %ecx,%ecx
 10c04ea:	ff 50 18             	call   *0x18(%rax)
 10c04ed:	48 8b 85 28 fe ff ff 	mov    -0x1d8(%rbp),%rax
 10c04f4:	66 c7 00 00 00       	movw   $0x0,(%rax)
 10c04f9:	41 80 e6 01          	and    $0x1,%r14b
 10c04fd:	44 88 70 02          	mov    %r14b,0x2(%rax)
 10c0501:	e9 71 f5 ff ff       	jmp    10bfa77 <zstd.emitBestSequenceCompressedBlock+0x237>
 10c0506:	49 89 c8             	mov    %rcx,%r8
 10c0509:	48 89 7d 98          	mov    %rdi,-0x68(%rbp)
 10c050d:	66 b9 1a 00          	mov    $0x1a,%cx
 10c0511:	31 c0                	xor    %eax,%eax
 10c0513:	84 c0                	test   %al,%al
 10c0515:	0f 85 27 f5 ff ff    	jne    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c051b:	4c 89 95 18 ff ff ff 	mov    %r10,-0xe8(%rbp)
 10c0522:	4c 89 9d 20 ff ff ff 	mov    %r11,-0xe0(%rbp)
 10c0529:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 10c052d:	48 8b 7d 98          	mov    -0x68(%rbp),%rdi
 10c0531:	4c 89 e6             	mov    %r12,%rsi
 10c0534:	48 89 95 f0 fe ff ff 	mov    %rdx,-0x110(%rbp)
 10c053b:	31 d2                	xor    %edx,%edx
 10c053d:	48 89 4d a8          	mov    %rcx,-0x58(%rbp)
 10c0541:	4c 89 45 b8          	mov    %r8,-0x48(%rbp)
 10c0545:	41 ff 10             	call   *(%r8)
 10c0548:	66 b9 1a 00          	mov    $0x1a,%cx
 10c054c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0550:	48 85 c0             	test   %rax,%rax
 10c0553:	0f 84 e9 f4 ff ff    	je     10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c0559:	48 89 c3             	mov    %rax,%rbx
 10c055c:	48 89 c7             	mov    %rax,%rdi
 10c055f:	48 8b b5 18 ff ff ff 	mov    -0xe8(%rbp),%rsi
 10c0566:	4c 89 f2             	mov    %r14,%rdx
 10c0569:	e8 52 cf 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c056e:	4d 85 ed             	test   %r13,%r13
 10c0571:	74 1b                	je     10c058e <zstd.emitBestSequenceCompressedBlock+0xd4e>
 10c0573:	48 8b 7d 98          	mov    -0x68(%rbp),%rdi
 10c0577:	48 8b b5 18 ff ff ff 	mov    -0xe8(%rbp),%rsi
 10c057e:	4c 89 ea             	mov    %r13,%rdx
 10c0581:	31 c9                	xor    %ecx,%ecx
 10c0583:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10c0587:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 10c058b:	ff 50 18             	call   *0x18(%rax)
 10c058e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0592:	4c 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%r9
 10c0599:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 10c05a0:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 10c05a7:	4c 8b 9d 20 ff ff ff 	mov    -0xe0(%rbp),%r11
 10c05ae:	e9 a6 fe ff ff       	jmp    10c0459 <zstd.emitBestSequenceCompressedBlock+0xc19>
 10c05b3:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c05b7:	66 b9 3b 00          	mov    $0x3b,%cx
 10c05bb:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 10c05bf:	4d 89 f0             	mov    %r14,%r8
 10c05c2:	48 89 95 e0 fe ff ff 	mov    %rdx,-0x120(%rbp)
 10c05c9:	4c 89 85 d0 fe ff ff 	mov    %r8,-0x130(%rbp)
 10c05d0:	e9 6d f4 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c05d5:	4c 89 95 10 ff ff ff 	mov    %r10,-0xf0(%rbp)
 10c05dc:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 10c05e0:	4c 8b 8d 68 fe ff ff 	mov    -0x198(%rbp),%r9
 10c05e7:	e9 90 00 00 00       	jmp    10c067c <zstd.emitBestSequenceCompressedBlock+0xe3c>
 10c05ec:	66 b9 1a 00          	mov    $0x1a,%cx
 10c05f0:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c05f4:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 10c05f8:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c05fc:	48 85 d2             	test   %rdx,%rdx
 10c05ff:	0f 84 3d f4 ff ff    	je     10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c0605:	48 8b 3e             	mov    (%rsi),%rdi
 10c0608:	48 8b 46 08          	mov    0x8(%rsi),%rax
 10c060c:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10c0610:	89 cb                	mov    %ecx,%ebx
 10c0612:	31 c9                	xor    %ecx,%ecx
 10c0614:	ff 50 18             	call   *0x18(%rax)
 10c0617:	89 d9                	mov    %ebx,%ecx
 10c0619:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c061d:	e9 20 f4 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c0622:	66 b9 1a 00          	mov    $0x1a,%cx
 10c0626:	4c 8b 45 b8          	mov    -0x48(%rbp),%r8
 10c062a:	eb 96                	jmp    10c05c2 <zstd.emitBestSequenceCompressedBlock+0xd82>
 10c062c:	66 b9 1a 00          	mov    $0x1a,%cx
 10c0630:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0634:	4c 8b 45 b8          	mov    -0x48(%rbp),%r8
 10c0638:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 10c063c:	eb 84                	jmp    10c05c2 <zstd.emitBestSequenceCompressedBlock+0xd82>
 10c063e:	31 c9                	xor    %ecx,%ecx
 10c0640:	31 c0                	xor    %eax,%eax
 10c0642:	eb 28                	jmp    10c066c <zstd.emitBestSequenceCompressedBlock+0xe2c>
 10c0644:	31 c0                	xor    %eax,%eax
 10c0646:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c064a:	49 89 d8             	mov    %rbx,%r8
 10c064d:	31 c9                	xor    %ecx,%ecx
 10c064f:	4c 8b 8d 68 fe ff ff 	mov    -0x198(%rbp),%r9
 10c0656:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 10c065d:	4c 8b 55 b8          	mov    -0x48(%rbp),%r10
 10c0661:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 10c0665:	4d 89 e3             	mov    %r12,%r11
 10c0668:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 10c066c:	48 85 c9             	test   %rcx,%rcx
 10c066f:	0f 84 8b 03 00 00    	je     10c0a00 <zstd.emitBestSequenceCompressedBlock+0x11c0>
 10c0675:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 10c067c:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 10c0680:	48 01 cf             	add    %rcx,%rdi
 10c0683:	4c 89 ce             	mov    %r9,%rsi
 10c0686:	e8 35 ce 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c068b:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10c068f:	49 39 c7             	cmp    %rax,%r15
 10c0692:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c0696:	0f 85 03 02 00 00    	jne    10c089f <zstd.emitBestSequenceCompressedBlock+0x105f>
 10c069c:	48 3d ff ff 03 00    	cmp    $0x3ffff,%rax
 10c06a2:	0f 87 08 03 00 00    	ja     10c09b0 <zstd.emitBestSequenceCompressedBlock+0x1170>
 10c06a8:	48 8d bd b0 ed ff ff 	lea    -0x1250(%rbp),%rdi
 10c06af:	31 db                	xor    %ebx,%ebx
 10c06b1:	ba 00 10 00 00       	mov    $0x1000,%edx
 10c06b6:	31 f6                	xor    %esi,%esi
 10c06b8:	e8 e3 c9 03 00       	call   10fd0a0 <compiler_rt.memset>
 10c06bd:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c06c1:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 10c06c5:	48 89 d8             	mov    %rbx,%rax
 10c06c8:	0f b6 0c 1e          	movzbl (%rsi,%rbx,1),%ecx
 10c06cc:	ff 84 8d b0 ed ff ff 	incl   -0x1250(%rbp,%rcx,4)
 10c06d3:	0f b6 4c 1e 01       	movzbl 0x1(%rsi,%rbx,1),%ecx
 10c06d8:	ff 84 8d b0 f1 ff ff 	incl   -0xe50(%rbp,%rcx,4)
 10c06df:	0f b6 4c 1e 02       	movzbl 0x2(%rsi,%rbx,1),%ecx
 10c06e4:	ff 84 8d b0 f5 ff ff 	incl   -0xa50(%rbp,%rcx,4)
 10c06eb:	0f b6 4c 1e 03       	movzbl 0x3(%rsi,%rbx,1),%ecx
 10c06f0:	ff 84 8d b0 f9 ff ff 	incl   -0x650(%rbp,%rcx,4)
 10c06f7:	48 83 c3 04          	add    $0x4,%rbx
 10c06fb:	48 83 c0 08          	add    $0x8,%rax
 10c06ff:	48 39 d0             	cmp    %rdx,%rax
 10c0702:	76 c1                	jbe    10c06c5 <zstd.emitBestSequenceCompressedBlock+0xe85>
 10c0704:	48 39 da             	cmp    %rbx,%rdx
 10c0707:	74 22                	je     10c072b <zstd.emitBestSequenceCompressedBlock+0xeeb>
 10c0709:	48 8d 43 fc          	lea    -0x4(%rbx),%rax
 10c070d:	4b 8d 0c 2e          	lea    (%r14,%r13,1),%rcx
 10c0711:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 10c0715:	0f b6 14 1e          	movzbl (%rsi,%rbx,1),%edx
 10c0719:	ff 84 95 b0 ed ff ff 	incl   -0x1250(%rbp,%rdx,4)
 10c0720:	48 ff c0             	inc    %rax
 10c0723:	48 ff c3             	inc    %rbx
 10c0726:	48 39 c1             	cmp    %rax,%rcx
 10c0729:	75 ea                	jne    10c0715 <zstd.emitBestSequenceCompressedBlock+0xed5>
 10c072b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 10c072f:	c5 fc 11 85 88 ea ff 	vmovups %ymm0,-0x1578(%rbp)
 10c0736:	ff 
 10c0737:	c5 fc 11 85 68 ea ff 	vmovups %ymm0,-0x1598(%rbp)
 10c073e:	ff 
 10c073f:	c5 fc 11 85 48 ea ff 	vmovups %ymm0,-0x15b8(%rbp)
 10c0746:	ff 
 10c0747:	c5 fc 11 85 28 ea ff 	vmovups %ymm0,-0x15d8(%rbp)
 10c074e:	ff 
 10c074f:	c5 fc 11 85 08 ea ff 	vmovups %ymm0,-0x15f8(%rbp)
 10c0756:	ff 
 10c0757:	c5 fc 11 85 e8 e9 ff 	vmovups %ymm0,-0x1618(%rbp)
 10c075e:	ff 
 10c075f:	c5 fc 11 85 c8 e9 ff 	vmovups %ymm0,-0x1638(%rbp)
 10c0766:	ff 
 10c0767:	c5 fc 11 85 a8 e9 ff 	vmovups %ymm0,-0x1658(%rbp)
 10c076e:	ff 
 10c076f:	c5 fc 11 85 88 e9 ff 	vmovups %ymm0,-0x1678(%rbp)
 10c0776:	ff 
 10c0777:	c5 fc 11 85 68 e9 ff 	vmovups %ymm0,-0x1698(%rbp)
 10c077e:	ff 
 10c077f:	c5 fc 11 85 48 e9 ff 	vmovups %ymm0,-0x16b8(%rbp)
 10c0786:	ff 
 10c0787:	c5 fc 11 85 28 e9 ff 	vmovups %ymm0,-0x16d8(%rbp)
 10c078e:	ff 
 10c078f:	c5 fc 11 85 08 e9 ff 	vmovups %ymm0,-0x16f8(%rbp)
 10c0796:	ff 
 10c0797:	c5 fc 11 85 e8 e8 ff 	vmovups %ymm0,-0x1718(%rbp)
 10c079e:	ff 
 10c079f:	c5 fc 11 85 c8 e8 ff 	vmovups %ymm0,-0x1738(%rbp)
 10c07a6:	ff 
 10c07a7:	c5 fc 11 85 a8 e8 ff 	vmovups %ymm0,-0x1758(%rbp)
 10c07ae:	ff 
 10c07af:	48 c7 85 a0 e4 ff ff 	movq   $0x0,-0x1b60(%rbp)
 10c07b6:	00 00 00 00 
 10c07ba:	c5 fc 11 85 a8 ec ff 	vmovups %ymm0,-0x1358(%rbp)
 10c07c1:	ff 
 10c07c2:	c5 fc 11 85 c8 ec ff 	vmovups %ymm0,-0x1338(%rbp)
 10c07c9:	ff 
 10c07ca:	c5 fc 11 85 e8 ec ff 	vmovups %ymm0,-0x1318(%rbp)
 10c07d1:	ff 
 10c07d2:	c5 fc 11 85 08 ed ff 	vmovups %ymm0,-0x12f8(%rbp)
 10c07d9:	ff 
 10c07da:	c5 fc 11 85 28 ed ff 	vmovups %ymm0,-0x12d8(%rbp)
 10c07e1:	ff 
 10c07e2:	c5 fc 11 85 48 ed ff 	vmovups %ymm0,-0x12b8(%rbp)
 10c07e9:	ff 
 10c07ea:	c5 fc 11 85 68 ed ff 	vmovups %ymm0,-0x1298(%rbp)
 10c07f1:	ff 
 10c07f2:	c5 fc 11 85 88 ed ff 	vmovups %ymm0,-0x1278(%rbp)
 10c07f9:	ff 
 10c07fa:	66 c7 85 a8 ed ff ff 	movw   $0x0,-0x1258(%rbp)
 10c0801:	00 00 
 10c0803:	31 c0                	xor    %eax,%eax
 10c0805:	31 c9                	xor    %ecx,%ecx
 10c0807:	48 8d b5 a0 e4 ff ff 	lea    -0x1b60(%rbp),%rsi
 10c080e:	eb 11                	jmp    10c0821 <zstd.emitBestSequenceCompressedBlock+0xfe1>
 10c0810:	48 83 c1 02          	add    $0x2,%rcx
 10c0814:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 10c081b:	0f 84 b2 00 00 00    	je     10c08d3 <zstd.emitBestSequenceCompressedBlock+0x1093>
 10c0821:	8b 94 8d b0 f1 ff ff 	mov    -0xe50(%rbp,%rcx,4),%edx
 10c0828:	03 94 8d b0 ed ff ff 	add    -0x1250(%rbp,%rcx,4),%edx
 10c082f:	03 94 8d b0 f5 ff ff 	add    -0xa50(%rbp,%rcx,4),%edx
 10c0836:	03 94 8d b0 f9 ff ff 	add    -0x650(%rbp,%rcx,4),%edx
 10c083d:	89 94 8d a8 e4 ff ff 	mov    %edx,-0x1b58(%rbp,%rcx,4)
 10c0844:	74 18                	je     10c085e <zstd.emitBestSequenceCompressedBlock+0x101e>
 10c0846:	88 8c 05 a8 ea ff ff 	mov    %cl,-0x1558(%rbp,%rax,1)
 10c084d:	48 8b 85 a0 e4 ff ff 	mov    -0x1b60(%rbp),%rax
 10c0854:	48 ff c0             	inc    %rax
 10c0857:	48 89 85 a0 e4 ff ff 	mov    %rax,-0x1b60(%rbp)
 10c085e:	8b 94 8d b4 f1 ff ff 	mov    -0xe4c(%rbp,%rcx,4),%edx
 10c0865:	03 94 8d b4 ed ff ff 	add    -0x124c(%rbp,%rcx,4),%edx
 10c086c:	03 94 8d b4 f5 ff ff 	add    -0xa4c(%rbp,%rcx,4),%edx
 10c0873:	03 94 8d b4 f9 ff ff 	add    -0x64c(%rbp,%rcx,4),%edx
 10c087a:	89 94 8d ac e4 ff ff 	mov    %edx,-0x1b54(%rbp,%rcx,4)
 10c0881:	74 8d                	je     10c0810 <zstd.emitBestSequenceCompressedBlock+0xfd0>
 10c0883:	8d 51 01             	lea    0x1(%rcx),%edx
 10c0886:	88 94 05 a8 ea ff ff 	mov    %dl,-0x1558(%rbp,%rax,1)
 10c088d:	48 8b 85 a0 e4 ff ff 	mov    -0x1b60(%rbp),%rax
 10c0894:	48 ff c0             	inc    %rax
 10c0897:	48 89 06             	mov    %rax,(%rsi)
 10c089a:	e9 71 ff ff ff       	jmp    10c0810 <zstd.emitBestSequenceCompressedBlock+0xfd0>
 10c089f:	66 b9 3b 00          	mov    $0x3b,%cx
 10c08a3:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 10c08aa:	48 85 d2             	test   %rdx,%rdx
 10c08ad:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c08b1:	0f 84 8b f1 ff ff    	je     10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c08b7:	48 8b 3e             	mov    (%rsi),%rdi
 10c08ba:	48 8b 46 08          	mov    0x8(%rsi),%rax
 10c08be:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c08c2:	31 c9                	xor    %ecx,%ecx
 10c08c4:	4d 89 e0             	mov    %r12,%r8
 10c08c7:	ff 50 18             	call   *0x18(%rax)
 10c08ca:	66 b9 3b 00          	mov    $0x3b,%cx
 10c08ce:	e9 46 fd ff ff       	jmp    10c0619 <zstd.emitBestSequenceCompressedBlock+0xdd9>
 10c08d3:	48 8d bd a0 e4 ff ff 	lea    -0x1b60(%rbp),%rdi
 10c08da:	c5 f8 77             	vzeroupper 
 10c08dd:	e8 be 87 00 00       	call   10c90a0 <zstd.finalizeSmallHuffmanLiteralPlan>
 10c08e2:	84 c0                	test   %al,%al
 10c08e4:	0f 84 c6 00 00 00    	je     10c09b0 <zstd.emitBestSequenceCompressedBlock+0x1170>
 10c08ea:	48 8d bd 90 db ff ff 	lea    -0x2470(%rbp),%rdi
 10c08f1:	48 8d b5 a0 e4 ff ff 	lea    -0x1b60(%rbp),%rsi
 10c08f8:	ba 10 09 00 00       	mov    $0x910,%edx
 10c08fd:	e8 be cb 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c0902:	c5 f8 10 05 3e f4 f4 	vmovups -0xb0bc2(%rip),%xmm0        # 100fd48 <__anon_3065>
 10c0909:	ff 
 10c090a:	c5 f8 29 85 30 fe ff 	vmovaps %xmm0,-0x1d0(%rbp)
 10c0911:	ff 
 10c0912:	48 c7 85 40 fe ff ff 	movq   $0x0,-0x1c0(%rbp)
 10c0919:	00 00 00 00 
 10c091d:	0f b6 9d 98 e4 ff ff 	movzbl -0x1b68(%rbp),%ebx
 10c0924:	48 81 fb 81 00 00 00 	cmp    $0x81,%rbx
 10c092b:	0f 83 f5 02 00 00    	jae    10c0c26 <zstd.emitBestSequenceCompressedBlock+0x13e6>
 10c0931:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c0937:	31 c0                	xor    %eax,%eax
 10c0939:	84 c0                	test   %al,%al
 10c093b:	0f 85 09 2a 00 00    	jne    10c334a <zstd.emitBestSequenceCompressedBlock+0x3b0a>
 10c0941:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c0945:	48 8b 38             	mov    (%rax),%rdi
 10c0948:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c094c:	be 81 00 00 00       	mov    $0x81,%esi
 10c0951:	31 d2                	xor    %edx,%edx
 10c0953:	4c 89 e1             	mov    %r12,%rcx
 10c0956:	ff 10                	call   *(%rax)
 10c0958:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 10c095c:	48 85 c0             	test   %rax,%rax
 10c095f:	0f 84 e1 29 00 00    	je     10c3346 <zstd.emitBestSequenceCompressedBlock+0x3b06>
 10c0965:	48 89 da             	mov    %rbx,%rdx
 10c0968:	8d 43 7f             	lea    0x7f(%rbx),%eax
 10c096b:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 10c096f:	88 01                	mov    %al,(%rcx)
 10c0971:	84 d2                	test   %dl,%dl
 10c0973:	0f 84 94 1a 00 00    	je     10c240d <zstd.emitBestSequenceCompressedBlock+0x2bcd>
 10c0979:	49 89 d9             	mov    %rbx,%r9
 10c097c:	41 ff c1             	inc    %r9d
 10c097f:	41 d1 e9             	shr    %r9d
 10c0982:	45 01 c9             	add    %r9d,%r9d
 10c0985:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 10c098b:	ba 81 00 00 00       	mov    $0x81,%edx
 10c0990:	41 bc 82 00 00 00    	mov    $0x82,%r12d
 10c0996:	41 be 02 00 00 00    	mov    $0x2,%r14d
 10c099c:	45 31 ff             	xor    %r15d,%r15d
 10c099f:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 10c09a3:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c09a7:	4c 89 4d a0          	mov    %r9,-0x60(%rbp)
 10c09ab:	e9 97 00 00 00       	jmp    10c0a47 <zstd.emitBestSequenceCompressedBlock+0x1207>
 10c09b0:	bb c2 ff 03 01       	mov    $0x103ffc2,%ebx
 10c09b5:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c09b9:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 10c09bd:	49 8b 3e             	mov    (%r14),%rdi
 10c09c0:	49 8b 46 08          	mov    0x8(%r14),%rax
 10c09c4:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 10c09cb:	31 c9                	xor    %ecx,%ecx
 10c09cd:	4d 89 e0             	mov    %r12,%r8
 10c09d0:	c5 f8 77             	vzeroupper 
 10c09d3:	ff 50 18             	call   *0x18(%rax)
 10c09d6:	4c 89 f6             	mov    %r14,%rsi
 10c09d9:	4c 8b 8d e8 fe ff ff 	mov    -0x118(%rbp),%r9
 10c09e0:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 10c09e7:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 10c09ee:	4c 8b 65 98          	mov    -0x68(%rbp),%r12
 10c09f2:	f6 03 01             	testb  $0x1,(%rbx)
 10c09f5:	0f 84 a9 f0 ff ff    	je     10bfaa4 <zstd.emitBestSequenceCompressedBlock+0x264>
 10c09fb:	e9 75 fa ff ff       	jmp    10c0475 <zstd.emitBestSequenceCompressedBlock+0xc35>
 10c0a00:	66 b9 1a 00          	mov    $0x1a,%cx
 10c0a04:	31 c0                	xor    %eax,%eax
 10c0a06:	84 c0                	test   %al,%al
 10c0a08:	0f 84 a4 01 00 00    	je     10c0bb2 <zstd.emitBestSequenceCompressedBlock+0x1372>
 10c0a0e:	4c 89 d2             	mov    %r10,%rdx
 10c0a11:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c0a15:	48 85 d2             	test   %rdx,%rdx
 10c0a18:	0f 85 e7 fb ff ff    	jne    10c0605 <zstd.emitBestSequenceCompressedBlock+0xdc5>
 10c0a1e:	e9 1f f0 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c0a23:	48 89 c6             	mov    %rax,%rsi
 10c0a26:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 10c0a2a:	45 08 d5             	or     %r10b,%r13b
 10c0a2d:	46 88 2c 06          	mov    %r13b,(%rsi,%r8,1)
 10c0a31:	49 ff c4             	inc    %r12
 10c0a34:	49 ff c6             	inc    %r14
 10c0a37:	49 83 c7 02          	add    $0x2,%r15
 10c0a3b:	49 ff c0             	inc    %r8
 10c0a3e:	4d 39 f9             	cmp    %r15,%r9
 10c0a41:	0f 84 a7 19 00 00    	je     10c23ee <zstd.emitBestSequenceCompressedBlock+0x2bae>
 10c0a47:	0f b6 85 98 e4 ff ff 	movzbl -0x1b68(%rbp),%eax
 10c0a4e:	41 38 c7             	cmp    %al,%r15b
 10c0a51:	74 23                	je     10c0a76 <zstd.emitBestSequenceCompressedBlock+0x1236>
 10c0a53:	42 0f b6 bc 3d 98 e3 	movzbl -0x1c68(%rbp,%r15,1),%edi
 10c0a5a:	ff ff 
 10c0a5c:	40 84 ff             	test   %dil,%dil
 10c0a5f:	74 15                	je     10c0a76 <zstd.emitBestSequenceCompressedBlock+0x1236>
 10c0a61:	44 0f b6 95 99 e4 ff 	movzbl -0x1b67(%rbp),%r10d
 10c0a68:	ff 
 10c0a69:	41 28 fa             	sub    %dil,%r10b
 10c0a6c:	41 c0 e2 04          	shl    $0x4,%r10b
 10c0a70:	41 80 c2 10          	add    $0x10,%r10b
 10c0a74:	eb 03                	jmp    10c0a79 <zstd.emitBestSequenceCompressedBlock+0x1239>
 10c0a76:	45 31 d2             	xor    %r10d,%r10d
 10c0a79:	49 8d 7f 01          	lea    0x1(%r15),%rdi
 10c0a7d:	40 38 c7             	cmp    %al,%dil
 10c0a80:	74 21                	je     10c0aa3 <zstd.emitBestSequenceCompressedBlock+0x1263>
 10c0a82:	42 0f b6 84 3d 99 e3 	movzbl -0x1c67(%rbp,%r15,1),%eax
 10c0a89:	ff ff 
 10c0a8b:	84 c0                	test   %al,%al
 10c0a8d:	74 14                	je     10c0aa3 <zstd.emitBestSequenceCompressedBlock+0x1263>
 10c0a8f:	44 0f b6 ad 99 e4 ff 	movzbl -0x1b67(%rbp),%r13d
 10c0a96:	ff 
 10c0a97:	41 28 c5             	sub    %al,%r13b
 10c0a9a:	41 fe c5             	inc    %r13b
 10c0a9d:	41 80 e5 0f          	and    $0xf,%r13b
 10c0aa1:	eb 03                	jmp    10c0aa6 <zstd.emitBestSequenceCompressedBlock+0x1266>
 10c0aa3:	45 31 ed             	xor    %r13d,%r13d
 10c0aa6:	4c 39 c2             	cmp    %r8,%rdx
 10c0aa9:	0f 87 7b ff ff ff    	ja     10c0a2a <zstd.emitBestSequenceCompressedBlock+0x11ea>
 10c0aaf:	4c 89 f3             	mov    %r14,%rbx
 10c0ab2:	48 d1 eb             	shr    %rbx
 10c0ab5:	4c 01 e3             	add    %r12,%rbx
 10c0ab8:	48 8b 39             	mov    (%rcx),%rdi
 10c0abb:	4c 8b 59 08          	mov    0x8(%rcx),%r11
 10c0abf:	31 c0                	xor    %eax,%eax
 10c0ac1:	84 c0                	test   %al,%al
 10c0ac3:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 10c0ac7:	48 89 55 88          	mov    %rdx,-0x78(%rbp)
 10c0acb:	4c 89 9d 58 ff ff ff 	mov    %r11,-0xa8(%rbp)
 10c0ad2:	48 89 bd 88 fe ff ff 	mov    %rdi,-0x178(%rbp)
 10c0ad9:	74 06                	je     10c0ae1 <zstd.emitBestSequenceCompressedBlock+0x12a1>
 10c0adb:	31 c0                	xor    %eax,%eax
 10c0add:	31 d2                	xor    %edx,%edx
 10c0adf:	eb 2f                	jmp    10c0b10 <zstd.emitBestSequenceCompressedBlock+0x12d0>
 10c0ae1:	44 89 55 c0          	mov    %r10d,-0x40(%rbp)
 10c0ae5:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 10c0ae9:	31 c9                	xor    %ecx,%ecx
 10c0aeb:	49 89 d8             	mov    %rbx,%r8
 10c0aee:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c0af2:	41 ff 53 10          	call   *0x10(%r11)
 10c0af6:	48 85 c0             	test   %rax,%rax
 10c0af9:	74 05                	je     10c0b00 <zstd.emitBestSequenceCompressedBlock+0x12c0>
 10c0afb:	48 89 da             	mov    %rbx,%rdx
 10c0afe:	eb 04                	jmp    10c0b04 <zstd.emitBestSequenceCompressedBlock+0x12c4>
 10c0b00:	31 c0                	xor    %eax,%eax
 10c0b02:	31 d2                	xor    %edx,%edx
 10c0b04:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 10c0b08:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10c0b0c:	44 8b 55 c0          	mov    -0x40(%rbp),%r10d
 10c0b10:	48 85 c0             	test   %rax,%rax
 10c0b13:	0f 85 0a ff ff ff    	jne    10c0a23 <zstd.emitBestSequenceCompressedBlock+0x11e3>
 10c0b19:	44 89 55 c0          	mov    %r10d,-0x40(%rbp)
 10c0b1d:	4c 89 a5 70 ff ff ff 	mov    %r12,-0x90(%rbp)
 10c0b24:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 10c0b28:	31 c0                	xor    %eax,%eax
 10c0b2a:	84 c0                	test   %al,%al
 10c0b2c:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c0b30:	0f 85 25 1a 00 00    	jne    10c255b <zstd.emitBestSequenceCompressedBlock+0x2d1b>
 10c0b36:	48 8b bd 88 fe ff ff 	mov    -0x178(%rbp),%rdi
 10c0b3d:	48 89 de             	mov    %rbx,%rsi
 10c0b40:	31 d2                	xor    %edx,%edx
 10c0b42:	4c 89 e1             	mov    %r12,%rcx
 10c0b45:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 10c0b4c:	ff 10                	call   *(%rax)
 10c0b4e:	48 85 c0             	test   %rax,%rax
 10c0b51:	0f 84 04 1a 00 00    	je     10c255b <zstd.emitBestSequenceCompressedBlock+0x2d1b>
 10c0b57:	48 89 c7             	mov    %rax,%rdi
 10c0b5a:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c0b5e:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 10c0b62:	48 89 85 98 fe ff ff 	mov    %rax,-0x168(%rbp)
 10c0b69:	e8 52 c9 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c0b6e:	48 8b bd 88 fe ff ff 	mov    -0x178(%rbp),%rdi
 10c0b75:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c0b79:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 10c0b7d:	31 c9                	xor    %ecx,%ecx
 10c0b7f:	4d 89 e0             	mov    %r12,%r8
 10c0b82:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 10c0b89:	ff 50 18             	call   *0x18(%rax)
 10c0b8c:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10c0b90:	48 89 da             	mov    %rbx,%rdx
 10c0b93:	48 8b b5 98 fe ff ff 	mov    -0x168(%rbp),%rsi
 10c0b9a:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 10c0b9e:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 10c0ba2:	4c 8b a5 70 ff ff ff 	mov    -0x90(%rbp),%r12
 10c0ba9:	44 8b 55 c0          	mov    -0x40(%rbp),%r10d
 10c0bad:	e9 78 fe ff ff       	jmp    10c0a2a <zstd.emitBestSequenceCompressedBlock+0x11ea>
 10c0bb2:	48 89 fb             	mov    %rdi,%rbx
 10c0bb5:	4c 89 65 a0          	mov    %r12,-0x60(%rbp)
 10c0bb9:	4c 89 e7             	mov    %r12,%rdi
 10c0bbc:	4c 89 85 10 ff ff ff 	mov    %r8,-0xf0(%rbp)
 10c0bc3:	4c 89 c6             	mov    %r8,%rsi
 10c0bc6:	31 d2                	xor    %edx,%edx
 10c0bc8:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10c0bcc:	4d 89 dc             	mov    %r11,%r12
 10c0bcf:	41 ff 13             	call   *(%r11)
 10c0bd2:	48 85 c0             	test   %rax,%rax
 10c0bd5:	0f 84 00 02 00 00    	je     10c0ddb <zstd.emitBestSequenceCompressedBlock+0x159b>
 10c0bdb:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 10c0bdf:	48 89 c7             	mov    %rax,%rdi
 10c0be2:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10c0be6:	48 89 da             	mov    %rbx,%rdx
 10c0be9:	e8 d2 c8 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c0bee:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 10c0bf3:	74 17                	je     10c0c0c <zstd.emitBestSequenceCompressedBlock+0x13cc>
 10c0bf5:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 10c0bf9:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10c0bfd:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 10c0c01:	31 c9                	xor    %ecx,%ecx
 10c0c03:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c0c07:	41 ff 54 24 18       	call   *0x18(%r12)
 10c0c0c:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 10c0c10:	4c 8b 8d 68 fe ff ff 	mov    -0x198(%rbp),%r9
 10c0c17:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 10c0c1e:	48 89 df             	mov    %rbx,%rdi
 10c0c21:	e9 56 fa ff ff       	jmp    10c067c <zstd.emitBestSequenceCompressedBlock+0xe3c>
 10c0c26:	b8 01 00 00 00       	mov    $0x1,%eax
 10c0c2b:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 10c0c2f:	48 c7 45 a8 00 00 00 	movq   $0x0,-0x58(%rbp)
 10c0c36:	00 
 10c0c37:	48 c7 45 88 00 00 00 	movq   $0x0,-0x78(%rbp)
 10c0c3e:	00 
 10c0c3f:	49 89 db             	mov    %rbx,%r11
 10c0c42:	0f b6 fb             	movzbl %bl,%edi
 10c0c45:	0f b6 85 99 e4 ff ff 	movzbl -0x1b67(%rbp),%eax
 10c0c4c:	fe c0                	inc    %al
 10c0c4e:	89 f9                	mov    %edi,%ecx
 10c0c50:	83 e1 03             	and    $0x3,%ecx
 10c0c53:	31 d2                	xor    %edx,%edx
 10c0c55:	40 80 ff 04          	cmp    $0x4,%dil
 10c0c59:	73 0a                	jae    10c0c65 <zstd.emitBestSequenceCompressedBlock+0x1425>
 10c0c5b:	49 89 fe             	mov    %rdi,%r14
 10c0c5e:	31 f6                	xor    %esi,%esi
 10c0c60:	e9 ad 00 00 00       	jmp    10c0d12 <zstd.emitBestSequenceCompressedBlock+0x14d2>
 10c0c65:	49 89 fe             	mov    %rdi,%r14
 10c0c68:	83 e7 fc             	and    $0xfffffffc,%edi
 10c0c6b:	31 f6                	xor    %esi,%esi
 10c0c6d:	44 0f b6 84 35 98 e3 	movzbl -0x1c68(%rbp,%rsi,1),%r8d
 10c0c74:	ff ff 
 10c0c76:	44 0f b6 8c 35 99 e3 	movzbl -0x1c67(%rbp,%rsi,1),%r9d
 10c0c7d:	ff ff 
 10c0c7f:	41 89 c2             	mov    %eax,%r10d
 10c0c82:	45 28 c2             	sub    %r8b,%r10b
 10c0c85:	41 80 e2 0f          	and    $0xf,%r10b
 10c0c89:	45 84 c0             	test   %r8b,%r8b
 10c0c8c:	45 0f b6 c2          	movzbl %r10b,%r8d
 10c0c90:	44 0f 44 c2          	cmove  %edx,%r8d
 10c0c94:	44 88 84 35 a0 e4 ff 	mov    %r8b,-0x1b60(%rbp,%rsi,1)
 10c0c9b:	ff 
 10c0c9c:	41 89 c0             	mov    %eax,%r8d
 10c0c9f:	45 28 c8             	sub    %r9b,%r8b
 10c0ca2:	41 80 e0 0f          	and    $0xf,%r8b
 10c0ca6:	45 84 c9             	test   %r9b,%r9b
 10c0ca9:	45 0f b6 c0          	movzbl %r8b,%r8d
 10c0cad:	44 0f 44 c2          	cmove  %edx,%r8d
 10c0cb1:	44 88 84 35 a1 e4 ff 	mov    %r8b,-0x1b5f(%rbp,%rsi,1)
 10c0cb8:	ff 
 10c0cb9:	44 0f b6 84 35 9a e3 	movzbl -0x1c66(%rbp,%rsi,1),%r8d
 10c0cc0:	ff ff 
 10c0cc2:	41 89 c1             	mov    %eax,%r9d
 10c0cc5:	45 28 c1             	sub    %r8b,%r9b
 10c0cc8:	41 80 e1 0f          	and    $0xf,%r9b
 10c0ccc:	45 84 c0             	test   %r8b,%r8b
 10c0ccf:	45 0f b6 c1          	movzbl %r9b,%r8d
 10c0cd3:	44 0f 44 c2          	cmove  %edx,%r8d
 10c0cd7:	44 88 84 35 a2 e4 ff 	mov    %r8b,-0x1b5e(%rbp,%rsi,1)
 10c0cde:	ff 
 10c0cdf:	44 0f b6 84 35 9b e3 	movzbl -0x1c65(%rbp,%rsi,1),%r8d
 10c0ce6:	ff ff 
 10c0ce8:	41 89 c1             	mov    %eax,%r9d
 10c0ceb:	45 28 c1             	sub    %r8b,%r9b
 10c0cee:	41 80 e1 0f          	and    $0xf,%r9b
 10c0cf2:	45 84 c0             	test   %r8b,%r8b
 10c0cf5:	45 0f b6 c1          	movzbl %r9b,%r8d
 10c0cf9:	44 0f 44 c2          	cmove  %edx,%r8d
 10c0cfd:	44 88 84 35 a3 e4 ff 	mov    %r8b,-0x1b5d(%rbp,%rsi,1)
 10c0d04:	ff 
 10c0d05:	48 83 c6 04          	add    $0x4,%rsi
 10c0d09:	48 39 f7             	cmp    %rsi,%rdi
 10c0d0c:	0f 85 5b ff ff ff    	jne    10c0c6d <zstd.emitBestSequenceCompressedBlock+0x142d>
 10c0d12:	48 85 c9             	test   %rcx,%rcx
 10c0d15:	74 46                	je     10c0d5d <zstd.emitBestSequenceCompressedBlock+0x151d>
 10c0d17:	48 8d 95 90 db ff ff 	lea    -0x2470(%rbp),%rdx
 10c0d1e:	48 01 f2             	add    %rsi,%rdx
 10c0d21:	48 81 c2 08 08 00 00 	add    $0x808,%rdx
 10c0d28:	48 01 ee             	add    %rbp,%rsi
 10c0d2b:	48 81 c6 a0 e4 ff ff 	add    $0xffffffffffffe4a0,%rsi
 10c0d32:	31 ff                	xor    %edi,%edi
 10c0d34:	45 31 c0             	xor    %r8d,%r8d
 10c0d37:	46 0f b6 0c 02       	movzbl (%rdx,%r8,1),%r9d
 10c0d3c:	41 89 c2             	mov    %eax,%r10d
 10c0d3f:	45 28 ca             	sub    %r9b,%r10b
 10c0d42:	41 80 e2 0f          	and    $0xf,%r10b
 10c0d46:	45 84 c9             	test   %r9b,%r9b
 10c0d49:	45 0f b6 ca          	movzbl %r10b,%r9d
 10c0d4d:	44 0f 44 cf          	cmove  %edi,%r9d
 10c0d51:	46 88 0c 06          	mov    %r9b,(%rsi,%r8,1)
 10c0d55:	49 ff c0             	inc    %r8
 10c0d58:	4c 39 c1             	cmp    %r8,%rcx
 10c0d5b:	75 da                	jne    10c0d37 <zstd.emitBestSequenceCompressedBlock+0x14f7>
 10c0d5d:	4c 89 db             	mov    %r11,%rbx
 10c0d60:	c5 f8 10 05 e0 ef f4 	vmovups -0xb1020(%rip),%xmm0        # 100fd48 <__anon_3065>
 10c0d67:	ff 
 10c0d68:	c5 f8 29 85 40 ff ff 	vmovaps %xmm0,-0xc0(%rbp)
 10c0d6f:	ff 
 10c0d70:	48 c7 85 50 ff ff ff 	movq   $0x0,-0xb0(%rbp)
 10c0d77:	00 00 00 00 
 10c0d7b:	0f b6 c3             	movzbl %bl,%eax
 10c0d7e:	89 85 20 fe ff ff    	mov    %eax,-0x1e0(%rbp)
 10c0d84:	49 8d 46 fd          	lea    -0x3(%r14),%rax
 10c0d88:	48 89 85 18 fe ff ff 	mov    %rax,-0x1e8(%rbp)
 10c0d8f:	49 8d 46 fe          	lea    -0x2(%r14),%rax
 10c0d93:	48 89 85 10 fe ff ff 	mov    %rax,-0x1f0(%rbp)
 10c0d9a:	b8 01 00 00 00       	mov    $0x1,%eax
 10c0d9f:	48 89 85 a8 fe ff ff 	mov    %rax,-0x158(%rbp)
 10c0da6:	41 b7 01             	mov    $0x1,%r15b
 10c0da9:	0f b6 05 12 f2 f7 ff 	movzbl -0x80dee(%rip),%eax        # 103ffc2 <__anon_14421+0x2>
 10c0db0:	88 85 6f ff ff ff    	mov    %al,-0x91(%rbp)
 10c0db6:	31 c0                	xor    %eax,%eax
 10c0db8:	48 c7 85 90 fe ff ff 	movq   $0x0,-0x170(%rbp)
 10c0dbf:	00 00 00 00 
 10c0dc3:	48 c7 85 58 ff ff ff 	movq   $0x0,-0xa8(%rbp)
 10c0dca:	00 00 00 00 
 10c0dce:	48 89 5d a0          	mov    %rbx,-0x60(%rbp)
 10c0dd2:	4c 89 b5 98 fe ff ff 	mov    %r14,-0x168(%rbp)
 10c0dd9:	eb 68                	jmp    10c0e43 <zstd.emitBestSequenceCompressedBlock+0x1603>
 10c0ddb:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c0ddf:	66 b9 1a 00          	mov    $0x1a,%cx
 10c0de3:	e9 0c f8 ff ff       	jmp    10c05f4 <zstd.emitBestSequenceCompressedBlock+0xdb4>
 10c0de8:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 10c0def:	4c 8b ad a8 fe ff ff 	mov    -0x158(%rbp),%r13
 10c0df6:	4c 89 ef             	mov    %r13,%rdi
 10c0df9:	4c 89 f6             	mov    %r14,%rsi
 10c0dfc:	48 89 da             	mov    %rbx,%rdx
 10c0dff:	c5 f8 77             	vzeroupper 
 10c0e02:	e8 b9 c6 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c0e07:	4c 89 bd 58 ff ff ff 	mov    %r15,-0xa8(%rbp)
 10c0e0e:	48 89 9d 90 fe ff ff 	mov    %rbx,-0x170(%rbp)
 10c0e15:	4c 89 ad a8 fe ff ff 	mov    %r13,-0x158(%rbp)
 10c0e1c:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 10c0e20:	4c 8b b5 98 fe ff ff 	mov    -0x168(%rbp),%r14
 10c0e27:	44 8b bd 88 fe ff ff 	mov    -0x178(%rbp),%r15d
 10c0e2e:	b8 01 00 00 00       	mov    $0x1,%eax
 10c0e33:	41 f6 c7 01          	test   $0x1,%r15b
 10c0e37:	41 bf 00 00 00 00    	mov    $0x0,%r15d
 10c0e3d:	0f 84 e6 15 00 00    	je     10c2429 <zstd.emitBestSequenceCompressedBlock+0x2be9>
 10c0e43:	0f b6 b0 20 5f 01 01 	movzbl 0x1015f20(%rax),%esi
 10c0e4a:	48 c7 85 48 ff ff ff 	movq   $0x0,-0xb8(%rbp)
 10c0e51:	00 00 00 00 
 10c0e55:	80 fb 03             	cmp    $0x3,%bl
 10c0e58:	0f 83 c3 00 00 00    	jae    10c0f21 <zstd.emitBestSequenceCompressedBlock+0x16e1>
 10c0e5e:	f6 05 5d f1 f7 ff 01 	testb  $0x1,-0x80ea3(%rip)        # 103ffc2 <__anon_14421+0x2>
 10c0e65:	74 c7                	je     10c0e2e <zstd.emitBestSequenceCompressedBlock+0x15ee>
 10c0e67:	44 89 bd 88 fe ff ff 	mov    %r15d,-0x178(%rbp)
 10c0e6e:	31 db                	xor    %ebx,%ebx
 10c0e70:	48 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%rax
 10c0e77:	48 ff c8             	dec    %rax
 10c0e7a:	48 39 d8             	cmp    %rbx,%rax
 10c0e7d:	72 9d                	jb     10c0e1c <zstd.emitBestSequenceCompressedBlock+0x15dc>
 10c0e7f:	4c 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%r14
 10c0e86:	c6 85 b0 ed ff ff 00 	movb   $0x0,-0x1250(%rbp)
 10c0e8d:	c6 85 d0 fd ff ff 00 	movb   $0x0,-0x230(%rbp)
 10c0e94:	31 c0                	xor    %eax,%eax
 10c0e96:	84 c0                	test   %al,%al
 10c0e98:	0f 85 c4 17 00 00    	jne    10c2662 <zstd.emitBestSequenceCompressedBlock+0x2e22>
 10c0e9e:	48 39 9d 58 ff ff ff 	cmp    %rbx,-0xa8(%rbp)
 10c0ea5:	0f 83 3d ff ff ff    	jae    10c0de8 <zstd.emitBestSequenceCompressedBlock+0x15a8>
 10c0eab:	49 89 df             	mov    %rbx,%r15
 10c0eae:	49 d1 ef             	shr    %r15
 10c0eb1:	49 83 ef 80          	sub    $0xffffffffffffff80,%r15
 10c0eb5:	49 01 df             	add    %rbx,%r15
 10c0eb8:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10c0ebf:	4c 0f 42 f8          	cmovb  %rax,%r15
 10c0ec3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c0ec7:	48 8b 08             	mov    (%rax),%rcx
 10c0eca:	48 89 4d c0          	mov    %rcx,-0x40(%rbp)
 10c0ece:	4c 8b 60 08          	mov    0x8(%rax),%r12
 10c0ed2:	48 83 bd 58 ff ff ff 	cmpq   $0x0,-0xa8(%rbp)
 10c0ed9:	00 
 10c0eda:	0f 84 b9 0a 00 00    	je     10c1999 <zstd.emitBestSequenceCompressedBlock+0x2159>
 10c0ee0:	31 c0                	xor    %eax,%eax
 10c0ee2:	84 c0                	test   %al,%al
 10c0ee4:	0f 85 af 0a 00 00    	jne    10c1999 <zstd.emitBestSequenceCompressedBlock+0x2159>
 10c0eea:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 10c0eee:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c0ef5:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10c0efc:	31 c9                	xor    %ecx,%ecx
 10c0efe:	4d 89 f8             	mov    %r15,%r8
 10c0f01:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c0f05:	c5 f8 77             	vzeroupper 
 10c0f08:	41 ff 54 24 10       	call   *0x10(%r12)
 10c0f0d:	48 85 c0             	test   %rax,%rax
 10c0f10:	0f 84 83 0a 00 00    	je     10c1999 <zstd.emitBestSequenceCompressedBlock+0x2159>
 10c0f16:	49 89 c5             	mov    %rax,%r13
 10c0f19:	4c 89 f8             	mov    %r15,%rax
 10c0f1c:	e9 7d 0a 00 00       	jmp    10c199e <zstd.emitBestSequenceCompressedBlock+0x215e>
 10c0f21:	c5 f0 57 c9          	vxorps %xmm1,%xmm1,%xmm1
 10c0f25:	c5 fc 11 8d f0 fd ff 	vmovups %ymm1,-0x210(%rbp)
 10c0f2c:	ff 
 10c0f2d:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 10c0f31:	c5 fc 11 8d d0 fd ff 	vmovups %ymm1,-0x230(%rbp)
 10c0f38:	ff 
 10c0f39:	31 c0                	xor    %eax,%eax
 10c0f3b:	31 c9                	xor    %ecx,%ecx
 10c0f3d:	0f b6 94 05 a0 e4 ff 	movzbl -0x1b60(%rbp,%rax,1),%edx
 10c0f44:	ff 
 10c0f45:	48 83 fa 0f          	cmp    $0xf,%rdx
 10c0f49:	0f 87 d9 13 00 00    	ja     10c2328 <zstd.emitBestSequenceCompressedBlock+0x2ae8>
 10c0f4f:	ff 84 95 d0 fd ff ff 	incl   -0x230(%rbp,%rdx,4)
 10c0f56:	0f b6 c9             	movzbl %cl,%ecx
 10c0f59:	38 d1                	cmp    %dl,%cl
 10c0f5b:	0f 46 ca             	cmovbe %edx,%ecx
 10c0f5e:	48 ff c0             	inc    %rax
 10c0f61:	49 39 c6             	cmp    %rax,%r14
 10c0f64:	75 d7                	jne    10c0f3d <zstd.emitBestSequenceCompressedBlock+0x16fd>
 10c0f66:	48 89 b5 78 fe ff ff 	mov    %rsi,-0x188(%rbp)
 10c0f6d:	44 89 bd 88 fe ff ff 	mov    %r15d,-0x178(%rbp)
 10c0f74:	0f b6 c1             	movzbl %cl,%eax
 10c0f77:	48 8d 48 01          	lea    0x1(%rax),%rcx
 10c0f7b:	48 89 8d a0 fe ff ff 	mov    %rcx,-0x160(%rbp)
 10c0f82:	48 89 85 70 fe ff ff 	mov    %rax,-0x190(%rbp)
 10c0f89:	3c 07                	cmp    $0x7,%al
 10c0f8b:	0f 83 28 09 00 00    	jae    10c18b9 <zstd.emitBestSequenceCompressedBlock+0x2079>
 10c0f91:	31 c9                	xor    %ecx,%ecx
 10c0f93:	31 c0                	xor    %eax,%eax
 10c0f95:	48 8b 95 a0 fe ff ff 	mov    -0x160(%rbp),%rdx
 10c0f9c:	83 e2 07             	and    $0x7,%edx
 10c0f9f:	74 1d                	je     10c0fbe <zstd.emitBestSequenceCompressedBlock+0x177e>
 10c0fa1:	48 8d 0c 8d d0 fd ff 	lea    -0x230(,%rcx,4),%rcx
 10c0fa8:	ff 
 10c0fa9:	48 01 e9             	add    %rbp,%rcx
 10c0fac:	31 f6                	xor    %esi,%esi
 10c0fae:	8b 3c b1             	mov    (%rcx,%rsi,4),%edi
 10c0fb1:	39 f8                	cmp    %edi,%eax
 10c0fb3:	0f 46 c7             	cmovbe %edi,%eax
 10c0fb6:	48 ff c6             	inc    %rsi
 10c0fb9:	48 39 f2             	cmp    %rsi,%rdx
 10c0fbc:	75 f0                	jne    10c0fae <zstd.emitBestSequenceCompressedBlock+0x176e>
 10c0fbe:	83 f8 01             	cmp    $0x1,%eax
 10c0fc1:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 10c0fc5:	4c 8b b5 98 fe ff ff 	mov    -0x168(%rbp),%r14
 10c0fcc:	44 8b bd 88 fe ff ff 	mov    -0x178(%rbp),%r15d
 10c0fd3:	4c 8b ad 78 fe ff ff 	mov    -0x188(%rbp),%r13
 10c0fda:	0f 84 7e fe ff ff    	je     10c0e5e <zstd.emitBestSequenceCompressedBlock+0x161e>
 10c0fe0:	3b 85 20 fe ff ff    	cmp    -0x1e0(%rbp),%eax
 10c0fe6:	0f 84 72 fe ff ff    	je     10c0e5e <zstd.emitBestSequenceCompressedBlock+0x161e>
 10c0fec:	c5 fc 11 85 b0 fd ff 	vmovups %ymm0,-0x250(%rbp)
 10c0ff3:	ff 
 10c0ff4:	48 8d bd d0 fd ff ff 	lea    -0x230(%rbp),%rdi
 10c0ffb:	48 8b b5 a0 fe ff ff 	mov    -0x160(%rbp),%rsi
 10c1002:	4c 89 f2             	mov    %r14,%rdx
 10c1005:	44 89 e9             	mov    %r13d,%ecx
 10c1008:	4c 8d 85 b0 fd ff ff 	lea    -0x250(%rbp),%r8
 10c100f:	49 89 f1             	mov    %rsi,%r9
 10c1012:	c5 f8 77             	vzeroupper 
 10c1015:	e8 16 67 00 00       	call   10c7730 <zstd.normalizeFseCounts>
 10c101a:	84 c0                	test   %al,%al
 10c101c:	0f 84 3c fe ff ff    	je     10c0e5e <zstd.emitBestSequenceCompressedBlock+0x161e>
 10c1022:	41 8d 45 f6          	lea    -0xa(%r13),%eax
 10c1026:	3c fb                	cmp    $0xfb,%al
 10c1028:	0f 82 fa 12 00 00    	jb     10c2328 <zstd.emitBestSequenceCompressedBlock+0x2ae8>
 10c102e:	48 8b 8d 78 fe ff ff 	mov    -0x188(%rbp),%rcx
 10c1035:	8d 41 fb             	lea    -0x5(%rcx),%eax
 10c1038:	0f b6 c0             	movzbl %al,%eax
 10c103b:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 10c103f:	b8 01 00 00 00       	mov    $0x1,%eax
 10c1044:	c4 62 71 f7 f8       	shlx   %ecx,%eax,%r15d
 10c1049:	41 8d 57 01          	lea    0x1(%r15),%edx
 10c104d:	44 8d 71 01          	lea    0x1(%rcx),%r14d
 10c1051:	b3 04                	mov    $0x4,%bl
 10c1053:	31 c0                	xor    %eax,%eax
 10c1055:	31 c9                	xor    %ecx,%ecx
 10c1057:	89 95 70 ff ff ff    	mov    %edx,-0x90(%rbp)
 10c105d:	f6 c1 01             	test   $0x1,%cl
 10c1060:	0f 84 56 01 00 00    	je     10c11bc <zstd.emitBestSequenceCompressedBlock+0x197c>
 10c1066:	49 89 c5             	mov    %rax,%r13
 10c1069:	48 3b 85 70 fe ff ff 	cmp    -0x190(%rbp),%rax
 10c1070:	48 8b 8d a0 fe ff ff 	mov    -0x160(%rbp),%rcx
 10c1077:	0f 86 22 01 00 00    	jbe    10c119f <zstd.emitBestSequenceCompressedBlock+0x195f>
 10c107d:	49 39 cd             	cmp    %rcx,%r13
 10c1080:	0f 84 a2 12 00 00    	je     10c2328 <zstd.emitBestSequenceCompressedBlock+0x2ae8>
 10c1086:	48 8d 48 03          	lea    0x3(%rax),%rcx
 10c108a:	49 39 cd             	cmp    %rcx,%r13
 10c108d:	72 2c                	jb     10c10bb <zstd.emitBestSequenceCompressedBlock+0x187b>
 10c108f:	0f b6 db             	movzbl %bl,%ebx
 10c1092:	ba 03 00 00 00       	mov    $0x3,%edx
 10c1097:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c109b:	48 89 c1             	mov    %rax,%rcx
 10c109e:	c4 e2 e1 f7 c2       	shlx   %rbx,%rdx,%rax
 10c10a3:	48 01 c6             	add    %rax,%rsi
 10c10a6:	48 83 c3 02          	add    $0x2,%rbx
 10c10aa:	48 8d 41 03          	lea    0x3(%rcx),%rax
 10c10ae:	48 83 c1 06          	add    $0x6,%rcx
 10c10b2:	49 39 cd             	cmp    %rcx,%r13
 10c10b5:	73 e4                	jae    10c109b <zstd.emitBestSequenceCompressedBlock+0x185b>
 10c10b7:	48 89 75 c0          	mov    %rsi,-0x40(%rbp)
 10c10bb:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 10c10bf:	4c 89 ea             	mov    %r13,%rdx
 10c10c2:	48 29 c2             	sub    %rax,%rdx
 10c10c5:	c4 e2 e1 f7 c2       	shlx   %rbx,%rdx,%rax
 10c10ca:	48 01 c8             	add    %rcx,%rax
 10c10cd:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 10c10d1:	80 fb 0f             	cmp    $0xf,%bl
 10c10d4:	0f 82 ea 00 00 00    	jb     10c11c4 <zstd.emitBestSequenceCompressedBlock+0x1984>
 10c10da:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10c10e1:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 10c10e8:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 10c10ef:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c10f6:	48 8d 41 01          	lea    0x1(%rcx),%rax
 10c10fa:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 10c1101:	48 89 8d f8 fe ff ff 	mov    %rcx,-0x108(%rbp)
 10c1108:	48 89 95 30 ff ff ff 	mov    %rdx,-0xd0(%rbp)
 10c110f:	48 39 ca             	cmp    %rcx,%rdx
 10c1112:	0f 87 7a 01 00 00    	ja     10c1292 <zstd.emitBestSequenceCompressedBlock+0x1a52>
 10c1118:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 10c111f:	48 89 c1             	mov    %rax,%rcx
 10c1122:	48 d1 e9             	shr    %rcx
 10c1125:	48 83 e9 80          	sub    $0xffffffffffffff80,%rcx
 10c1129:	48 01 c1             	add    %rax,%rcx
 10c112c:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10c1133:	48 0f 42 c8          	cmovb  %rax,%rcx
 10c1137:	48 89 4d 80          	mov    %rcx,-0x80(%rbp)
 10c113b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c113f:	48 8b 08             	mov    (%rax),%rcx
 10c1142:	48 89 8d 00 ff ff ff 	mov    %rcx,-0x100(%rbp)
 10c1149:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c114d:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 10c1154:	48 83 bd 30 ff ff ff 	cmpq   $0x0,-0xd0(%rbp)
 10c115b:	00 
 10c115c:	74 6e                	je     10c11cc <zstd.emitBestSequenceCompressedBlock+0x198c>
 10c115e:	31 c0                	xor    %eax,%eax
 10c1160:	84 c0                	test   %al,%al
 10c1162:	75 68                	jne    10c11cc <zstd.emitBestSequenceCompressedBlock+0x198c>
 10c1164:	48 8b bd 00 ff ff ff 	mov    -0x100(%rbp),%rdi
 10c116b:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 10c1172:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 10c1179:	31 c9                	xor    %ecx,%ecx
 10c117b:	4c 8b 45 80          	mov    -0x80(%rbp),%r8
 10c117f:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c1183:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c118a:	ff 50 10             	call   *0x10(%rax)
 10c118d:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 10c1194:	48 85 c0             	test   %rax,%rax
 10c1197:	74 33                	je     10c11cc <zstd.emitBestSequenceCompressedBlock+0x198c>
 10c1199:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 10c119d:	eb 3a                	jmp    10c11d9 <zstd.emitBestSequenceCompressedBlock+0x1999>
 10c119f:	66 42 83 bc 6d b0 fd 	cmpw   $0x0,-0x250(%rbp,%r13,2)
 10c11a6:	ff ff 00 
 10c11a9:	0f 85 ce fe ff ff    	jne    10c107d <zstd.emitBestSequenceCompressedBlock+0x183d>
 10c11af:	49 ff c5             	inc    %r13
 10c11b2:	4c 39 e9             	cmp    %r13,%rcx
 10c11b5:	75 e8                	jne    10c119f <zstd.emitBestSequenceCompressedBlock+0x195f>
 10c11b7:	e9 6c 11 00 00       	jmp    10c2328 <zstd.emitBestSequenceCompressedBlock+0x2ae8>
 10c11bc:	49 89 c5             	mov    %rax,%r13
 10c11bf:	e9 af 02 00 00       	jmp    10c1473 <zstd.emitBestSequenceCompressedBlock+0x1c33>
 10c11c4:	80 c3 02             	add    $0x2,%bl
 10c11c7:	e9 a7 02 00 00       	jmp    10c1473 <zstd.emitBestSequenceCompressedBlock+0x1c33>
 10c11cc:	48 c7 85 78 ff ff ff 	movq   $0x0,-0x88(%rbp)
 10c11d3:	00 00 00 00 
 10c11d7:	31 c0                	xor    %eax,%eax
 10c11d9:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10c11e0:	00 
 10c11e1:	74 09                	je     10c11ec <zstd.emitBestSequenceCompressedBlock+0x19ac>
 10c11e3:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 10c11e7:	e9 86 00 00 00       	jmp    10c1272 <zstd.emitBestSequenceCompressedBlock+0x1a32>
 10c11ec:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c11f2:	31 c0                	xor    %eax,%eax
 10c11f4:	84 c0                	test   %al,%al
 10c11f6:	0f 85 32 11 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c11fc:	48 8b bd 00 ff ff ff 	mov    -0x100(%rbp),%rdi
 10c1203:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 10c1207:	31 d2                	xor    %edx,%edx
 10c1209:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c120d:	4c 89 e1             	mov    %r12,%rcx
 10c1210:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c1217:	ff 10                	call   *(%rax)
 10c1219:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 10c1220:	48 85 c0             	test   %rax,%rax
 10c1223:	0f 84 09 11 00 00    	je     10c2332 <zstd.emitBestSequenceCompressedBlock+0x2af2>
 10c1229:	48 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%rdi
 10c1230:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 10c1237:	48 8b 95 f8 fe ff ff 	mov    -0x108(%rbp),%rdx
 10c123e:	e8 7d c2 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c1243:	48 83 bd 30 ff ff ff 	cmpq   $0x0,-0xd0(%rbp)
 10c124a:	00 
 10c124b:	74 25                	je     10c1272 <zstd.emitBestSequenceCompressedBlock+0x1a32>
 10c124d:	48 8b bd 00 ff ff ff 	mov    -0x100(%rbp),%rdi
 10c1254:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 10c125b:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 10c1262:	31 c9                	xor    %ecx,%ecx
 10c1264:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c1268:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c126f:	ff 50 18             	call   *0x18(%rax)
 10c1272:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 10c1279:	48 89 8d 40 ff ff ff 	mov    %rcx,-0xc0(%rbp)
 10c1280:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 10c1284:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 10c128b:	48 89 8d 28 ff ff ff 	mov    %rcx,-0xd8(%rbp)
 10c1292:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 10c1299:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 10c12a0:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 10c12a4:	48 8b 8d f8 fe ff ff 	mov    -0x108(%rbp),%rcx
 10c12ab:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 10c12b2:	88 04 0a             	mov    %al,(%rdx,%rcx,1)
 10c12b5:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10c12bc:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 10c12c3:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 10c12ca:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c12d1:	48 8d 41 01          	lea    0x1(%rcx),%rax
 10c12d5:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 10c12dc:	48 89 8d f8 fe ff ff 	mov    %rcx,-0x108(%rbp)
 10c12e3:	48 89 95 30 ff ff ff 	mov    %rdx,-0xd0(%rbp)
 10c12ea:	48 39 ca             	cmp    %rcx,%rdx
 10c12ed:	0f 87 4d 01 00 00    	ja     10c1440 <zstd.emitBestSequenceCompressedBlock+0x1c00>
 10c12f3:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 10c12fa:	48 89 c1             	mov    %rax,%rcx
 10c12fd:	48 d1 e9             	shr    %rcx
 10c1300:	48 83 e9 80          	sub    $0xffffffffffffff80,%rcx
 10c1304:	48 01 c1             	add    %rax,%rcx
 10c1307:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10c130e:	48 0f 42 c8          	cmovb  %rax,%rcx
 10c1312:	48 89 4d 80          	mov    %rcx,-0x80(%rbp)
 10c1316:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c131a:	48 8b 08             	mov    (%rax),%rcx
 10c131d:	48 89 8d 00 ff ff ff 	mov    %rcx,-0x100(%rbp)
 10c1324:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c1328:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 10c132f:	48 83 bd 30 ff ff ff 	cmpq   $0x0,-0xd0(%rbp)
 10c1336:	00 
 10c1337:	74 41                	je     10c137a <zstd.emitBestSequenceCompressedBlock+0x1b3a>
 10c1339:	31 c0                	xor    %eax,%eax
 10c133b:	84 c0                	test   %al,%al
 10c133d:	75 3b                	jne    10c137a <zstd.emitBestSequenceCompressedBlock+0x1b3a>
 10c133f:	48 8b bd 00 ff ff ff 	mov    -0x100(%rbp),%rdi
 10c1346:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 10c134d:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 10c1354:	31 c9                	xor    %ecx,%ecx
 10c1356:	4c 8b 45 80          	mov    -0x80(%rbp),%r8
 10c135a:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c135e:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c1365:	ff 50 10             	call   *0x10(%rax)
 10c1368:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 10c136f:	48 85 c0             	test   %rax,%rax
 10c1372:	74 06                	je     10c137a <zstd.emitBestSequenceCompressedBlock+0x1b3a>
 10c1374:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 10c1378:	eb 0d                	jmp    10c1387 <zstd.emitBestSequenceCompressedBlock+0x1b47>
 10c137a:	48 c7 85 78 ff ff ff 	movq   $0x0,-0x88(%rbp)
 10c1381:	00 00 00 00 
 10c1385:	31 c0                	xor    %eax,%eax
 10c1387:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10c138e:	00 
 10c138f:	74 09                	je     10c139a <zstd.emitBestSequenceCompressedBlock+0x1b5a>
 10c1391:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 10c1395:	e9 86 00 00 00       	jmp    10c1420 <zstd.emitBestSequenceCompressedBlock+0x1be0>
 10c139a:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c13a0:	31 c0                	xor    %eax,%eax
 10c13a2:	84 c0                	test   %al,%al
 10c13a4:	0f 85 84 0f 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c13aa:	48 8b bd 00 ff ff ff 	mov    -0x100(%rbp),%rdi
 10c13b1:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 10c13b5:	31 d2                	xor    %edx,%edx
 10c13b7:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c13bb:	4c 89 e1             	mov    %r12,%rcx
 10c13be:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c13c5:	ff 10                	call   *(%rax)
 10c13c7:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 10c13ce:	48 85 c0             	test   %rax,%rax
 10c13d1:	0f 84 5b 0f 00 00    	je     10c2332 <zstd.emitBestSequenceCompressedBlock+0x2af2>
 10c13d7:	48 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%rdi
 10c13de:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 10c13e5:	48 8b 95 f8 fe ff ff 	mov    -0x108(%rbp),%rdx
 10c13ec:	e8 cf c0 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c13f1:	48 83 bd 30 ff ff ff 	cmpq   $0x0,-0xd0(%rbp)
 10c13f8:	00 
 10c13f9:	74 25                	je     10c1420 <zstd.emitBestSequenceCompressedBlock+0x1be0>
 10c13fb:	48 8b bd 00 ff ff ff 	mov    -0x100(%rbp),%rdi
 10c1402:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 10c1409:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 10c1410:	31 c9                	xor    %ecx,%ecx
 10c1412:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c1416:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c141d:	ff 50 18             	call   *0x18(%rax)
 10c1420:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 10c1427:	48 89 8d 40 ff ff ff 	mov    %rcx,-0xc0(%rbp)
 10c142e:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 10c1432:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 10c1439:	48 89 8d 28 ff ff ff 	mov    %rcx,-0xd8(%rbp)
 10c1440:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 10c1444:	89 c8                	mov    %ecx,%eax
 10c1446:	c1 e8 08             	shr    $0x8,%eax
 10c1449:	48 8b 95 60 ff ff ff 	mov    -0xa0(%rbp),%rdx
 10c1450:	48 89 95 48 ff ff ff 	mov    %rdx,-0xb8(%rbp)
 10c1457:	48 8b 95 f8 fe ff ff 	mov    -0x108(%rbp),%rdx
 10c145e:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 10c1465:	88 04 16             	mov    %al,(%rsi,%rdx,1)
 10c1468:	48 c1 e9 10          	shr    $0x10,%rcx
 10c146c:	48 89 4d c0          	mov    %rcx,-0x40(%rbp)
 10c1470:	80 c3 f2             	add    $0xf2,%bl
 10c1473:	42 0f bf b4 6d b0 fd 	movswl -0x250(%rbp,%r13,2),%esi
 10c147a:	ff ff 
 10c147c:	44 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%r8d
 10c1483:	44 89 c0             	mov    %r8d,%eax
 10c1486:	f7 d0                	not    %eax
 10c1488:	42 8d 0c 78          	lea    (%rax,%r15,2),%ecx
 10c148c:	89 f2                	mov    %esi,%edx
 10c148e:	f7 da                	neg    %edx
 10c1490:	0f 49 d6             	cmovns %esi,%edx
 10c1493:	ff c6                	inc    %esi
 10c1495:	44 39 fe             	cmp    %r15d,%esi
 10c1498:	89 c8                	mov    %ecx,%eax
 10c149a:	bf 00 00 00 00       	mov    $0x0,%edi
 10c149f:	0f 4c c7             	cmovl  %edi,%eax
 10c14a2:	01 f0                	add    %esi,%eax
 10c14a4:	0f 88 7e 0e 00 00    	js     10c2328 <zstd.emitBestSequenceCompressedBlock+0x2ae8>
 10c14aa:	41 01 d0             	add    %edx,%r8d
 10c14ad:	39 c8                	cmp    %ecx,%eax
 10c14af:	0f 9c c1             	setl   %cl
 10c14b2:	83 f8 01             	cmp    $0x1,%eax
 10c14b5:	0f 94 c2             	sete   %dl
 10c14b8:	48 89 95 28 ff ff ff 	mov    %rdx,-0xd8(%rbp)
 10c14bf:	45 85 c0             	test   %r8d,%r8d
 10c14c2:	0f 8e 60 0e 00 00    	jle    10c2328 <zstd.emitBestSequenceCompressedBlock+0x2ae8>
 10c14c8:	44 89 f2             	mov    %r14d,%edx
 10c14cb:	45 39 f8             	cmp    %r15d,%r8d
 10c14ce:	7d 0b                	jge    10c14db <zstd.emitBestSequenceCompressedBlock+0x1c9b>
 10c14d0:	41 fe ce             	dec    %r14b
 10c14d3:	41 d1 ef             	shr    %r15d
 10c14d6:	45 39 f8             	cmp    %r15d,%r8d
 10c14d9:	72 f5                	jb     10c14d0 <zstd.emitBestSequenceCompressedBlock+0x1c90>
 10c14db:	44 89 85 70 ff ff ff 	mov    %r8d,-0x90(%rbp)
 10c14e2:	89 c0                	mov    %eax,%eax
 10c14e4:	c4 e2 e1 f7 c0       	shlx   %rbx,%rax,%rax
 10c14e9:	48 01 45 c0          	add    %rax,-0x40(%rbp)
 10c14ed:	00 da                	add    %bl,%dl
 10c14ef:	89 d3                	mov    %edx,%ebx
 10c14f1:	28 cb                	sub    %cl,%bl
 10c14f3:	80 fb 10             	cmp    $0x10,%bl
 10c14f6:	0f 86 6c 03 00 00    	jbe    10c1868 <zstd.emitBestSequenceCompressedBlock+0x2028>
 10c14fc:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10c1503:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 10c150a:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 10c1511:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c1518:	48 8d 41 01          	lea    0x1(%rcx),%rax
 10c151c:	48 89 85 f8 fe ff ff 	mov    %rax,-0x108(%rbp)
 10c1523:	48 89 8d 30 ff ff ff 	mov    %rcx,-0xd0(%rbp)
 10c152a:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 10c1531:	48 39 ca             	cmp    %rcx,%rdx
 10c1534:	0f 87 4d 01 00 00    	ja     10c1687 <zstd.emitBestSequenceCompressedBlock+0x1e47>
 10c153a:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 10c1541:	48 89 c1             	mov    %rax,%rcx
 10c1544:	48 d1 e9             	shr    %rcx
 10c1547:	48 83 e9 80          	sub    $0xffffffffffffff80,%rcx
 10c154b:	48 01 c1             	add    %rax,%rcx
 10c154e:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10c1555:	48 0f 42 c8          	cmovb  %rax,%rcx
 10c1559:	48 89 8d 38 ff ff ff 	mov    %rcx,-0xc8(%rbp)
 10c1560:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c1564:	48 8b 08             	mov    (%rax),%rcx
 10c1567:	48 89 8d 80 fe ff ff 	mov    %rcx,-0x180(%rbp)
 10c156e:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c1572:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 10c1579:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10c1580:	00 
 10c1581:	74 44                	je     10c15c7 <zstd.emitBestSequenceCompressedBlock+0x1d87>
 10c1583:	31 c0                	xor    %eax,%eax
 10c1585:	84 c0                	test   %al,%al
 10c1587:	75 3e                	jne    10c15c7 <zstd.emitBestSequenceCompressedBlock+0x1d87>
 10c1589:	48 8b bd 80 fe ff ff 	mov    -0x180(%rbp),%rdi
 10c1590:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 10c1597:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 10c159e:	31 c9                	xor    %ecx,%ecx
 10c15a0:	4c 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%r8
 10c15a7:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c15ab:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 10c15b2:	ff 50 10             	call   *0x10(%rax)
 10c15b5:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 10c15b9:	48 85 c0             	test   %rax,%rax
 10c15bc:	74 09                	je     10c15c7 <zstd.emitBestSequenceCompressedBlock+0x1d87>
 10c15be:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c15c5:	eb 0a                	jmp    10c15d1 <zstd.emitBestSequenceCompressedBlock+0x1d91>
 10c15c7:	48 c7 45 80 00 00 00 	movq   $0x0,-0x80(%rbp)
 10c15ce:	00 
 10c15cf:	31 c0                	xor    %eax,%eax
 10c15d1:	48 83 7d 80 00       	cmpq   $0x0,-0x80(%rbp)
 10c15d6:	74 0c                	je     10c15e4 <zstd.emitBestSequenceCompressedBlock+0x1da4>
 10c15d8:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 10c15df:	e9 83 00 00 00       	jmp    10c1667 <zstd.emitBestSequenceCompressedBlock+0x1e27>
 10c15e4:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c15ea:	31 c0                	xor    %eax,%eax
 10c15ec:	84 c0                	test   %al,%al
 10c15ee:	0f 85 3a 0d 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c15f4:	48 8b bd 80 fe ff ff 	mov    -0x180(%rbp),%rdi
 10c15fb:	48 8b b5 38 ff ff ff 	mov    -0xc8(%rbp),%rsi
 10c1602:	31 d2                	xor    %edx,%edx
 10c1604:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c1608:	4c 89 e1             	mov    %r12,%rcx
 10c160b:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 10c1612:	ff 10                	call   *(%rax)
 10c1614:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 10c1618:	48 85 c0             	test   %rax,%rax
 10c161b:	0f 84 11 0d 00 00    	je     10c2332 <zstd.emitBestSequenceCompressedBlock+0x2af2>
 10c1621:	48 8b 7d 80          	mov    -0x80(%rbp),%rdi
 10c1625:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 10c162c:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 10c1633:	e8 88 be 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c1638:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10c163f:	00 
 10c1640:	74 25                	je     10c1667 <zstd.emitBestSequenceCompressedBlock+0x1e27>
 10c1642:	48 8b bd 80 fe ff ff 	mov    -0x180(%rbp),%rdi
 10c1649:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 10c1650:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 10c1657:	31 c9                	xor    %ecx,%ecx
 10c1659:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c165d:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 10c1664:	ff 50 18             	call   *0x18(%rax)
 10c1667:	48 8b 4d 80          	mov    -0x80(%rbp),%rcx
 10c166b:	48 89 8d 40 ff ff ff 	mov    %rcx,-0xc0(%rbp)
 10c1672:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c1679:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 10c1680:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 10c1687:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 10c168e:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 10c1695:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 10c1699:	48 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%rcx
 10c16a0:	48 8b 95 60 ff ff ff 	mov    -0xa0(%rbp),%rdx
 10c16a7:	88 04 0a             	mov    %al,(%rdx,%rcx,1)
 10c16aa:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10c16b1:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 10c16b8:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 10c16bf:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c16c6:	48 8d 41 01          	lea    0x1(%rcx),%rax
 10c16ca:	48 89 85 f8 fe ff ff 	mov    %rax,-0x108(%rbp)
 10c16d1:	48 89 8d 30 ff ff ff 	mov    %rcx,-0xd0(%rbp)
 10c16d8:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 10c16df:	48 39 ca             	cmp    %rcx,%rdx
 10c16e2:	0f 87 4d 01 00 00    	ja     10c1835 <zstd.emitBestSequenceCompressedBlock+0x1ff5>
 10c16e8:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 10c16ef:	48 89 c1             	mov    %rax,%rcx
 10c16f2:	48 d1 e9             	shr    %rcx
 10c16f5:	48 83 e9 80          	sub    $0xffffffffffffff80,%rcx
 10c16f9:	48 01 c1             	add    %rax,%rcx
 10c16fc:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10c1703:	48 0f 42 c8          	cmovb  %rax,%rcx
 10c1707:	48 89 8d 38 ff ff ff 	mov    %rcx,-0xc8(%rbp)
 10c170e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c1712:	48 8b 08             	mov    (%rax),%rcx
 10c1715:	48 89 8d 80 fe ff ff 	mov    %rcx,-0x180(%rbp)
 10c171c:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c1720:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 10c1727:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10c172e:	00 
 10c172f:	74 44                	je     10c1775 <zstd.emitBestSequenceCompressedBlock+0x1f35>
 10c1731:	31 c0                	xor    %eax,%eax
 10c1733:	84 c0                	test   %al,%al
 10c1735:	75 3e                	jne    10c1775 <zstd.emitBestSequenceCompressedBlock+0x1f35>
 10c1737:	48 8b bd 80 fe ff ff 	mov    -0x180(%rbp),%rdi
 10c173e:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 10c1745:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 10c174c:	31 c9                	xor    %ecx,%ecx
 10c174e:	4c 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%r8
 10c1755:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c1759:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 10c1760:	ff 50 10             	call   *0x10(%rax)
 10c1763:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 10c1767:	48 85 c0             	test   %rax,%rax
 10c176a:	74 09                	je     10c1775 <zstd.emitBestSequenceCompressedBlock+0x1f35>
 10c176c:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c1773:	eb 0a                	jmp    10c177f <zstd.emitBestSequenceCompressedBlock+0x1f3f>
 10c1775:	48 c7 45 80 00 00 00 	movq   $0x0,-0x80(%rbp)
 10c177c:	00 
 10c177d:	31 c0                	xor    %eax,%eax
 10c177f:	48 83 7d 80 00       	cmpq   $0x0,-0x80(%rbp)
 10c1784:	74 0c                	je     10c1792 <zstd.emitBestSequenceCompressedBlock+0x1f52>
 10c1786:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 10c178d:	e9 83 00 00 00       	jmp    10c1815 <zstd.emitBestSequenceCompressedBlock+0x1fd5>
 10c1792:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c1798:	31 c0                	xor    %eax,%eax
 10c179a:	84 c0                	test   %al,%al
 10c179c:	0f 85 8c 0b 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c17a2:	48 8b bd 80 fe ff ff 	mov    -0x180(%rbp),%rdi
 10c17a9:	48 8b b5 38 ff ff ff 	mov    -0xc8(%rbp),%rsi
 10c17b0:	31 d2                	xor    %edx,%edx
 10c17b2:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c17b6:	4c 89 e1             	mov    %r12,%rcx
 10c17b9:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 10c17c0:	ff 10                	call   *(%rax)
 10c17c2:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 10c17c6:	48 85 c0             	test   %rax,%rax
 10c17c9:	0f 84 63 0b 00 00    	je     10c2332 <zstd.emitBestSequenceCompressedBlock+0x2af2>
 10c17cf:	48 8b 7d 80          	mov    -0x80(%rbp),%rdi
 10c17d3:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 10c17da:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 10c17e1:	e8 da bc 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c17e6:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10c17ed:	00 
 10c17ee:	74 25                	je     10c1815 <zstd.emitBestSequenceCompressedBlock+0x1fd5>
 10c17f0:	48 8b bd 80 fe ff ff 	mov    -0x180(%rbp),%rdi
 10c17f7:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 10c17fe:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 10c1805:	31 c9                	xor    %ecx,%ecx
 10c1807:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c180b:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 10c1812:	ff 50 18             	call   *0x18(%rax)
 10c1815:	48 8b 4d 80          	mov    -0x80(%rbp),%rcx
 10c1819:	48 89 8d 40 ff ff ff 	mov    %rcx,-0xc0(%rbp)
 10c1820:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10c1827:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 10c182e:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 10c1835:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 10c1839:	89 c8                	mov    %ecx,%eax
 10c183b:	c1 e8 08             	shr    $0x8,%eax
 10c183e:	48 8b 95 f8 fe ff ff 	mov    -0x108(%rbp),%rdx
 10c1845:	48 89 95 48 ff ff ff 	mov    %rdx,-0xb8(%rbp)
 10c184c:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 10c1853:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 10c185a:	88 04 16             	mov    %al,(%rsi,%rdx,1)
 10c185d:	48 c1 e9 10          	shr    $0x10,%rcx
 10c1861:	48 89 4d c0          	mov    %rcx,-0x40(%rbp)
 10c1865:	80 c3 f0             	add    $0xf0,%bl
 10c1868:	4c 3b ad 70 fe ff ff 	cmp    -0x190(%rbp),%r13
 10c186f:	8b 95 70 ff ff ff    	mov    -0x90(%rbp),%edx
 10c1875:	48 8b 8d 28 ff ff ff 	mov    -0xd8(%rbp),%rcx
 10c187c:	73 0f                	jae    10c188d <zstd.emitBestSequenceCompressedBlock+0x204d>
 10c187e:	49 ff c5             	inc    %r13
 10c1881:	4c 89 e8             	mov    %r13,%rax
 10c1884:	83 fa 01             	cmp    $0x1,%edx
 10c1887:	0f 85 ca f7 ff ff    	jne    10c1057 <zstd.emitBestSequenceCompressedBlock+0x1817>
 10c188d:	66 c7 45 b0 3b 00    	movw   $0x3b,-0x50(%rbp)
 10c1893:	83 fa 01             	cmp    $0x1,%edx
 10c1896:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c189a:	0f 85 92 0a 00 00    	jne    10c2332 <zstd.emitBestSequenceCompressedBlock+0x2af2>
 10c18a0:	84 db                	test   %bl,%bl
 10c18a2:	0f 84 e6 02 00 00    	je     10c1b8e <zstd.emitBestSequenceCompressedBlock+0x234e>
 10c18a8:	44 0f b6 f3          	movzbl %bl,%r14d
 10c18ac:	41 83 c6 07          	add    $0x7,%r14d
 10c18b0:	41 c1 ee 03          	shr    $0x3,%r14d
 10c18b4:	e9 3c 01 00 00       	jmp    10c19f5 <zstd.emitBestSequenceCompressedBlock+0x21b5>
 10c18b9:	48 8b 95 a0 fe ff ff 	mov    -0x160(%rbp),%rdx
 10c18c0:	81 e2 f8 00 00 00    	and    $0xf8,%edx
 10c18c6:	31 c9                	xor    %ecx,%ecx
 10c18c8:	31 c0                	xor    %eax,%eax
 10c18ca:	eb 0d                	jmp    10c18d9 <zstd.emitBestSequenceCompressedBlock+0x2099>
 10c18cc:	48 83 c1 08          	add    $0x8,%rcx
 10c18d0:	48 39 ca             	cmp    %rcx,%rdx
 10c18d3:	0f 84 bc f6 ff ff    	je     10c0f95 <zstd.emitBestSequenceCompressedBlock+0x1755>
 10c18d9:	8b b4 8d d0 fd ff ff 	mov    -0x230(%rbp,%rcx,4),%esi
 10c18e0:	39 f0                	cmp    %esi,%eax
 10c18e2:	77 57                	ja     10c193b <zstd.emitBestSequenceCompressedBlock+0x20fb>
 10c18e4:	89 f0                	mov    %esi,%eax
 10c18e6:	8b b4 8d d4 fd ff ff 	mov    -0x22c(%rbp,%rcx,4),%esi
 10c18ed:	39 f0                	cmp    %esi,%eax
 10c18ef:	76 55                	jbe    10c1946 <zstd.emitBestSequenceCompressedBlock+0x2106>
 10c18f1:	8b b4 8d d8 fd ff ff 	mov    -0x228(%rbp,%rcx,4),%esi
 10c18f8:	39 f0                	cmp    %esi,%eax
 10c18fa:	77 57                	ja     10c1953 <zstd.emitBestSequenceCompressedBlock+0x2113>
 10c18fc:	89 f0                	mov    %esi,%eax
 10c18fe:	8b b4 8d dc fd ff ff 	mov    -0x224(%rbp,%rcx,4),%esi
 10c1905:	39 f0                	cmp    %esi,%eax
 10c1907:	76 55                	jbe    10c195e <zstd.emitBestSequenceCompressedBlock+0x211e>
 10c1909:	8b b4 8d e0 fd ff ff 	mov    -0x220(%rbp,%rcx,4),%esi
 10c1910:	39 f0                	cmp    %esi,%eax
 10c1912:	77 57                	ja     10c196b <zstd.emitBestSequenceCompressedBlock+0x212b>
 10c1914:	89 f0                	mov    %esi,%eax
 10c1916:	8b b4 8d e4 fd ff ff 	mov    -0x21c(%rbp,%rcx,4),%esi
 10c191d:	39 f0                	cmp    %esi,%eax
 10c191f:	76 55                	jbe    10c1976 <zstd.emitBestSequenceCompressedBlock+0x2136>
 10c1921:	8b b4 8d e8 fd ff ff 	mov    -0x218(%rbp,%rcx,4),%esi
 10c1928:	39 f0                	cmp    %esi,%eax
 10c192a:	77 57                	ja     10c1983 <zstd.emitBestSequenceCompressedBlock+0x2143>
 10c192c:	89 f0                	mov    %esi,%eax
 10c192e:	8b b4 8d ec fd ff ff 	mov    -0x214(%rbp,%rcx,4),%esi
 10c1935:	39 f0                	cmp    %esi,%eax
 10c1937:	77 93                	ja     10c18cc <zstd.emitBestSequenceCompressedBlock+0x208c>
 10c1939:	eb 57                	jmp    10c1992 <zstd.emitBestSequenceCompressedBlock+0x2152>
 10c193b:	8b b4 8d d4 fd ff ff 	mov    -0x22c(%rbp,%rcx,4),%esi
 10c1942:	39 f0                	cmp    %esi,%eax
 10c1944:	77 ab                	ja     10c18f1 <zstd.emitBestSequenceCompressedBlock+0x20b1>
 10c1946:	89 f0                	mov    %esi,%eax
 10c1948:	8b b4 8d d8 fd ff ff 	mov    -0x228(%rbp,%rcx,4),%esi
 10c194f:	39 f0                	cmp    %esi,%eax
 10c1951:	76 a9                	jbe    10c18fc <zstd.emitBestSequenceCompressedBlock+0x20bc>
 10c1953:	8b b4 8d dc fd ff ff 	mov    -0x224(%rbp,%rcx,4),%esi
 10c195a:	39 f0                	cmp    %esi,%eax
 10c195c:	77 ab                	ja     10c1909 <zstd.emitBestSequenceCompressedBlock+0x20c9>
 10c195e:	89 f0                	mov    %esi,%eax
 10c1960:	8b b4 8d e0 fd ff ff 	mov    -0x220(%rbp,%rcx,4),%esi
 10c1967:	39 f0                	cmp    %esi,%eax
 10c1969:	76 a9                	jbe    10c1914 <zstd.emitBestSequenceCompressedBlock+0x20d4>
 10c196b:	8b b4 8d e4 fd ff ff 	mov    -0x21c(%rbp,%rcx,4),%esi
 10c1972:	39 f0                	cmp    %esi,%eax
 10c1974:	77 ab                	ja     10c1921 <zstd.emitBestSequenceCompressedBlock+0x20e1>
 10c1976:	89 f0                	mov    %esi,%eax
 10c1978:	8b b4 8d e8 fd ff ff 	mov    -0x218(%rbp,%rcx,4),%esi
 10c197f:	39 f0                	cmp    %esi,%eax
 10c1981:	76 a9                	jbe    10c192c <zstd.emitBestSequenceCompressedBlock+0x20ec>
 10c1983:	8b b4 8d ec fd ff ff 	mov    -0x214(%rbp,%rcx,4),%esi
 10c198a:	39 f0                	cmp    %esi,%eax
 10c198c:	0f 87 3a ff ff ff    	ja     10c18cc <zstd.emitBestSequenceCompressedBlock+0x208c>
 10c1992:	89 f0                	mov    %esi,%eax
 10c1994:	e9 33 ff ff ff       	jmp    10c18cc <zstd.emitBestSequenceCompressedBlock+0x208c>
 10c1999:	45 31 ed             	xor    %r13d,%r13d
 10c199c:	31 c0                	xor    %eax,%eax
 10c199e:	4d 85 ed             	test   %r13,%r13
 10c19a1:	0f 84 8d 01 00 00    	je     10c1b34 <zstd.emitBestSequenceCompressedBlock+0x22f4>
 10c19a7:	49 89 c7             	mov    %rax,%r15
 10c19aa:	e9 47 f4 ff ff       	jmp    10c0df6 <zstd.emitBestSequenceCompressedBlock+0x15b6>
 10c19af:	49 89 c7             	mov    %rax,%r15
 10c19b2:	48 89 9d 40 ff ff ff 	mov    %rbx,-0xc0(%rbp)
 10c19b9:	4c 89 bd 50 ff ff ff 	mov    %r15,-0xb0(%rbp)
 10c19c0:	48 89 9d 70 ff ff ff 	mov    %rbx,-0x90(%rbp)
 10c19c7:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 10c19ce:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 10c19d5:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 10c19d9:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 10c19e0:	42 88 04 29          	mov    %al,(%rcx,%r13,1)
 10c19e4:	48 c1 e8 08          	shr    $0x8,%rax
 10c19e8:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 10c19ec:	49 ff ce             	dec    %r14
 10c19ef:	0f 84 99 01 00 00    	je     10c1b8e <zstd.emitBestSequenceCompressedBlock+0x234e>
 10c19f5:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10c19fc:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 10c1a03:	4c 8b ad 48 ff ff ff 	mov    -0xb8(%rbp),%r13
 10c1a0a:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 10c1a11:	49 8d 45 01          	lea    0x1(%r13),%rax
 10c1a15:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 10c1a1c:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 10c1a23:	4c 39 e9             	cmp    %r13,%rcx
 10c1a26:	77 9f                	ja     10c19c7 <zstd.emitBestSequenceCompressedBlock+0x2187>
 10c1a28:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 10c1a2f:	49 89 c7             	mov    %rax,%r15
 10c1a32:	49 d1 ef             	shr    %r15
 10c1a35:	49 83 ef 80          	sub    $0xffffffffffffff80,%r15
 10c1a39:	49 01 c7             	add    %rax,%r15
 10c1a3c:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10c1a43:	4c 0f 42 f8          	cmovb  %rax,%r15
 10c1a47:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c1a4b:	48 8b 08             	mov    (%rax),%rcx
 10c1a4e:	48 89 8d 30 ff ff ff 	mov    %rcx,-0xd0(%rbp)
 10c1a55:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c1a59:	48 89 85 f8 fe ff ff 	mov    %rax,-0x108(%rbp)
 10c1a60:	48 83 bd 60 ff ff ff 	cmpq   $0x0,-0xa0(%rbp)
 10c1a67:	00 
 10c1a68:	74 3b                	je     10c1aa5 <zstd.emitBestSequenceCompressedBlock+0x2265>
 10c1a6a:	31 c0                	xor    %eax,%eax
 10c1a6c:	84 c0                	test   %al,%al
 10c1a6e:	75 35                	jne    10c1aa5 <zstd.emitBestSequenceCompressedBlock+0x2265>
 10c1a70:	48 8b bd 30 ff ff ff 	mov    -0xd0(%rbp),%rdi
 10c1a77:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 10c1a7e:	48 8b 95 60 ff ff ff 	mov    -0xa0(%rbp),%rdx
 10c1a85:	31 c9                	xor    %ecx,%ecx
 10c1a87:	4d 89 f8             	mov    %r15,%r8
 10c1a8a:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c1a8e:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 10c1a95:	ff 50 10             	call   *0x10(%rax)
 10c1a98:	48 85 c0             	test   %rax,%rax
 10c1a9b:	74 08                	je     10c1aa5 <zstd.emitBestSequenceCompressedBlock+0x2265>
 10c1a9d:	48 89 c3             	mov    %rax,%rbx
 10c1aa0:	4c 89 f8             	mov    %r15,%rax
 10c1aa3:	eb 04                	jmp    10c1aa9 <zstd.emitBestSequenceCompressedBlock+0x2269>
 10c1aa5:	31 db                	xor    %ebx,%ebx
 10c1aa7:	31 c0                	xor    %eax,%eax
 10c1aa9:	48 85 db             	test   %rbx,%rbx
 10c1aac:	0f 85 fd fe ff ff    	jne    10c19af <zstd.emitBestSequenceCompressedBlock+0x216f>
 10c1ab2:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c1ab8:	31 c0                	xor    %eax,%eax
 10c1aba:	84 c0                	test   %al,%al
 10c1abc:	0f 85 6c 08 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1ac2:	48 8b bd 30 ff ff ff 	mov    -0xd0(%rbp),%rdi
 10c1ac9:	4c 89 fe             	mov    %r15,%rsi
 10c1acc:	31 d2                	xor    %edx,%edx
 10c1ace:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c1ad2:	4c 89 e1             	mov    %r12,%rcx
 10c1ad5:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 10c1adc:	ff 10                	call   *(%rax)
 10c1ade:	48 85 c0             	test   %rax,%rax
 10c1ae1:	0f 84 4b 08 00 00    	je     10c2332 <zstd.emitBestSequenceCompressedBlock+0x2af2>
 10c1ae7:	48 89 c3             	mov    %rax,%rbx
 10c1aea:	48 89 c7             	mov    %rax,%rdi
 10c1aed:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 10c1af4:	4c 89 ea             	mov    %r13,%rdx
 10c1af7:	e8 c4 b9 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c1afc:	48 83 bd 60 ff ff ff 	cmpq   $0x0,-0xa0(%rbp)
 10c1b03:	00 
 10c1b04:	0f 84 a8 fe ff ff    	je     10c19b2 <zstd.emitBestSequenceCompressedBlock+0x2172>
 10c1b0a:	48 8b bd 30 ff ff ff 	mov    -0xd0(%rbp),%rdi
 10c1b11:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 10c1b18:	48 8b 95 60 ff ff ff 	mov    -0xa0(%rbp),%rdx
 10c1b1f:	31 c9                	xor    %ecx,%ecx
 10c1b21:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c1b25:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 10c1b2c:	ff 50 18             	call   *0x18(%rax)
 10c1b2f:	e9 7e fe ff ff       	jmp    10c19b2 <zstd.emitBestSequenceCompressedBlock+0x2172>
 10c1b34:	31 c0                	xor    %eax,%eax
 10c1b36:	84 c0                	test   %al,%al
 10c1b38:	0f 85 24 0b 00 00    	jne    10c2662 <zstd.emitBestSequenceCompressedBlock+0x2e22>
 10c1b3e:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 10c1b42:	4c 89 fe             	mov    %r15,%rsi
 10c1b45:	31 d2                	xor    %edx,%edx
 10c1b47:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10c1b4b:	c5 f8 77             	vzeroupper 
 10c1b4e:	41 ff 14 24          	call   *(%r12)
 10c1b52:	48 85 c0             	test   %rax,%rax
 10c1b55:	0f 84 07 0b 00 00    	je     10c2662 <zstd.emitBestSequenceCompressedBlock+0x2e22>
 10c1b5b:	49 89 c5             	mov    %rax,%r13
 10c1b5e:	48 83 bd 58 ff ff ff 	cmpq   $0x0,-0xa8(%rbp)
 10c1b65:	00 
 10c1b66:	0f 84 8a f2 ff ff    	je     10c0df6 <zstd.emitBestSequenceCompressedBlock+0x15b6>
 10c1b6c:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 10c1b70:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c1b77:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10c1b7e:	31 c9                	xor    %ecx,%ecx
 10c1b80:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c1b84:	41 ff 54 24 18       	call   *0x18(%r12)
 10c1b89:	e9 68 f2 ff ff       	jmp    10c0df6 <zstd.emitBestSequenceCompressedBlock+0x15b6>
 10c1b8e:	48 8d bd b0 ed ff ff 	lea    -0x1250(%rbp),%rdi
 10c1b95:	48 8d b5 b0 fd ff ff 	lea    -0x250(%rbp),%rsi
 10c1b9c:	48 8b 95 a0 fe ff ff 	mov    -0x160(%rbp),%rdx
 10c1ba3:	48 8b 8d 70 fe ff ff 	mov    -0x190(%rbp),%rcx
 10c1baa:	4c 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%r8
 10c1bb1:	e8 4a 55 00 00       	call   10c7100 <zstd.buildFseCompressionTable>
 10c1bb6:	66 89 45 b0          	mov    %ax,-0x50(%rbp)
 10c1bba:	66 85 c0             	test   %ax,%ax
 10c1bbd:	0f 85 6b 07 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1bc3:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 10c1bca:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 10c1bd1:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 10c1bd5:	c5 f8 29 85 50 fe ff 	vmovaps %xmm0,-0x1b0(%rbp)
 10c1bdc:	ff 
 10c1bdd:	48 8b 8d 98 fe ff ff 	mov    -0x168(%rbp),%rcx
 10c1be4:	0f b6 84 0d 9f e4 ff 	movzbl -0x1b61(%rbp,%rcx,1),%eax
 10c1beb:	ff 
 10c1bec:	0f b6 95 b9 f3 ff ff 	movzbl -0xc47(%rbp),%edx
 10c1bf3:	88 55 c0             	mov    %dl,-0x40(%rbp)
 10c1bf6:	f6 c1 01             	test   $0x1,%cl
 10c1bf9:	0f 85 d1 00 00 00    	jne    10c1cd0 <zstd.emitBestSequenceCompressedBlock+0x2490>
 10c1bff:	66 c7 45 b0 3b 00    	movw   $0x3b,-0x50(%rbp)
 10c1c05:	3a 45 c0             	cmp    -0x40(%rbp),%al
 10c1c08:	0f 87 20 07 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1c0e:	8b 8c c5 bc ed ff ff 	mov    -0x1244(%rbp,%rax,8),%ecx
 10c1c15:	8d 91 00 80 00 00    	lea    0x8000(%rcx),%edx
 10c1c1b:	8d b1 ff 7f 01 00    	lea    0x17fff(%rcx),%esi
 10c1c21:	85 d2                	test   %edx,%edx
 10c1c23:	0f 49 f2             	cmovns %edx,%esi
 10c1c26:	89 f2                	mov    %esi,%edx
 10c1c28:	c1 fa 10             	sar    $0x10,%edx
 10c1c2b:	81 e6 00 00 ff ff    	and    $0xffff0000,%esi
 10c1c31:	29 ce                	sub    %ecx,%esi
 10c1c33:	c4 e2 eb f7 ce       	shrx   %rdx,%rsi,%rcx
 10c1c38:	03 8c c5 b8 ed ff ff 	add    -0x1248(%rbp,%rax,8),%ecx
 10c1c3f:	0f 88 e9 06 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1c45:	89 c8                	mov    %ecx,%eax
 10c1c47:	48 8b 8d b0 ed ff ff 	mov    -0x1250(%rbp),%rcx
 10c1c4e:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 10c1c55:	48 39 c1             	cmp    %rax,%rcx
 10c1c58:	0f 86 d0 06 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1c5e:	48 8b 8d 10 fe ff ff 	mov    -0x1f0(%rbp),%rcx
 10c1c65:	0f b6 8c 0d a0 e4 ff 	movzbl -0x1b60(%rbp,%rcx,1),%ecx
 10c1c6c:	ff 
 10c1c6d:	3a 4d c0             	cmp    -0x40(%rbp),%cl
 10c1c70:	0f 87 b8 06 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1c76:	8b 94 cd bc ed ff ff 	mov    -0x1244(%rbp,%rcx,8),%edx
 10c1c7d:	8d b2 00 80 00 00    	lea    0x8000(%rdx),%esi
 10c1c83:	8d ba ff 7f 01 00    	lea    0x17fff(%rdx),%edi
 10c1c89:	85 f6                	test   %esi,%esi
 10c1c8b:	0f 49 fe             	cmovns %esi,%edi
 10c1c8e:	89 fe                	mov    %edi,%esi
 10c1c90:	c1 fe 10             	sar    $0x10,%esi
 10c1c93:	81 e7 00 00 ff ff    	and    $0xffff0000,%edi
 10c1c99:	29 d7                	sub    %edx,%edi
 10c1c9b:	c4 62 cb f7 ff       	shrx   %rsi,%rdi,%r15
 10c1ca0:	44 03 bc cd b8 ed ff 	add    -0x1248(%rbp,%rcx,8),%r15d
 10c1ca7:	ff 
 10c1ca8:	0f 88 80 06 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1cae:	4c 39 bd 70 ff ff ff 	cmp    %r15,-0x90(%rbp)
 10c1cb5:	0f 86 73 06 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1cbb:	44 0f b7 ac 45 b8 ef 	movzwl -0x1048(%rbp,%rax,2),%r13d
 10c1cc2:	ff ff 
 10c1cc4:	4c 8b a5 10 fe ff ff 	mov    -0x1f0(%rbp),%r12
 10c1ccb:	e9 45 01 00 00       	jmp    10c1e15 <zstd.emitBestSequenceCompressedBlock+0x25d5>
 10c1cd0:	66 c7 45 b0 3b 00    	movw   $0x3b,-0x50(%rbp)
 10c1cd6:	3a 45 c0             	cmp    -0x40(%rbp),%al
 10c1cd9:	0f 87 4f 06 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1cdf:	8b 8c c5 bc ed ff ff 	mov    -0x1244(%rbp,%rax,8),%ecx
 10c1ce6:	8d 91 00 80 00 00    	lea    0x8000(%rcx),%edx
 10c1cec:	8d b1 ff 7f 01 00    	lea    0x17fff(%rcx),%esi
 10c1cf2:	85 d2                	test   %edx,%edx
 10c1cf4:	0f 49 f2             	cmovns %edx,%esi
 10c1cf7:	89 f2                	mov    %esi,%edx
 10c1cf9:	c1 fa 10             	sar    $0x10,%edx
 10c1cfc:	81 e6 00 00 ff ff    	and    $0xffff0000,%esi
 10c1d02:	29 ce                	sub    %ecx,%esi
 10c1d04:	c4 e2 eb f7 ce       	shrx   %rdx,%rsi,%rcx
 10c1d09:	03 8c c5 b8 ed ff ff 	add    -0x1248(%rbp,%rax,8),%ecx
 10c1d10:	0f 88 18 06 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1d16:	89 c8                	mov    %ecx,%eax
 10c1d18:	48 8b 8d b0 ed ff ff 	mov    -0x1250(%rbp),%rcx
 10c1d1f:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 10c1d26:	48 39 c1             	cmp    %rax,%rcx
 10c1d29:	0f 86 ff 05 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1d2f:	48 8b 8d 98 fe ff ff 	mov    -0x168(%rbp),%rcx
 10c1d36:	0f b6 8c 0d 9e e4 ff 	movzbl -0x1b62(%rbp,%rcx,1),%ecx
 10c1d3d:	ff 
 10c1d3e:	3a 4d c0             	cmp    -0x40(%rbp),%cl
 10c1d41:	0f 87 e7 05 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1d47:	8b 94 cd bc ed ff ff 	mov    -0x1244(%rbp,%rcx,8),%edx
 10c1d4e:	8d b2 00 80 00 00    	lea    0x8000(%rdx),%esi
 10c1d54:	8d ba ff 7f 01 00    	lea    0x17fff(%rdx),%edi
 10c1d5a:	85 f6                	test   %esi,%esi
 10c1d5c:	0f 49 fe             	cmovns %esi,%edi
 10c1d5f:	89 fe                	mov    %edi,%esi
 10c1d61:	c1 fe 10             	sar    $0x10,%esi
 10c1d64:	81 e7 00 00 ff ff    	and    $0xffff0000,%edi
 10c1d6a:	29 d7                	sub    %edx,%edi
 10c1d6c:	c4 e2 cb f7 d7       	shrx   %rsi,%rdi,%rdx
 10c1d71:	03 94 cd b8 ed ff ff 	add    -0x1248(%rbp,%rcx,8),%edx
 10c1d78:	0f 88 b0 05 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1d7e:	89 d1                	mov    %edx,%ecx
 10c1d80:	48 39 8d 70 ff ff ff 	cmp    %rcx,-0x90(%rbp)
 10c1d87:	0f 86 a1 05 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1d8d:	48 8b 95 18 fe ff ff 	mov    -0x1e8(%rbp),%rdx
 10c1d94:	0f b6 94 15 a0 e4 ff 	movzbl -0x1b60(%rbp,%rdx,1),%edx
 10c1d9b:	ff 
 10c1d9c:	3a 55 c0             	cmp    -0x40(%rbp),%dl
 10c1d9f:	0f 87 89 05 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1da5:	0f b7 9c 45 b8 ef ff 	movzwl -0x1048(%rbp,%rax,2),%ebx
 10c1dac:	ff 
 10c1dad:	44 0f b7 ac 4d b8 ef 	movzwl -0x1048(%rbp,%rcx,2),%r13d
 10c1db4:	ff ff 
 10c1db6:	44 8b bc d5 b8 ed ff 	mov    -0x1248(%rbp,%rdx,8),%r15d
 10c1dbd:	ff 
 10c1dbe:	44 8b b4 d5 bc ed ff 	mov    -0x1244(%rbp,%rdx,8),%r14d
 10c1dc5:	ff 
 10c1dc6:	41 01 de             	add    %ebx,%r14d
 10c1dc9:	41 c1 fe 10          	sar    $0x10,%r14d
 10c1dcd:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c1dd4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c1dd8:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c1ddf:	48 89 d9             	mov    %rbx,%rcx
 10c1de2:	45 89 f0             	mov    %r14d,%r8d
 10c1de5:	e8 a6 41 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c1dea:	66 85 c0             	test   %ax,%ax
 10c1ded:	0f 85 77 14 00 00    	jne    10c326a <zstd.emitBestSequenceCompressedBlock+0x3a2a>
 10c1df3:	c4 e2 8b f7 c3       	shrx   %r14,%rbx,%rax
 10c1df8:	41 01 c7             	add    %eax,%r15d
 10c1dfb:	0f 88 2d 05 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1e01:	4c 8b a5 18 fe ff ff 	mov    -0x1e8(%rbp),%r12
 10c1e08:	4c 39 bd 70 ff ff ff 	cmp    %r15,-0x90(%rbp)
 10c1e0f:	0f 86 19 05 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1e15:	46 0f b7 b4 7d b8 ef 	movzwl -0x1048(%rbp,%r15,2),%r14d
 10c1e1c:	ff ff 
 10c1e1e:	45 0f b7 fd          	movzwl %r13w,%r15d
 10c1e22:	f6 85 98 fe ff ff 02 	testb  $0x2,-0x168(%rbp)
 10c1e29:	0f 85 f2 00 00 00    	jne    10c1f21 <zstd.emitBestSequenceCompressedBlock+0x26e1>
 10c1e2f:	42 0f b6 84 25 9f e4 	movzbl -0x1b61(%rbp,%r12,1),%eax
 10c1e36:	ff ff 
 10c1e38:	66 c7 45 b0 3b 00    	movw   $0x3b,-0x50(%rbp)
 10c1e3e:	3a 45 c0             	cmp    -0x40(%rbp),%al
 10c1e41:	0f 87 e7 04 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1e47:	44 8b ac c5 b8 ed ff 	mov    -0x1248(%rbp,%rax,8),%r13d
 10c1e4e:	ff 
 10c1e4f:	8b 9c c5 bc ed ff ff 	mov    -0x1244(%rbp,%rax,8),%ebx
 10c1e56:	44 01 fb             	add    %r15d,%ebx
 10c1e59:	c1 fb 10             	sar    $0x10,%ebx
 10c1e5c:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c1e63:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c1e67:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c1e6e:	4c 89 f9             	mov    %r15,%rcx
 10c1e71:	41 89 d8             	mov    %ebx,%r8d
 10c1e74:	e8 17 41 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c1e79:	66 85 c0             	test   %ax,%ax
 10c1e7c:	0f 85 e8 13 00 00    	jne    10c326a <zstd.emitBestSequenceCompressedBlock+0x3a2a>
 10c1e82:	c4 c2 e3 f7 c7       	shrx   %rbx,%r15,%rax
 10c1e87:	41 01 c5             	add    %eax,%r13d
 10c1e8a:	0f 88 9e 04 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1e90:	44 89 e8             	mov    %r13d,%eax
 10c1e93:	48 39 85 70 ff ff ff 	cmp    %rax,-0x90(%rbp)
 10c1e9a:	0f 86 8e 04 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1ea0:	42 0f b6 8c 25 9e e4 	movzbl -0x1b62(%rbp,%r12,1),%ecx
 10c1ea7:	ff ff 
 10c1ea9:	3a 4d c0             	cmp    -0x40(%rbp),%cl
 10c1eac:	0f 87 7c 04 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1eb2:	44 0f b7 bc 45 b8 ef 	movzwl -0x1048(%rbp,%rax,2),%r15d
 10c1eb9:	ff ff 
 10c1ebb:	44 8b ac cd b8 ed ff 	mov    -0x1248(%rbp,%rcx,8),%r13d
 10c1ec2:	ff 
 10c1ec3:	8b 9c cd bc ed ff ff 	mov    -0x1244(%rbp,%rcx,8),%ebx
 10c1eca:	44 01 f3             	add    %r14d,%ebx
 10c1ecd:	c1 fb 10             	sar    $0x10,%ebx
 10c1ed0:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c1ed7:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c1edb:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c1ee2:	4c 89 f1             	mov    %r14,%rcx
 10c1ee5:	41 89 d8             	mov    %ebx,%r8d
 10c1ee8:	e8 a3 40 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c1eed:	66 85 c0             	test   %ax,%ax
 10c1ef0:	0f 85 74 13 00 00    	jne    10c326a <zstd.emitBestSequenceCompressedBlock+0x3a2a>
 10c1ef6:	c4 c2 e3 f7 c6       	shrx   %rbx,%r14,%rax
 10c1efb:	41 01 c5             	add    %eax,%r13d
 10c1efe:	0f 88 2a 04 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1f04:	44 89 e8             	mov    %r13d,%eax
 10c1f07:	48 39 85 70 ff ff ff 	cmp    %rax,-0x90(%rbp)
 10c1f0e:	0f 86 1a 04 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1f14:	49 83 c4 fe          	add    $0xfffffffffffffffe,%r12
 10c1f18:	44 0f b7 b4 45 b8 ef 	movzwl -0x1048(%rbp,%rax,2),%r14d
 10c1f1f:	ff ff 
 10c1f21:	4d 85 e4             	test   %r12,%r12
 10c1f24:	0f 84 ea 01 00 00    	je     10c2114 <zstd.emitBestSequenceCompressedBlock+0x28d4>
 10c1f2a:	42 0f b6 84 25 9f e4 	movzbl -0x1b61(%rbp,%r12,1),%eax
 10c1f31:	ff ff 
 10c1f33:	66 c7 45 b0 3b 00    	movw   $0x3b,-0x50(%rbp)
 10c1f39:	3a 45 c0             	cmp    -0x40(%rbp),%al
 10c1f3c:	0f 87 ec 03 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1f42:	44 8b ac c5 b8 ed ff 	mov    -0x1248(%rbp,%rax,8),%r13d
 10c1f49:	ff 
 10c1f4a:	8b 9c c5 bc ed ff ff 	mov    -0x1244(%rbp,%rax,8),%ebx
 10c1f51:	44 01 fb             	add    %r15d,%ebx
 10c1f54:	c1 fb 10             	sar    $0x10,%ebx
 10c1f57:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c1f5e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c1f62:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c1f69:	4c 89 f9             	mov    %r15,%rcx
 10c1f6c:	41 89 d8             	mov    %ebx,%r8d
 10c1f6f:	e8 1c 40 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c1f74:	66 85 c0             	test   %ax,%ax
 10c1f77:	0f 85 ed 12 00 00    	jne    10c326a <zstd.emitBestSequenceCompressedBlock+0x3a2a>
 10c1f7d:	c4 c2 e3 f7 c7       	shrx   %rbx,%r15,%rax
 10c1f82:	41 01 c5             	add    %eax,%r13d
 10c1f85:	0f 88 a3 03 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1f8b:	44 89 e8             	mov    %r13d,%eax
 10c1f8e:	48 39 85 70 ff ff ff 	cmp    %rax,-0x90(%rbp)
 10c1f95:	0f 86 93 03 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1f9b:	42 0f b6 8c 25 9e e4 	movzbl -0x1b62(%rbp,%r12,1),%ecx
 10c1fa2:	ff ff 
 10c1fa4:	3a 4d c0             	cmp    -0x40(%rbp),%cl
 10c1fa7:	0f 87 81 03 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1fad:	44 0f b7 bc 45 b8 ef 	movzwl -0x1048(%rbp,%rax,2),%r15d
 10c1fb4:	ff ff 
 10c1fb6:	44 8b ac cd b8 ed ff 	mov    -0x1248(%rbp,%rcx,8),%r13d
 10c1fbd:	ff 
 10c1fbe:	8b 9c cd bc ed ff ff 	mov    -0x1244(%rbp,%rcx,8),%ebx
 10c1fc5:	44 01 f3             	add    %r14d,%ebx
 10c1fc8:	c1 fb 10             	sar    $0x10,%ebx
 10c1fcb:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c1fd2:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c1fd6:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c1fdd:	4c 89 f1             	mov    %r14,%rcx
 10c1fe0:	41 89 d8             	mov    %ebx,%r8d
 10c1fe3:	e8 a8 3f 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c1fe8:	66 85 c0             	test   %ax,%ax
 10c1feb:	0f 85 79 12 00 00    	jne    10c326a <zstd.emitBestSequenceCompressedBlock+0x3a2a>
 10c1ff1:	c4 c2 e3 f7 c6       	shrx   %rbx,%r14,%rax
 10c1ff6:	41 01 c5             	add    %eax,%r13d
 10c1ff9:	0f 88 2f 03 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c1fff:	44 89 e8             	mov    %r13d,%eax
 10c2002:	48 39 85 70 ff ff ff 	cmp    %rax,-0x90(%rbp)
 10c2009:	0f 86 1f 03 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c200f:	44 0f b7 b4 45 b8 ef 	movzwl -0x1048(%rbp,%rax,2),%r14d
 10c2016:	ff ff 
 10c2018:	49 83 fc 02          	cmp    $0x2,%r12
 10c201c:	0f 84 f2 00 00 00    	je     10c2114 <zstd.emitBestSequenceCompressedBlock+0x28d4>
 10c2022:	42 0f b6 84 25 9d e4 	movzbl -0x1b63(%rbp,%r12,1),%eax
 10c2029:	ff ff 
 10c202b:	3a 45 c0             	cmp    -0x40(%rbp),%al
 10c202e:	0f 87 fa 02 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c2034:	44 8b ac c5 b8 ed ff 	mov    -0x1248(%rbp,%rax,8),%r13d
 10c203b:	ff 
 10c203c:	8b 9c c5 bc ed ff ff 	mov    -0x1244(%rbp,%rax,8),%ebx
 10c2043:	44 01 fb             	add    %r15d,%ebx
 10c2046:	c1 fb 10             	sar    $0x10,%ebx
 10c2049:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c2050:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2054:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c205b:	4c 89 f9             	mov    %r15,%rcx
 10c205e:	41 89 d8             	mov    %ebx,%r8d
 10c2061:	e8 2a 3f 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c2066:	66 85 c0             	test   %ax,%ax
 10c2069:	0f 85 fb 11 00 00    	jne    10c326a <zstd.emitBestSequenceCompressedBlock+0x3a2a>
 10c206f:	c4 c2 e3 f7 c7       	shrx   %rbx,%r15,%rax
 10c2074:	41 01 c5             	add    %eax,%r13d
 10c2077:	0f 88 b1 02 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c207d:	44 89 e8             	mov    %r13d,%eax
 10c2080:	48 39 85 70 ff ff ff 	cmp    %rax,-0x90(%rbp)
 10c2087:	0f 86 a1 02 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c208d:	42 0f b6 8c 25 9c e4 	movzbl -0x1b64(%rbp,%r12,1),%ecx
 10c2094:	ff ff 
 10c2096:	3a 4d c0             	cmp    -0x40(%rbp),%cl
 10c2099:	0f 87 8f 02 00 00    	ja     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c209f:	44 0f b7 bc 45 b8 ef 	movzwl -0x1048(%rbp,%rax,2),%r15d
 10c20a6:	ff ff 
 10c20a8:	44 8b ac cd b8 ed ff 	mov    -0x1248(%rbp,%rcx,8),%r13d
 10c20af:	ff 
 10c20b0:	8b 9c cd bc ed ff ff 	mov    -0x1244(%rbp,%rcx,8),%ebx
 10c20b7:	44 01 f3             	add    %r14d,%ebx
 10c20ba:	c1 fb 10             	sar    $0x10,%ebx
 10c20bd:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c20c4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c20c8:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c20cf:	4c 89 f1             	mov    %r14,%rcx
 10c20d2:	41 89 d8             	mov    %ebx,%r8d
 10c20d5:	e8 b6 3e 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c20da:	66 85 c0             	test   %ax,%ax
 10c20dd:	0f 85 87 11 00 00    	jne    10c326a <zstd.emitBestSequenceCompressedBlock+0x3a2a>
 10c20e3:	c4 c2 e3 f7 c6       	shrx   %rbx,%r14,%rax
 10c20e8:	41 01 c5             	add    %eax,%r13d
 10c20eb:	0f 88 3d 02 00 00    	js     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c20f1:	44 89 e8             	mov    %r13d,%eax
 10c20f4:	48 39 85 70 ff ff ff 	cmp    %rax,-0x90(%rbp)
 10c20fb:	0f 86 2d 02 00 00    	jbe    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c2101:	44 0f b7 b4 45 b8 ef 	movzwl -0x1048(%rbp,%rax,2),%r14d
 10c2108:	ff ff 
 10c210a:	49 83 c4 fc          	add    $0xfffffffffffffffc,%r12
 10c210e:	0f 85 16 fe ff ff    	jne    10c1f2a <zstd.emitBestSequenceCompressedBlock+0x26ea>
 10c2114:	0f b6 9d b8 f3 ff ff 	movzbl -0xc48(%rbp),%ebx
 10c211b:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c2122:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2126:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c212d:	4c 89 f9             	mov    %r15,%rcx
 10c2130:	41 89 d8             	mov    %ebx,%r8d
 10c2133:	e8 58 3e 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c2138:	66 89 45 b0          	mov    %ax,-0x50(%rbp)
 10c213c:	66 85 c0             	test   %ax,%ax
 10c213f:	0f 85 e9 01 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c2145:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 10c214c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2150:	48 8d 95 40 ff ff ff 	lea    -0xc0(%rbp),%rdx
 10c2157:	4c 89 f1             	mov    %r14,%rcx
 10c215a:	41 89 d8             	mov    %ebx,%r8d
 10c215d:	e8 2e 3e 00 00       	call   10c5f90 <zstd.ReverseBitstreamWriter.addBits>
 10c2162:	66 89 45 b0          	mov    %ax,-0x50(%rbp)
 10c2166:	66 85 c0             	test   %ax,%ax
 10c2169:	0f 85 bf 01 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c216f:	4c 8b b5 50 fe ff ff 	mov    -0x1b0(%rbp),%r14
 10c2176:	44 0f b6 bd 58 fe ff 	movzbl -0x1a8(%rbp),%r15d
 10c217d:	ff 
 10c217e:	4d 0f ab fe          	bts    %r15,%r14
 10c2182:	48 8d bd 40 ff ff ff 	lea    -0xc0(%rbp),%rdi
 10c2189:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c218d:	44 89 f2             	mov    %r14d,%edx
 10c2190:	e8 8b 40 00 00       	call   10c6220 <array_list.Aligned(u8,null).append>
 10c2195:	66 89 45 b0          	mov    %ax,-0x50(%rbp)
 10c2199:	66 85 c0             	test   %ax,%ax
 10c219c:	0f 85 8c 01 00 00    	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c21a2:	41 80 ff 08          	cmp    $0x8,%r15b
 10c21a6:	73 19                	jae    10c21c1 <zstd.emitBestSequenceCompressedBlock+0x2981>
 10c21a8:	48 8b 9d 48 ff ff ff 	mov    -0xb8(%rbp),%rbx
 10c21af:	48 3b 9d 28 ff ff ff 	cmp    -0xd8(%rbp),%rbx
 10c21b6:	0f 86 60 ec ff ff    	jbe    10c0e1c <zstd.emitBestSequenceCompressedBlock+0x15dc>
 10c21bc:	e9 af ec ff ff       	jmp    10c0e70 <zstd.emitBestSequenceCompressedBlock+0x1630>
 10c21c1:	41 fe c7             	inc    %r15b
 10c21c4:	eb 39                	jmp    10c21ff <zstd.emitBestSequenceCompressedBlock+0x29bf>
 10c21c6:	49 89 c5             	mov    %rax,%r13
 10c21c9:	48 89 9d 40 ff ff ff 	mov    %rbx,-0xc0(%rbp)
 10c21d0:	4c 89 ad 50 ff ff ff 	mov    %r13,-0xb0(%rbp)
 10c21d7:	48 89 5d c0          	mov    %rbx,-0x40(%rbp)
 10c21db:	49 c1 ee 08          	shr    $0x8,%r14
 10c21df:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 10c21e6:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 10c21ed:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 10c21f1:	46 88 34 20          	mov    %r14b,(%rax,%r12,1)
 10c21f5:	41 80 c7 f8          	add    $0xf8,%r15b
 10c21f9:	41 80 ff 09          	cmp    $0x9,%r15b
 10c21fd:	72 a9                	jb     10c21a8 <zstd.emitBestSequenceCompressedBlock+0x2968>
 10c21ff:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10c2206:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 10c220a:	4c 8b a5 48 ff ff ff 	mov    -0xb8(%rbp),%r12
 10c2211:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 10c2218:	49 8d 44 24 01       	lea    0x1(%r12),%rax
 10c221d:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 10c2224:	48 89 8d a0 fe ff ff 	mov    %rcx,-0x160(%rbp)
 10c222b:	4c 39 e1             	cmp    %r12,%rcx
 10c222e:	77 ab                	ja     10c21db <zstd.emitBestSequenceCompressedBlock+0x299b>
 10c2230:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 10c2237:	49 89 c5             	mov    %rax,%r13
 10c223a:	49 d1 ed             	shr    %r13
 10c223d:	49 83 ed 80          	sub    $0xffffffffffffff80,%r13
 10c2241:	49 01 c5             	add    %rax,%r13
 10c2244:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10c224b:	4c 0f 42 e8          	cmovb  %rax,%r13
 10c224f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2253:	48 8b 08             	mov    (%rax),%rcx
 10c2256:	48 89 8d 78 fe ff ff 	mov    %rcx,-0x188(%rbp)
 10c225d:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2261:	48 89 85 70 fe ff ff 	mov    %rax,-0x190(%rbp)
 10c2268:	48 83 bd a0 fe ff ff 	cmpq   $0x0,-0x160(%rbp)
 10c226f:	00 
 10c2270:	74 38                	je     10c22aa <zstd.emitBestSequenceCompressedBlock+0x2a6a>
 10c2272:	31 c0                	xor    %eax,%eax
 10c2274:	84 c0                	test   %al,%al
 10c2276:	75 32                	jne    10c22aa <zstd.emitBestSequenceCompressedBlock+0x2a6a>
 10c2278:	48 8b bd 78 fe ff ff 	mov    -0x188(%rbp),%rdi
 10c227f:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c2283:	48 8b 95 a0 fe ff ff 	mov    -0x160(%rbp),%rdx
 10c228a:	31 c9                	xor    %ecx,%ecx
 10c228c:	4d 89 e8             	mov    %r13,%r8
 10c228f:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c2293:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 10c229a:	ff 50 10             	call   *0x10(%rax)
 10c229d:	48 85 c0             	test   %rax,%rax
 10c22a0:	74 08                	je     10c22aa <zstd.emitBestSequenceCompressedBlock+0x2a6a>
 10c22a2:	48 89 c3             	mov    %rax,%rbx
 10c22a5:	4c 89 e8             	mov    %r13,%rax
 10c22a8:	eb 04                	jmp    10c22ae <zstd.emitBestSequenceCompressedBlock+0x2a6e>
 10c22aa:	31 db                	xor    %ebx,%ebx
 10c22ac:	31 c0                	xor    %eax,%eax
 10c22ae:	48 85 db             	test   %rbx,%rbx
 10c22b1:	0f 85 0f ff ff ff    	jne    10c21c6 <zstd.emitBestSequenceCompressedBlock+0x2986>
 10c22b7:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c22bd:	31 c0                	xor    %eax,%eax
 10c22bf:	84 c0                	test   %al,%al
 10c22c1:	75 6b                	jne    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c22c3:	48 8b bd 78 fe ff ff 	mov    -0x188(%rbp),%rdi
 10c22ca:	4c 89 ee             	mov    %r13,%rsi
 10c22cd:	31 d2                	xor    %edx,%edx
 10c22cf:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10c22d3:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 10c22da:	ff 10                	call   *(%rax)
 10c22dc:	48 85 c0             	test   %rax,%rax
 10c22df:	74 4d                	je     10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c22e1:	48 89 c3             	mov    %rax,%rbx
 10c22e4:	48 89 c7             	mov    %rax,%rdi
 10c22e7:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c22eb:	4c 89 e2             	mov    %r12,%rdx
 10c22ee:	e8 cd b1 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c22f3:	48 83 bd a0 fe ff ff 	cmpq   $0x0,-0x160(%rbp)
 10c22fa:	00 
 10c22fb:	0f 84 c8 fe ff ff    	je     10c21c9 <zstd.emitBestSequenceCompressedBlock+0x2989>
 10c2301:	48 8b bd 78 fe ff ff 	mov    -0x188(%rbp),%rdi
 10c2308:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c230c:	48 8b 95 a0 fe ff ff 	mov    -0x160(%rbp),%rdx
 10c2313:	31 c9                	xor    %ecx,%ecx
 10c2315:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2319:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 10c2320:	ff 50 18             	call   *0x18(%rax)
 10c2323:	e9 a1 fe ff ff       	jmp    10c21c9 <zstd.emitBestSequenceCompressedBlock+0x2989>
 10c2328:	66 c7 45 b0 3b 00    	movw   $0x3b,-0x50(%rbp)
 10c232e:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c2332:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c2339:	48 85 d2             	test   %rdx,%rdx
 10c233c:	74 1d                	je     10c235b <zstd.emitBestSequenceCompressedBlock+0x2b1b>
 10c233e:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 10c2345:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2349:	48 8b 38             	mov    (%rax),%rdi
 10c234c:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2350:	31 c9                	xor    %ecx,%ecx
 10c2352:	4d 89 e0             	mov    %r12,%r8
 10c2355:	c5 f8 77             	vzeroupper 
 10c2358:	ff 50 18             	call   *0x18(%rax)
 10c235b:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10c2362:	48 85 d2             	test   %rdx,%rdx
 10c2365:	74 1d                	je     10c2384 <zstd.emitBestSequenceCompressedBlock+0x2b44>
 10c2367:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c236b:	48 8b 38             	mov    (%rax),%rdi
 10c236e:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2372:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c2379:	31 c9                	xor    %ecx,%ecx
 10c237b:	4d 89 e0             	mov    %r12,%r8
 10c237e:	c5 f8 77             	vzeroupper 
 10c2381:	ff 50 18             	call   *0x18(%rax)
 10c2384:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 10c2388:	48 85 d2             	test   %rdx,%rdx
 10c238b:	0f 84 b5 0f 00 00    	je     10c3346 <zstd.emitBestSequenceCompressedBlock+0x3b06>
 10c2391:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2395:	48 8b 38             	mov    (%rax),%rdi
 10c2398:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c239c:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c23a0:	31 c9                	xor    %ecx,%ecx
 10c23a2:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c23a6:	4d 89 e0             	mov    %r12,%r8
 10c23a9:	c5 f8 77             	vzeroupper 
 10c23ac:	ff 50 18             	call   *0x18(%rax)
 10c23af:	e9 96 0f 00 00       	jmp    10c334a <zstd.emitBestSequenceCompressedBlock+0x3b0a>
 10c23b4:	48 8b 95 e0 fe ff ff 	mov    -0x120(%rbp),%rdx
 10c23bb:	48 85 d2             	test   %rdx,%rdx
 10c23be:	74 17                	je     10c23d7 <zstd.emitBestSequenceCompressedBlock+0x2b97>
 10c23c0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c23c4:	48 8b 38             	mov    (%rax),%rdi
 10c23c7:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c23cb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 10c23cf:	48 89 de             	mov    %rbx,%rsi
 10c23d2:	31 c9                	xor    %ecx,%ecx
 10c23d4:	ff 50 18             	call   *0x18(%rax)
 10c23d7:	48 8b 85 28 fe ff ff 	mov    -0x1d8(%rbp),%rax
 10c23de:	66 44 89 30          	mov    %r14w,(%rax)
 10c23e2:	e9 90 d6 ff ff       	jmp    10bfa77 <zstd.emitBestSequenceCompressedBlock+0x237>
 10c23e7:	89 c1                	mov    %eax,%ecx
 10c23e9:	e9 2b e2 ff ff       	jmp    10c0619 <zstd.emitBestSequenceCompressedBlock+0xdd9>
 10c23ee:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 10c23f2:	48 89 55 88          	mov    %rdx,-0x78(%rbp)
 10c23f6:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 10c23fa:	0f b6 85 98 e4 ff ff 	movzbl -0x1b68(%rbp),%eax
 10c2401:	84 c0                	test   %al,%al
 10c2403:	74 1a                	je     10c241f <zstd.emitBestSequenceCompressedBlock+0x2bdf>
 10c2405:	48 89 c3             	mov    %rax,%rbx
 10c2408:	e9 32 e8 ff ff       	jmp    10c0c3f <zstd.emitBestSequenceCompressedBlock+0x13ff>
 10c240d:	b8 81 00 00 00       	mov    $0x81,%eax
 10c2412:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 10c2416:	b8 01 00 00 00       	mov    $0x1,%eax
 10c241b:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 10c241f:	45 31 f6             	xor    %r14d,%r14d
 10c2422:	31 db                	xor    %ebx,%ebx
 10c2424:	e9 37 e9 ff ff       	jmp    10c0d60 <zstd.emitBestSequenceCompressedBlock+0x1520>
 10c2429:	48 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%rax
 10c2430:	4c 8d 78 80          	lea    -0x80(%rax),%r15
 10c2434:	49 83 ff 81          	cmp    $0xffffffffffffff81,%r15
 10c2438:	0f 83 37 01 00 00    	jae    10c2575 <zstd.emitBestSequenceCompressedBlock+0x2d35>
 10c243e:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c2445:	48 85 d2             	test   %rdx,%rdx
 10c2448:	74 1e                	je     10c2468 <zstd.emitBestSequenceCompressedBlock+0x2c28>
 10c244a:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 10c2451:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2455:	48 8b 38             	mov    (%rax),%rdi
 10c2458:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c245c:	31 c9                	xor    %ecx,%ecx
 10c245e:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2462:	c5 f8 77             	vzeroupper 
 10c2465:	ff 50 18             	call   *0x18(%rax)
 10c2468:	48 83 bd 58 ff ff ff 	cmpq   $0x0,-0xa8(%rbp)
 10c246f:	00 
 10c2470:	74 25                	je     10c2497 <zstd.emitBestSequenceCompressedBlock+0x2c57>
 10c2472:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2476:	48 8b 38             	mov    (%rax),%rdi
 10c2479:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c247d:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c2484:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10c248b:	31 c9                	xor    %ecx,%ecx
 10c248d:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2491:	c5 f8 77             	vzeroupper 
 10c2494:	ff 50 18             	call   *0x18(%rax)
 10c2497:	48 83 7d a8 00       	cmpq   $0x0,-0x58(%rbp)
 10c249c:	0f 95 c0             	setne  %al
 10c249f:	0a 05 1d db f7 ff    	or     -0x824e3(%rip),%al        # 103ffc2 <__anon_14421+0x2>
 10c24a5:	a8 01                	test   $0x1,%al
 10c24a7:	0f 84 c8 02 00 00    	je     10c2775 <zstd.emitBestSequenceCompressedBlock+0x2f35>
 10c24ad:	41 be 01 00 00 00    	mov    $0x1,%r14d
 10c24b3:	48 c7 85 90 fe ff ff 	movq   $0x0,-0x170(%rbp)
 10c24ba:	00 00 00 00 
 10c24be:	45 31 e4             	xor    %r12d,%r12d
 10c24c1:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 10c24c5:	48 8d 42 ff          	lea    -0x1(%rdx),%rax
 10c24c9:	48 8b 8d 90 fe ff ff 	mov    -0x170(%rbp),%rcx
 10c24d0:	48 39 c8             	cmp    %rcx,%rax
 10c24d3:	41 0f 93 c5          	setae  %r13b
 10c24d7:	44 22 ad 6f ff ff ff 	and    -0x91(%rbp),%r13b
 10c24de:	48 0f 45 d1          	cmovne %rcx,%rdx
 10c24e2:	48 8d bd 30 fe ff ff 	lea    -0x1d0(%rbp),%rdi
 10c24e9:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c24ed:	48 89 d3             	mov    %rdx,%rbx
 10c24f0:	c5 f8 77             	vzeroupper 
 10c24f3:	e8 58 5e 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c24f8:	66 89 45 b0          	mov    %ax,-0x50(%rbp)
 10c24fc:	66 85 c0             	test   %ax,%ax
 10c24ff:	0f 85 02 0e 00 00    	jne    10c3307 <zstd.emitBestSequenceCompressedBlock+0x3ac7>
 10c2505:	45 84 ed             	test   %r13b,%r13b
 10c2508:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c250c:	49 0f 45 f6          	cmovne %r14,%rsi
 10c2510:	48 8b bd 38 fe ff ff 	mov    -0x1c8(%rbp),%rdi
 10c2517:	48 8d 04 1f          	lea    (%rdi,%rbx,1),%rax
 10c251b:	48 89 85 38 fe ff ff 	mov    %rax,-0x1c8(%rbp)
 10c2522:	48 03 bd 30 fe ff ff 	add    -0x1d0(%rbp),%rdi
 10c2529:	48 89 da             	mov    %rbx,%rdx
 10c252c:	e8 8f af 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c2531:	49 83 ff 81          	cmp    $0xffffffffffffff81,%r15
 10c2535:	72 1a                	jb     10c2551 <zstd.emitBestSequenceCompressedBlock+0x2d11>
 10c2537:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c253b:	48 8b 38             	mov    (%rax),%rdi
 10c253e:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2542:	4c 89 f6             	mov    %r14,%rsi
 10c2545:	4c 89 e2             	mov    %r12,%rdx
 10c2548:	31 c9                	xor    %ecx,%ecx
 10c254a:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c254e:	ff 50 18             	call   *0x18(%rax)
 10c2551:	bb ea ff 03 01       	mov    $0x103ffea,%ebx
 10c2556:	e9 1f 02 00 00       	jmp    10c277a <zstd.emitBestSequenceCompressedBlock+0x2f3a>
 10c255b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c255f:	48 8b 38             	mov    (%rax),%rdi
 10c2562:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2566:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c256a:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 10c256e:	31 c9                	xor    %ecx,%ecx
 10c2570:	e9 31 fe ff ff       	jmp    10c23a6 <zstd.emitBestSequenceCompressedBlock+0x2b66>
 10c2575:	31 c0                	xor    %eax,%eax
 10c2577:	84 c0                	test   %al,%al
 10c2579:	0f 85 c3 00 00 00    	jne    10c2642 <zstd.emitBestSequenceCompressedBlock+0x2e02>
 10c257f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2583:	48 8b 38             	mov    (%rax),%rdi
 10c2586:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c258a:	be 81 00 00 00       	mov    $0x81,%esi
 10c258f:	31 d2                	xor    %edx,%edx
 10c2591:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10c2595:	c5 f8 77             	vzeroupper 
 10c2598:	ff 10                	call   *(%rax)
 10c259a:	48 85 c0             	test   %rax,%rax
 10c259d:	0f 84 9f 00 00 00    	je     10c2642 <zstd.emitBestSequenceCompressedBlock+0x2e02>
 10c25a3:	49 89 c6             	mov    %rax,%r14
 10c25a6:	48 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%rax
 10c25ad:	41 88 06             	mov    %al,(%r14)
 10c25b0:	c6 85 b0 ed ff ff 00 	movb   $0x0,-0x1250(%rbp)
 10c25b7:	c6 85 d0 fd ff ff 00 	movb   $0x0,-0x230(%rbp)
 10c25be:	31 c0                	xor    %eax,%eax
 10c25c0:	84 c0                	test   %al,%al
 10c25c2:	0f 84 f8 00 00 00    	je     10c26c0 <zstd.emitBestSequenceCompressedBlock+0x2e80>
 10c25c8:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c25cf:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c25d3:	48 8b 38             	mov    (%rax),%rdi
 10c25d6:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c25da:	48 85 d2             	test   %rdx,%rdx
 10c25dd:	74 1b                	je     10c25fa <zstd.emitBestSequenceCompressedBlock+0x2dba>
 10c25df:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 10c25e6:	31 c9                	xor    %ecx,%ecx
 10c25e8:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c25ec:	ff 50 18             	call   *0x18(%rax)
 10c25ef:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c25f3:	48 8b 38             	mov    (%rax),%rdi
 10c25f6:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c25fa:	48 83 bd 58 ff ff ff 	cmpq   $0x0,-0xa8(%rbp)
 10c2601:	00 
 10c2602:	74 22                	je     10c2626 <zstd.emitBestSequenceCompressedBlock+0x2de6>
 10c2604:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c260b:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10c2612:	31 c9                	xor    %ecx,%ecx
 10c2614:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2618:	ff 50 18             	call   *0x18(%rax)
 10c261b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c261f:	48 8b 38             	mov    (%rax),%rdi
 10c2622:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2626:	ba 81 00 00 00       	mov    $0x81,%edx
 10c262b:	4c 89 f6             	mov    %r14,%rsi
 10c262e:	31 c9                	xor    %ecx,%ecx
 10c2630:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2634:	ff 50 18             	call   *0x18(%rax)
 10c2637:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c263d:	e9 42 fd ff ff       	jmp    10c2384 <zstd.emitBestSequenceCompressedBlock+0x2b44>
 10c2642:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c2649:	48 85 d2             	test   %rdx,%rdx
 10c264c:	74 3a                	je     10c2688 <zstd.emitBestSequenceCompressedBlock+0x2e48>
 10c264e:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 10c2655:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2659:	48 8b 38             	mov    (%rax),%rdi
 10c265c:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2660:	eb 1a                	jmp    10c267c <zstd.emitBestSequenceCompressedBlock+0x2e3c>
 10c2662:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c2669:	48 85 d2             	test   %rdx,%rdx
 10c266c:	74 1a                	je     10c2688 <zstd.emitBestSequenceCompressedBlock+0x2e48>
 10c266e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2672:	48 8b 38             	mov    (%rax),%rdi
 10c2675:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2679:	4c 89 f6             	mov    %r14,%rsi
 10c267c:	31 c9                	xor    %ecx,%ecx
 10c267e:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2682:	c5 f8 77             	vzeroupper 
 10c2685:	ff 50 18             	call   *0x18(%rax)
 10c2688:	66 c7 45 b0 1a 00    	movw   $0x1a,-0x50(%rbp)
 10c268e:	48 83 bd 58 ff ff ff 	cmpq   $0x0,-0xa8(%rbp)
 10c2695:	00 
 10c2696:	0f 84 e8 fc ff ff    	je     10c2384 <zstd.emitBestSequenceCompressedBlock+0x2b44>
 10c269c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c26a0:	48 8b 38             	mov    (%rax),%rdi
 10c26a3:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c26a7:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c26ae:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10c26b5:	31 c9                	xor    %ecx,%ecx
 10c26b7:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c26bb:	e9 be fc ff ff       	jmp    10c237e <zstd.emitBestSequenceCompressedBlock+0x2b3e>
 10c26c0:	4c 89 f7             	mov    %r14,%rdi
 10c26c3:	48 ff c7             	inc    %rdi
 10c26c6:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c26cd:	48 8b 95 90 fe ff ff 	mov    -0x170(%rbp),%rdx
 10c26d4:	e8 e7 ad 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c26d9:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 10c26e0:	48 85 d2             	test   %rdx,%rdx
 10c26e3:	74 1b                	je     10c2700 <zstd.emitBestSequenceCompressedBlock+0x2ec0>
 10c26e5:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 10c26ec:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c26f0:	48 8b 38             	mov    (%rax),%rdi
 10c26f3:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c26f7:	31 c9                	xor    %ecx,%ecx
 10c26f9:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c26fd:	ff 50 18             	call   *0x18(%rax)
 10c2700:	48 83 bd 58 ff ff ff 	cmpq   $0x0,-0xa8(%rbp)
 10c2707:	00 
 10c2708:	74 22                	je     10c272c <zstd.emitBestSequenceCompressedBlock+0x2eec>
 10c270a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c270e:	48 8b 38             	mov    (%rax),%rdi
 10c2711:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2715:	48 8b b5 a8 fe ff ff 	mov    -0x158(%rbp),%rsi
 10c271c:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10c2723:	31 c9                	xor    %ecx,%ecx
 10c2725:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2729:	ff 50 18             	call   *0x18(%rax)
 10c272c:	0f b6 0d b7 d8 f7 ff 	movzbl -0x82749(%rip),%ecx        # 103ffea <__anon_23972+0x2>
 10c2733:	48 83 7d a8 00       	cmpq   $0x0,-0x58(%rbp)
 10c2738:	0f 95 c0             	setne  %al
 10c273b:	88 8d 6f ff ff ff    	mov    %cl,-0x91(%rbp)
 10c2741:	08 c8                	or     %cl,%al
 10c2743:	a8 01                	test   $0x1,%al
 10c2745:	74 12                	je     10c2759 <zstd.emitBestSequenceCompressedBlock+0x2f19>
 10c2747:	48 ff 85 90 fe ff ff 	incq   -0x170(%rbp)
 10c274e:	41 bc 81 00 00 00    	mov    $0x81,%r12d
 10c2754:	e9 68 fd ff ff       	jmp    10c24c1 <zstd.emitBestSequenceCompressedBlock+0x2c81>
 10c2759:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c275d:	48 8b 38             	mov    (%rax),%rdi
 10c2760:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2764:	ba 81 00 00 00       	mov    $0x81,%edx
 10c2769:	4c 89 f6             	mov    %r14,%rsi
 10c276c:	31 c9                	xor    %ecx,%ecx
 10c276e:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2772:	ff 50 18             	call   *0x18(%rax)
 10c2775:	bb c2 ff 03 01       	mov    $0x103ffc2,%ebx
 10c277a:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 10c277f:	74 1f                	je     10c27a0 <zstd.emitBestSequenceCompressedBlock+0x2f60>
 10c2781:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2785:	48 8b 38             	mov    (%rax),%rdi
 10c2788:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c278c:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c2790:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 10c2794:	31 c9                	xor    %ecx,%ecx
 10c2796:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c279a:	c5 f8 77             	vzeroupper 
 10c279d:	ff 50 18             	call   *0x18(%rax)
 10c27a0:	f6 03 01             	testb  $0x1,(%rbx)
 10c27a3:	0f 84 1a 01 00 00    	je     10c28c3 <zstd.emitBestSequenceCompressedBlock+0x3083>
 10c27a9:	c5 f8 10 05 97 d5 f4 	vmovups -0xb2a69(%rip),%xmm0        # 100fd48 <__anon_3065>
 10c27b0:	ff 
 10c27b1:	c5 f8 29 85 b0 fe ff 	vmovaps %xmm0,-0x150(%rbp)
 10c27b8:	ff 
 10c27b9:	48 c7 85 c0 fe ff ff 	movq   $0x0,-0x140(%rbp)
 10c27c0:	00 00 00 00 
 10c27c4:	48 8b 85 30 fe ff ff 	mov    -0x1d0(%rbp),%rax
 10c27cb:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 10c27cf:	4c 8b a5 38 fe ff ff 	mov    -0x1c8(%rbp),%r12
 10c27d6:	48 81 7d 98 ff 03 00 	cmpq   $0x3ff,-0x68(%rbp)
 10c27dd:	00 
 10c27de:	0f 87 0b 01 00 00    	ja     10c28ef <zstd.emitBestSequenceCompressedBlock+0x30af>
 10c27e4:	c5 f8 10 05 5c d5 f4 	vmovups -0xb2aa4(%rip),%xmm0        # 100fd48 <__anon_3065>
 10c27eb:	ff 
 10c27ec:	c5 f8 29 85 a0 e4 ff 	vmovaps %xmm0,-0x1b60(%rbp)
 10c27f3:	ff 
 10c27f4:	48 c7 85 b0 e4 ff ff 	movq   $0x0,-0x1b50(%rbp)
 10c27fb:	00 00 00 00 
 10c27ff:	48 8d b5 a0 e4 ff ff 	lea    -0x1b60(%rbp),%rsi
 10c2806:	4c 8d 85 90 db ff ff 	lea    -0x2470(%rbp),%r8
 10c280d:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 10c2811:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 10c2815:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 10c2819:	c5 f8 77             	vzeroupper 
 10c281c:	e8 0f 65 00 00       	call   10c8d30 <zstd.emitSmallHuffmanStreamKnownActive>
 10c2821:	66 85 c0             	test   %ax,%ax
 10c2824:	0f 85 77 0b 00 00    	jne    10c33a1 <zstd.emitBestSequenceCompressedBlock+0x3b61>
 10c282a:	48 8b 85 a8 e4 ff ff 	mov    -0x1b58(%rbp),%rax
 10c2831:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 10c2835:	4e 8d 04 20          	lea    (%rax,%r12,1),%r8
 10c2839:	48 8d bd b0 fd ff ff 	lea    -0x250(%rbp),%rdi
 10c2840:	48 8d 95 b0 fe ff ff 	lea    -0x150(%rbp),%rdx
 10c2847:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c284b:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 10c284f:	e8 3c 63 00 00       	call   10c8b90 <zstd.emitHuffmanLiteralsHeader>
 10c2854:	0f b7 85 b0 fd ff ff 	movzwl -0x250(%rbp),%eax
 10c285b:	66 85 c0             	test   %ax,%ax
 10c285e:	0f 85 3d 0b 00 00    	jne    10c33a1 <zstd.emitBestSequenceCompressedBlock+0x3b61>
 10c2864:	80 bd b2 fd ff ff 00 	cmpb   $0x0,-0x24e(%rbp)
 10c286b:	0f 84 0e 05 00 00    	je     10c2d7f <zstd.emitBestSequenceCompressedBlock+0x353f>
 10c2871:	4c 8b b5 b8 fe ff ff 	mov    -0x148(%rbp),%r14
 10c2878:	4c 89 f3             	mov    %r14,%rbx
 10c287b:	4c 01 e3             	add    %r12,%rbx
 10c287e:	0f 92 85 40 ff ff ff 	setb   -0xc0(%rbp)
 10c2885:	0f 92 c0             	setb   %al
 10c2888:	0f 92 85 50 fe ff ff 	setb   -0x1b0(%rbp)
 10c288f:	84 c0                	test   %al,%al
 10c2891:	0f 84 6e 05 00 00    	je     10c2e05 <zstd.emitBestSequenceCompressedBlock+0x35c5>
 10c2897:	48 8b 95 b0 e4 ff ff 	mov    -0x1b50(%rbp),%rdx
 10c289e:	66 41 bd 1a 00       	mov    $0x1a,%r13w
 10c28a3:	48 85 d2             	test   %rdx,%rdx
 10c28a6:	0f 84 73 06 00 00    	je     10c2f1f <zstd.emitBestSequenceCompressedBlock+0x36df>
 10c28ac:	48 8b b5 a0 e4 ff ff 	mov    -0x1b60(%rbp),%rsi
 10c28b3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c28b7:	48 8b 38             	mov    (%rax),%rdi
 10c28ba:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c28be:	e9 53 06 00 00       	jmp    10c2f16 <zstd.emitBestSequenceCompressedBlock+0x36d6>
 10c28c3:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 10c28ca:	bb c2 ff 03 01       	mov    $0x103ffc2,%ebx
 10c28cf:	48 85 d2             	test   %rdx,%rdx
 10c28d2:	0f 84 07 09 00 00    	je     10c31df <zstd.emitBestSequenceCompressedBlock+0x399f>
 10c28d8:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 10c28df:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c28e3:	48 8b 38             	mov    (%rax),%rdi
 10c28e6:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c28ea:	e9 02 05 00 00       	jmp    10c2df1 <zstd.emitBestSequenceCompressedBlock+0x35b1>
 10c28ef:	c5 f8 10 05 51 d4 f4 	vmovups -0xb2baf(%rip),%xmm0        # 100fd48 <__anon_3065>
 10c28f6:	ff 
 10c28f7:	c5 f8 29 85 b0 ed ff 	vmovaps %xmm0,-0x1250(%rbp)
 10c28fe:	ff 
 10c28ff:	48 c7 85 c0 ed ff ff 	movq   $0x0,-0x1240(%rbp)
 10c2906:	00 00 00 00 
 10c290a:	c5 f8 11 85 c8 ed ff 	vmovups %xmm0,-0x1238(%rbp)
 10c2911:	ff 
 10c2912:	48 c7 85 d8 ed ff ff 	movq   $0x0,-0x1228(%rbp)
 10c2919:	00 00 00 00 
 10c291d:	c5 f8 29 85 e0 ed ff 	vmovaps %xmm0,-0x1220(%rbp)
 10c2924:	ff 
 10c2925:	48 c7 85 f0 ed ff ff 	movq   $0x0,-0x1210(%rbp)
 10c292c:	00 00 00 00 
 10c2930:	c5 f8 11 85 f8 ed ff 	vmovups %xmm0,-0x1208(%rbp)
 10c2937:	ff 
 10c2938:	48 c7 85 08 ee ff ff 	movq   $0x0,-0x11f8(%rbp)
 10c293f:	00 00 00 00 
 10c2943:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10c2947:	48 8d 58 03          	lea    0x3(%rax),%rbx
 10c294b:	48 c1 eb 02          	shr    $0x2,%rbx
 10c294f:	48 8d b5 b0 ed ff ff 	lea    -0x1250(%rbp),%rsi
 10c2956:	4c 8d 85 90 db ff ff 	lea    -0x2470(%rbp),%r8
 10c295d:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 10c2961:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 10c2965:	48 89 d9             	mov    %rbx,%rcx
 10c2968:	c5 f8 77             	vzeroupper 
 10c296b:	e8 c0 63 00 00       	call   10c8d30 <zstd.emitSmallHuffmanStreamKnownActive>
 10c2970:	66 85 c0             	test   %ax,%ax
 10c2973:	0f 85 fa 08 00 00    	jne    10c3273 <zstd.emitBestSequenceCompressedBlock+0x3a33>
 10c2979:	48 8d b5 c8 ed ff ff 	lea    -0x1238(%rbp),%rsi
 10c2980:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 10c2984:	48 8d 14 18          	lea    (%rax,%rbx,1),%rdx
 10c2988:	4c 8d 85 90 db ff ff 	lea    -0x2470(%rbp),%r8
 10c298f:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 10c2993:	48 89 d9             	mov    %rbx,%rcx
 10c2996:	e8 95 63 00 00       	call   10c8d30 <zstd.emitSmallHuffmanStreamKnownActive>
 10c299b:	66 85 c0             	test   %ax,%ax
 10c299e:	0f 85 cf 08 00 00    	jne    10c3273 <zstd.emitBestSequenceCompressedBlock+0x3a33>
 10c29a4:	48 8d b5 e0 ed ff ff 	lea    -0x1220(%rbp),%rsi
 10c29ab:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 10c29af:	48 8d 14 58          	lea    (%rax,%rbx,2),%rdx
 10c29b3:	4c 8d 85 90 db ff ff 	lea    -0x2470(%rbp),%r8
 10c29ba:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 10c29be:	48 89 d9             	mov    %rbx,%rcx
 10c29c1:	e8 6a 63 00 00       	call   10c8d30 <zstd.emitSmallHuffmanStreamKnownActive>
 10c29c6:	66 85 c0             	test   %ax,%ax
 10c29c9:	0f 85 a4 08 00 00    	jne    10c3273 <zstd.emitBestSequenceCompressedBlock+0x3a33>
 10c29cf:	48 8d b5 f8 ed ff ff 	lea    -0x1208(%rbp),%rsi
 10c29d6:	48 8d 04 5b          	lea    (%rbx,%rbx,2),%rax
 10c29da:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 10c29de:	48 8d 14 01          	lea    (%rcx,%rax,1),%rdx
 10c29e2:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 10c29e6:	48 29 c1             	sub    %rax,%rcx
 10c29e9:	4c 8d 85 90 db ff ff 	lea    -0x2470(%rbp),%r8
 10c29f0:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 10c29f4:	e8 37 63 00 00       	call   10c8d30 <zstd.emitSmallHuffmanStreamKnownActive>
 10c29f9:	66 85 c0             	test   %ax,%ax
 10c29fc:	0f 85 71 08 00 00    	jne    10c3273 <zstd.emitBestSequenceCompressedBlock+0x3a33>
 10c2a02:	48 8b 9d b8 ed ff ff 	mov    -0x1248(%rbp),%rbx
 10c2a09:	4c 8b b5 d0 ed ff ff 	mov    -0x1230(%rbp),%r14
 10c2a10:	4c 8b bd e8 ed ff ff 	mov    -0x1218(%rbp),%r15
 10c2a17:	48 81 fb 00 00 01 00 	cmp    $0x10000,%rbx
 10c2a1e:	0f 93 c0             	setae  %al
 10c2a21:	49 81 fe 00 00 01 00 	cmp    $0x10000,%r14
 10c2a28:	0f 93 c1             	setae  %cl
 10c2a2b:	08 c1                	or     %al,%cl
 10c2a2d:	49 81 ff 00 00 01 00 	cmp    $0x10000,%r15
 10c2a34:	0f 93 c0             	setae  %al
 10c2a37:	08 c8                	or     %cl,%al
 10c2a39:	0f 85 b6 02 00 00    	jne    10c2cf5 <zstd.emitBestSequenceCompressedBlock+0x34b5>
 10c2a3f:	4b 8d 0c 3e          	lea    (%r14,%r15,1),%rcx
 10c2a43:	4c 01 e1             	add    %r12,%rcx
 10c2a46:	48 01 d9             	add    %rbx,%rcx
 10c2a49:	48 8b 85 00 ee ff ff 	mov    -0x1200(%rbp),%rax
 10c2a50:	4c 8d 04 08          	lea    (%rax,%rcx,1),%r8
 10c2a54:	49 83 c0 06          	add    $0x6,%r8
 10c2a58:	48 8d bd d0 fd ff ff 	lea    -0x230(%rbp),%rdi
 10c2a5f:	48 8d 95 b0 fe ff ff 	lea    -0x150(%rbp),%rdx
 10c2a66:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2a6a:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 10c2a6e:	e8 1d 61 00 00       	call   10c8b90 <zstd.emitHuffmanLiteralsHeader>
 10c2a73:	0f b7 85 d0 fd ff ff 	movzwl -0x230(%rbp),%eax
 10c2a7a:	66 85 c0             	test   %ax,%ax
 10c2a7d:	0f 85 f0 07 00 00    	jne    10c3273 <zstd.emitBestSequenceCompressedBlock+0x3a33>
 10c2a83:	80 bd d2 fd ff ff 00 	cmpb   $0x0,-0x22e(%rbp)
 10c2a8a:	0f 84 65 02 00 00    	je     10c2cf5 <zstd.emitBestSequenceCompressedBlock+0x34b5>
 10c2a90:	48 8d bd b0 fe ff ff 	lea    -0x150(%rbp),%rdi
 10c2a97:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2a9b:	4c 89 e2             	mov    %r12,%rdx
 10c2a9e:	e8 ad 58 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c2aa3:	66 85 c0             	test   %ax,%ax
 10c2aa6:	0f 85 c7 07 00 00    	jne    10c3273 <zstd.emitBestSequenceCompressedBlock+0x3a33>
 10c2aac:	48 8b bd b8 fe ff ff 	mov    -0x148(%rbp),%rdi
 10c2ab3:	4a 8d 04 27          	lea    (%rdi,%r12,1),%rax
 10c2ab7:	48 89 85 b8 fe ff ff 	mov    %rax,-0x148(%rbp)
 10c2abe:	48 03 bd b0 fe ff ff 	add    -0x150(%rbp),%rdi
 10c2ac5:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c2ac9:	4c 89 e2             	mov    %r12,%rdx
 10c2acc:	e8 ef a9 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c2ad1:	48 8d bd b0 fe ff ff 	lea    -0x150(%rbp),%rdi
 10c2ad8:	ba 06 00 00 00       	mov    $0x6,%edx
 10c2add:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2ae1:	e8 6a 58 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c2ae6:	66 85 c0             	test   %ax,%ax
 10c2ae9:	0f 85 84 07 00 00    	jne    10c3273 <zstd.emitBestSequenceCompressedBlock+0x3a33>
 10c2aef:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 10c2af6:	48 8b 8d b8 fe ff ff 	mov    -0x148(%rbp),%rcx
 10c2afd:	48 8d 51 06          	lea    0x6(%rcx),%rdx
 10c2b01:	48 89 95 b8 fe ff ff 	mov    %rdx,-0x148(%rbp)
 10c2b08:	66 89 1c 08          	mov    %bx,(%rax,%rcx,1)
 10c2b0c:	66 44 89 74 08 02    	mov    %r14w,0x2(%rax,%rcx,1)
 10c2b12:	66 44 89 7c 08 04    	mov    %r15w,0x4(%rax,%rcx,1)
 10c2b18:	48 8b 85 b0 ed ff ff 	mov    -0x1250(%rbp),%rax
 10c2b1f:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 10c2b23:	48 8b 9d b8 ed ff ff 	mov    -0x1248(%rbp),%rbx
 10c2b2a:	48 8d bd b0 fe ff ff 	lea    -0x150(%rbp),%rdi
 10c2b31:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2b35:	48 89 da             	mov    %rbx,%rdx
 10c2b38:	e8 13 58 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c2b3d:	66 85 c0             	test   %ax,%ax
 10c2b40:	0f 85 73 08 00 00    	jne    10c33b9 <zstd.emitBestSequenceCompressedBlock+0x3b79>
 10c2b46:	48 8b bd b8 fe ff ff 	mov    -0x148(%rbp),%rdi
 10c2b4d:	48 8d 04 1f          	lea    (%rdi,%rbx,1),%rax
 10c2b51:	48 89 85 b8 fe ff ff 	mov    %rax,-0x148(%rbp)
 10c2b58:	48 03 bd b0 fe ff ff 	add    -0x150(%rbp),%rdi
 10c2b5f:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10c2b63:	48 89 da             	mov    %rbx,%rdx
 10c2b66:	e8 55 a9 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c2b6b:	48 8b 85 c8 ed ff ff 	mov    -0x1238(%rbp),%rax
 10c2b72:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 10c2b76:	48 8b 9d d0 ed ff ff 	mov    -0x1230(%rbp),%rbx
 10c2b7d:	48 8d bd b0 fe ff ff 	lea    -0x150(%rbp),%rdi
 10c2b84:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2b88:	48 89 da             	mov    %rbx,%rdx
 10c2b8b:	e8 c0 57 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c2b90:	66 85 c0             	test   %ax,%ax
 10c2b93:	0f 85 20 08 00 00    	jne    10c33b9 <zstd.emitBestSequenceCompressedBlock+0x3b79>
 10c2b99:	48 8b bd b8 fe ff ff 	mov    -0x148(%rbp),%rdi
 10c2ba0:	48 8d 04 1f          	lea    (%rdi,%rbx,1),%rax
 10c2ba4:	48 89 85 b8 fe ff ff 	mov    %rax,-0x148(%rbp)
 10c2bab:	48 03 bd b0 fe ff ff 	add    -0x150(%rbp),%rdi
 10c2bb2:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c2bb6:	48 89 da             	mov    %rbx,%rdx
 10c2bb9:	e8 02 a9 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c2bbe:	48 8b 85 e0 ed ff ff 	mov    -0x1220(%rbp),%rax
 10c2bc5:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 10c2bc9:	4c 8b b5 e8 ed ff ff 	mov    -0x1218(%rbp),%r14
 10c2bd0:	48 8d bd b0 fe ff ff 	lea    -0x150(%rbp),%rdi
 10c2bd7:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2bdb:	4c 89 f2             	mov    %r14,%rdx
 10c2bde:	e8 6d 57 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c2be3:	66 85 c0             	test   %ax,%ax
 10c2be6:	0f 85 cd 07 00 00    	jne    10c33b9 <zstd.emitBestSequenceCompressedBlock+0x3b79>
 10c2bec:	48 8b bd b8 fe ff ff 	mov    -0x148(%rbp),%rdi
 10c2bf3:	4a 8d 04 37          	lea    (%rdi,%r14,1),%rax
 10c2bf7:	48 89 85 b8 fe ff ff 	mov    %rax,-0x148(%rbp)
 10c2bfe:	48 03 bd b0 fe ff ff 	add    -0x150(%rbp),%rdi
 10c2c05:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c2c09:	4c 89 f2             	mov    %r14,%rdx
 10c2c0c:	e8 af a8 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c2c11:	4c 8b bd f8 ed ff ff 	mov    -0x1208(%rbp),%r15
 10c2c18:	48 8b 9d 00 ee ff ff 	mov    -0x1200(%rbp),%rbx
 10c2c1f:	48 8d bd b0 fe ff ff 	lea    -0x150(%rbp),%rdi
 10c2c26:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2c2a:	48 89 da             	mov    %rbx,%rdx
 10c2c2d:	e8 1e 57 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c2c32:	66 85 c0             	test   %ax,%ax
 10c2c35:	0f 85 7e 07 00 00    	jne    10c33b9 <zstd.emitBestSequenceCompressedBlock+0x3b79>
 10c2c3b:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 10c2c42:	4c 8b b5 b8 fe ff ff 	mov    -0x148(%rbp),%r14
 10c2c49:	4c 8b a5 c0 fe ff ff 	mov    -0x140(%rbp),%r12
 10c2c50:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 10c2c54:	4a 8d 3c 30          	lea    (%rax,%r14,1),%rdi
 10c2c58:	4c 89 fe             	mov    %r15,%rsi
 10c2c5b:	48 89 da             	mov    %rbx,%rdx
 10c2c5e:	e8 5d a8 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c2c63:	48 8b 95 c0 ed ff ff 	mov    -0x1240(%rbp),%rdx
 10c2c6a:	48 85 d2             	test   %rdx,%rdx
 10c2c6d:	74 18                	je     10c2c87 <zstd.emitBestSequenceCompressedBlock+0x3447>
 10c2c6f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2c73:	48 8b 38             	mov    (%rax),%rdi
 10c2c76:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2c7a:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10c2c7e:	31 c9                	xor    %ecx,%ecx
 10c2c80:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2c84:	ff 50 18             	call   *0x18(%rax)
 10c2c87:	48 8b 95 d8 ed ff ff 	mov    -0x1228(%rbp),%rdx
 10c2c8e:	48 85 d2             	test   %rdx,%rdx
 10c2c91:	74 18                	je     10c2cab <zstd.emitBestSequenceCompressedBlock+0x346b>
 10c2c93:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2c97:	48 8b 38             	mov    (%rax),%rdi
 10c2c9a:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2c9e:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c2ca2:	31 c9                	xor    %ecx,%ecx
 10c2ca4:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2ca8:	ff 50 18             	call   *0x18(%rax)
 10c2cab:	48 8b 95 f0 ed ff ff 	mov    -0x1210(%rbp),%rdx
 10c2cb2:	48 85 d2             	test   %rdx,%rdx
 10c2cb5:	74 18                	je     10c2ccf <zstd.emitBestSequenceCompressedBlock+0x348f>
 10c2cb7:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2cbb:	48 8b 38             	mov    (%rax),%rdi
 10c2cbe:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2cc2:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c2cc6:	31 c9                	xor    %ecx,%ecx
 10c2cc8:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2ccc:	ff 50 18             	call   *0x18(%rax)
 10c2ccf:	49 01 de             	add    %rbx,%r14
 10c2cd2:	48 8b 95 08 ee ff ff 	mov    -0x11f8(%rbp),%rdx
 10c2cd9:	48 85 d2             	test   %rdx,%rdx
 10c2cdc:	0f 84 eb 03 00 00    	je     10c30cd <zstd.emitBestSequenceCompressedBlock+0x388d>
 10c2ce2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2ce6:	48 8b 38             	mov    (%rax),%rdi
 10c2ce9:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2ced:	4c 89 fe             	mov    %r15,%rsi
 10c2cf0:	e9 cf 03 00 00       	jmp    10c30c4 <zstd.emitBestSequenceCompressedBlock+0x3884>
 10c2cf5:	48 8b 95 c0 ed ff ff 	mov    -0x1240(%rbp),%rdx
 10c2cfc:	48 85 d2             	test   %rdx,%rdx
 10c2cff:	74 1b                	je     10c2d1c <zstd.emitBestSequenceCompressedBlock+0x34dc>
 10c2d01:	48 8b b5 b0 ed ff ff 	mov    -0x1250(%rbp),%rsi
 10c2d08:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2d0c:	48 8b 38             	mov    (%rax),%rdi
 10c2d0f:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2d13:	31 c9                	xor    %ecx,%ecx
 10c2d15:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2d19:	ff 50 18             	call   *0x18(%rax)
 10c2d1c:	48 8b 95 d8 ed ff ff 	mov    -0x1228(%rbp),%rdx
 10c2d23:	48 85 d2             	test   %rdx,%rdx
 10c2d26:	74 1b                	je     10c2d43 <zstd.emitBestSequenceCompressedBlock+0x3503>
 10c2d28:	48 8b b5 c8 ed ff ff 	mov    -0x1238(%rbp),%rsi
 10c2d2f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2d33:	48 8b 38             	mov    (%rax),%rdi
 10c2d36:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2d3a:	31 c9                	xor    %ecx,%ecx
 10c2d3c:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2d40:	ff 50 18             	call   *0x18(%rax)
 10c2d43:	48 8b 95 f0 ed ff ff 	mov    -0x1210(%rbp),%rdx
 10c2d4a:	48 85 d2             	test   %rdx,%rdx
 10c2d4d:	74 1b                	je     10c2d6a <zstd.emitBestSequenceCompressedBlock+0x352a>
 10c2d4f:	48 8b b5 e0 ed ff ff 	mov    -0x1220(%rbp),%rsi
 10c2d56:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2d5a:	48 8b 38             	mov    (%rax),%rdi
 10c2d5d:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2d61:	31 c9                	xor    %ecx,%ecx
 10c2d63:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2d67:	ff 50 18             	call   *0x18(%rax)
 10c2d6a:	48 8b 95 08 ee ff ff 	mov    -0x11f8(%rbp),%rdx
 10c2d71:	48 85 d2             	test   %rdx,%rdx
 10c2d74:	74 30                	je     10c2da6 <zstd.emitBestSequenceCompressedBlock+0x3566>
 10c2d76:	48 8b b5 f8 ed ff ff 	mov    -0x1208(%rbp),%rsi
 10c2d7d:	eb 13                	jmp    10c2d92 <zstd.emitBestSequenceCompressedBlock+0x3552>
 10c2d7f:	48 8b 95 b0 e4 ff ff 	mov    -0x1b50(%rbp),%rdx
 10c2d86:	48 85 d2             	test   %rdx,%rdx
 10c2d89:	74 1b                	je     10c2da6 <zstd.emitBestSequenceCompressedBlock+0x3566>
 10c2d8b:	48 8b b5 a0 e4 ff ff 	mov    -0x1b60(%rbp),%rsi
 10c2d92:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2d96:	48 8b 38             	mov    (%rax),%rdi
 10c2d99:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2d9d:	31 c9                	xor    %ecx,%ecx
 10c2d9f:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2da3:	ff 50 18             	call   *0x18(%rax)
 10c2da6:	48 8b 95 c0 fe ff ff 	mov    -0x140(%rbp),%rdx
 10c2dad:	48 85 d2             	test   %rdx,%rdx
 10c2db0:	74 1b                	je     10c2dcd <zstd.emitBestSequenceCompressedBlock+0x358d>
 10c2db2:	48 8b b5 b0 fe ff ff 	mov    -0x150(%rbp),%rsi
 10c2db9:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2dbd:	48 8b 38             	mov    (%rax),%rdi
 10c2dc0:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2dc4:	31 c9                	xor    %ecx,%ecx
 10c2dc6:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2dca:	ff 50 18             	call   *0x18(%rax)
 10c2dcd:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 10c2dd4:	bb c2 ff 03 01       	mov    $0x103ffc2,%ebx
 10c2dd9:	48 85 d2             	test   %rdx,%rdx
 10c2ddc:	0f 84 fd 03 00 00    	je     10c31df <zstd.emitBestSequenceCompressedBlock+0x399f>
 10c2de2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2de6:	48 8b 38             	mov    (%rax),%rdi
 10c2de9:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2ded:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c2df1:	31 c9                	xor    %ecx,%ecx
 10c2df3:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c2df7:	4d 89 e0             	mov    %r12,%r8
 10c2dfa:	c5 f8 77             	vzeroupper 
 10c2dfd:	ff 50 18             	call   *0x18(%rax)
 10c2e00:	e9 b0 db ff ff       	jmp    10c09b5 <zstd.emitBestSequenceCompressedBlock+0x1175>
 10c2e05:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 10c2e0c:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 10c2e10:	48 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%rax
 10c2e17:	49 89 c5             	mov    %rax,%r13
 10c2e1a:	48 39 d8             	cmp    %rbx,%rax
 10c2e1d:	0f 83 93 00 00 00    	jae    10c2eb6 <zstd.emitBestSequenceCompressedBlock+0x3676>
 10c2e23:	48 89 d8             	mov    %rbx,%rax
 10c2e26:	48 d1 e8             	shr    %rax
 10c2e29:	48 83 e8 80          	sub    $0xffffffffffffff80,%rax
 10c2e2d:	48 01 d8             	add    %rbx,%rax
 10c2e30:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 10c2e37:	48 0f 43 c8          	cmovae %rax,%rcx
 10c2e3b:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 10c2e3f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2e43:	48 8b 08             	mov    (%rax),%rcx
 10c2e46:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 10c2e4a:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2e4e:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 10c2e52:	45 31 ff             	xor    %r15d,%r15d
 10c2e55:	4d 85 ed             	test   %r13,%r13
 10c2e58:	74 37                	je     10c2e91 <zstd.emitBestSequenceCompressedBlock+0x3651>
 10c2e5a:	b8 00 00 00 00       	mov    $0x0,%eax
 10c2e5f:	45 84 ff             	test   %r15b,%r15b
 10c2e62:	75 2f                	jne    10c2e93 <zstd.emitBestSequenceCompressedBlock+0x3653>
 10c2e64:	45 31 ff             	xor    %r15d,%r15d
 10c2e67:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 10c2e6b:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c2e6f:	4c 89 ea             	mov    %r13,%rdx
 10c2e72:	31 c9                	xor    %ecx,%ecx
 10c2e74:	4c 8b 45 a0          	mov    -0x60(%rbp),%r8
 10c2e78:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c2e7c:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 10c2e80:	ff 50 10             	call   *0x10(%rax)
 10c2e83:	48 85 c0             	test   %rax,%rax
 10c2e86:	74 09                	je     10c2e91 <zstd.emitBestSequenceCompressedBlock+0x3651>
 10c2e88:	49 89 c7             	mov    %rax,%r15
 10c2e8b:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 10c2e8f:	eb 02                	jmp    10c2e93 <zstd.emitBestSequenceCompressedBlock+0x3653>
 10c2e91:	31 c0                	xor    %eax,%eax
 10c2e93:	4d 85 ff             	test   %r15,%r15
 10c2e96:	0f 84 82 01 00 00    	je     10c301e <zstd.emitBestSequenceCompressedBlock+0x37de>
 10c2e9c:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 10c2ea0:	4c 89 bd b0 fe ff ff 	mov    %r15,-0x150(%rbp)
 10c2ea7:	4c 8b 6d a0          	mov    -0x60(%rbp),%r13
 10c2eab:	4c 89 ad c0 fe ff ff 	mov    %r13,-0x140(%rbp)
 10c2eb2:	4c 89 7d 88          	mov    %r15,-0x78(%rbp)
 10c2eb6:	4c 03 75 88          	add    -0x78(%rbp),%r14
 10c2eba:	4c 89 f7             	mov    %r14,%rdi
 10c2ebd:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c2ec1:	4c 89 e2             	mov    %r12,%rdx
 10c2ec4:	e8 f7 a5 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c2ec9:	49 89 de             	mov    %rbx,%r14
 10c2ecc:	4c 03 75 a8          	add    -0x58(%rbp),%r14
 10c2ed0:	0f 92 85 40 ff ff ff 	setb   -0xc0(%rbp)
 10c2ed7:	48 8b 85 a0 e4 ff ff 	mov    -0x1b60(%rbp),%rax
 10c2ede:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 10c2ee2:	0f 92 85 50 fe ff ff 	setb   -0x1b0(%rbp)
 10c2ee9:	f6 85 50 fe ff ff 01 	testb  $0x1,-0x1b0(%rbp)
 10c2ef0:	0f 84 9f 00 00 00    	je     10c2f95 <zstd.emitBestSequenceCompressedBlock+0x3755>
 10c2ef6:	48 8b 95 b0 e4 ff ff 	mov    -0x1b50(%rbp),%rdx
 10c2efd:	66 41 bd 1a 00       	mov    $0x1a,%r13w
 10c2f02:	48 85 d2             	test   %rdx,%rdx
 10c2f05:	74 18                	je     10c2f1f <zstd.emitBestSequenceCompressedBlock+0x36df>
 10c2f07:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2f0b:	48 8b 38             	mov    (%rax),%rdi
 10c2f0e:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2f12:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c2f16:	31 c9                	xor    %ecx,%ecx
 10c2f18:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2f1c:	ff 50 18             	call   *0x18(%rax)
 10c2f1f:	48 8b 95 c0 fe ff ff 	mov    -0x140(%rbp),%rdx
 10c2f26:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2f2a:	48 8b 38             	mov    (%rax),%rdi
 10c2f2d:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2f31:	48 85 d2             	test   %rdx,%rdx
 10c2f34:	74 1b                	je     10c2f51 <zstd.emitBestSequenceCompressedBlock+0x3711>
 10c2f36:	48 8b b5 b0 fe ff ff 	mov    -0x150(%rbp),%rsi
 10c2f3d:	31 c9                	xor    %ecx,%ecx
 10c2f3f:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2f43:	ff 50 18             	call   *0x18(%rax)
 10c2f46:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2f4a:	48 8b 38             	mov    (%rax),%rdi
 10c2f4d:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2f51:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 10c2f58:	48 85 d2             	test   %rdx,%rdx
 10c2f5b:	74 18                	je     10c2f75 <zstd.emitBestSequenceCompressedBlock+0x3735>
 10c2f5d:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c2f61:	31 c9                	xor    %ecx,%ecx
 10c2f63:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2f67:	ff 50 18             	call   *0x18(%rax)
 10c2f6a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2f6e:	48 8b 38             	mov    (%rax),%rdi
 10c2f71:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2f75:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c2f79:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 10c2f80:	31 c9                	xor    %ecx,%ecx
 10c2f82:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c2f86:	ff 50 18             	call   *0x18(%rax)
 10c2f89:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c2f8d:	44 89 e9             	mov    %r13d,%ecx
 10c2f90:	e9 ad ca ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c2f95:	4d 39 f5             	cmp    %r14,%r13
 10c2f98:	73 77                	jae    10c3011 <zstd.emitBestSequenceCompressedBlock+0x37d1>
 10c2f9a:	4c 89 f0             	mov    %r14,%rax
 10c2f9d:	48 d1 e8             	shr    %rax
 10c2fa0:	48 83 e8 80          	sub    $0xffffffffffffff80,%rax
 10c2fa4:	4c 01 f0             	add    %r14,%rax
 10c2fa7:	49 c7 c4 ff ff ff ff 	mov    $0xffffffffffffffff,%r12
 10c2fae:	4c 0f 43 e0          	cmovae %rax,%r12
 10c2fb2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c2fb6:	4c 8b 38             	mov    (%rax),%r15
 10c2fb9:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c2fbd:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 10c2fc1:	4d 85 ed             	test   %r13,%r13
 10c2fc4:	0f 84 b3 00 00 00    	je     10c307d <zstd.emitBestSequenceCompressedBlock+0x383d>
 10c2fca:	31 c9                	xor    %ecx,%ecx
 10c2fcc:	b8 00 00 00 00       	mov    $0x0,%eax
 10c2fd1:	48 c7 45 a0 00 00 00 	movq   $0x0,-0x60(%rbp)
 10c2fd8:	00 
 10c2fd9:	84 c9                	test   %cl,%cl
 10c2fdb:	0f 85 a6 00 00 00    	jne    10c3087 <zstd.emitBestSequenceCompressedBlock+0x3847>
 10c2fe1:	48 c7 45 a0 00 00 00 	movq   $0x0,-0x60(%rbp)
 10c2fe8:	00 
 10c2fe9:	4c 89 ff             	mov    %r15,%rdi
 10c2fec:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c2ff0:	4c 89 ea             	mov    %r13,%rdx
 10c2ff3:	31 c9                	xor    %ecx,%ecx
 10c2ff5:	4d 89 e0             	mov    %r12,%r8
 10c2ff8:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 10c2ffc:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 10c3000:	ff 50 10             	call   *0x10(%rax)
 10c3003:	48 85 c0             	test   %rax,%rax
 10c3006:	74 7d                	je     10c3085 <zstd.emitBestSequenceCompressedBlock+0x3845>
 10c3008:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 10c300c:	4c 89 e0             	mov    %r12,%rax
 10c300f:	eb 76                	jmp    10c3087 <zstd.emitBestSequenceCompressedBlock+0x3847>
 10c3011:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 10c3015:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 10c3019:	4d 89 ec             	mov    %r13,%r12
 10c301c:	eb 77                	jmp    10c3095 <zstd.emitBestSequenceCompressedBlock+0x3855>
 10c301e:	31 c0                	xor    %eax,%eax
 10c3020:	84 c0                	test   %al,%al
 10c3022:	0f 85 6f f8 ff ff    	jne    10c2897 <zstd.emitBestSequenceCompressedBlock+0x3057>
 10c3028:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 10c302c:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10c3030:	31 d2                	xor    %edx,%edx
 10c3032:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10c3036:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 10c303a:	ff 10                	call   *(%rax)
 10c303c:	48 85 c0             	test   %rax,%rax
 10c303f:	0f 84 52 f8 ff ff    	je     10c2897 <zstd.emitBestSequenceCompressedBlock+0x3057>
 10c3045:	49 89 c7             	mov    %rax,%r15
 10c3048:	48 89 c7             	mov    %rax,%rdi
 10c304b:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c304f:	4c 89 f2             	mov    %r14,%rdx
 10c3052:	e8 69 a4 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c3057:	4d 85 ed             	test   %r13,%r13
 10c305a:	0f 84 40 fe ff ff    	je     10c2ea0 <zstd.emitBestSequenceCompressedBlock+0x3660>
 10c3060:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 10c3064:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c3068:	4c 89 ea             	mov    %r13,%rdx
 10c306b:	31 c9                	xor    %ecx,%ecx
 10c306d:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c3071:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 10c3075:	ff 50 18             	call   *0x18(%rax)
 10c3078:	e9 23 fe ff ff       	jmp    10c2ea0 <zstd.emitBestSequenceCompressedBlock+0x3660>
 10c307d:	48 c7 45 a0 00 00 00 	movq   $0x0,-0x60(%rbp)
 10c3084:	00 
 10c3085:	31 c0                	xor    %eax,%eax
 10c3087:	48 83 7d a0 00       	cmpq   $0x0,-0x60(%rbp)
 10c308c:	0f 84 7a 01 00 00    	je     10c320c <zstd.emitBestSequenceCompressedBlock+0x39cc>
 10c3092:	49 89 c4             	mov    %rax,%r12
 10c3095:	48 03 5d a0          	add    -0x60(%rbp),%rbx
 10c3099:	48 89 df             	mov    %rbx,%rdi
 10c309c:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c30a0:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 10c30a4:	e8 17 a4 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c30a9:	48 8b 95 b0 e4 ff ff 	mov    -0x1b50(%rbp),%rdx
 10c30b0:	48 85 d2             	test   %rdx,%rdx
 10c30b3:	74 18                	je     10c30cd <zstd.emitBestSequenceCompressedBlock+0x388d>
 10c30b5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c30b9:	48 8b 38             	mov    (%rax),%rdi
 10c30bc:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c30c0:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 10c30c4:	31 c9                	xor    %ecx,%ecx
 10c30c6:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c30ca:	ff 50 18             	call   *0x18(%rax)
 10c30cd:	c6 85 b0 ed ff ff 00 	movb   $0x0,-0x1250(%rbp)
 10c30d4:	31 c0                	xor    %eax,%eax
 10c30d6:	84 c0                	test   %al,%al
 10c30d8:	74 6f                	je     10c3149 <zstd.emitBestSequenceCompressedBlock+0x3909>
 10c30da:	4d 85 e4             	test   %r12,%r12
 10c30dd:	74 1b                	je     10c30fa <zstd.emitBestSequenceCompressedBlock+0x38ba>
 10c30df:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c30e3:	48 8b 38             	mov    (%rax),%rdi
 10c30e6:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c30ea:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10c30ee:	4c 89 e2             	mov    %r12,%rdx
 10c30f1:	31 c9                	xor    %ecx,%ecx
 10c30f3:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c30f7:	ff 50 18             	call   *0x18(%rax)
 10c30fa:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 10c3101:	48 85 d2             	test   %rdx,%rdx
 10c3104:	74 18                	je     10c311e <zstd.emitBestSequenceCompressedBlock+0x38de>
 10c3106:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c310a:	48 8b 38             	mov    (%rax),%rdi
 10c310d:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c3111:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c3115:	31 c9                	xor    %ecx,%ecx
 10c3117:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c311b:	ff 50 18             	call   *0x18(%rax)
 10c311e:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 10c3122:	48 8b 3b             	mov    (%rbx),%rdi
 10c3125:	48 8b 43 08          	mov    0x8(%rbx),%rax
 10c3129:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c312d:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 10c3134:	31 c9                	xor    %ecx,%ecx
 10c3136:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c313a:	ff 50 18             	call   *0x18(%rax)
 10c313d:	48 89 de             	mov    %rbx,%rsi
 10c3140:	66 b9 3e 00          	mov    $0x3e,%cx
 10c3144:	e9 f9 c8 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c3149:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 10c314d:	48 81 f9 00 10 00 00 	cmp    $0x1000,%rcx
 10c3154:	b8 03 00 00 00       	mov    $0x3,%eax
 10c3159:	48 83 d8 00          	sbb    $0x0,%rax
 10c315d:	48 01 c8             	add    %rcx,%rax
 10c3160:	49 39 c6             	cmp    %rax,%r14
 10c3163:	0f 83 83 00 00 00    	jae    10c31ec <zstd.emitBestSequenceCompressedBlock+0x39ac>
 10c3169:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 10c3170:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c3174:	4c 89 f2             	mov    %r14,%rdx
 10c3177:	e8 d4 51 00 00       	call   10c8350 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 10c317c:	66 85 c0             	test   %ax,%ax
 10c317f:	0f 85 5b 02 00 00    	jne    10c33e0 <zstd.emitBestSequenceCompressedBlock+0x3ba0>
 10c3185:	48 8b bd d8 fe ff ff 	mov    -0x128(%rbp),%rdi
 10c318c:	4a 8d 04 37          	lea    (%rdi,%r14,1),%rax
 10c3190:	48 89 85 d8 fe ff ff 	mov    %rax,-0x128(%rbp)
 10c3197:	48 03 bd d0 fe ff ff 	add    -0x130(%rbp),%rdi
 10c319e:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10c31a2:	4c 89 f2             	mov    %r14,%rdx
 10c31a5:	e8 16 a3 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c31aa:	4d 85 e4             	test   %r12,%r12
 10c31ad:	74 1b                	je     10c31ca <zstd.emitBestSequenceCompressedBlock+0x398a>
 10c31af:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c31b3:	48 8b 38             	mov    (%rax),%rdi
 10c31b6:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c31ba:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10c31be:	4c 89 e2             	mov    %r12,%rdx
 10c31c1:	31 c9                	xor    %ecx,%ecx
 10c31c3:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c31c7:	ff 50 18             	call   *0x18(%rax)
 10c31ca:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 10c31d1:	bb ea ff 03 01       	mov    $0x103ffea,%ebx
 10c31d6:	48 85 d2             	test   %rdx,%rdx
 10c31d9:	0f 85 03 fc ff ff    	jne    10c2de2 <zstd.emitBestSequenceCompressedBlock+0x35a2>
 10c31df:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c31e3:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c31e7:	e9 cd d7 ff ff       	jmp    10c09b9 <zstd.emitBestSequenceCompressedBlock+0x1179>
 10c31ec:	4d 85 e4             	test   %r12,%r12
 10c31ef:	0f 84 d8 fb ff ff    	je     10c2dcd <zstd.emitBestSequenceCompressedBlock+0x358d>
 10c31f5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c31f9:	48 8b 38             	mov    (%rax),%rdi
 10c31fc:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c3200:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10c3204:	4c 89 e2             	mov    %r12,%rdx
 10c3207:	e9 b8 fb ff ff       	jmp    10c2dc4 <zstd.emitBestSequenceCompressedBlock+0x3584>
 10c320c:	31 c0                	xor    %eax,%eax
 10c320e:	84 c0                	test   %al,%al
 10c3210:	0f 85 e0 fc ff ff    	jne    10c2ef6 <zstd.emitBestSequenceCompressedBlock+0x36b6>
 10c3216:	4c 89 ff             	mov    %r15,%rdi
 10c3219:	4c 89 e6             	mov    %r12,%rsi
 10c321c:	31 d2                	xor    %edx,%edx
 10c321e:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 10c3222:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 10c3226:	ff 10                	call   *(%rax)
 10c3228:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 10c322c:	48 85 c0             	test   %rax,%rax
 10c322f:	0f 84 c1 fc ff ff    	je     10c2ef6 <zstd.emitBestSequenceCompressedBlock+0x36b6>
 10c3235:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 10c3239:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c323d:	48 89 da             	mov    %rbx,%rdx
 10c3240:	e8 7b a2 03 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10c3245:	4d 85 ed             	test   %r13,%r13
 10c3248:	0f 84 47 fe ff ff    	je     10c3095 <zstd.emitBestSequenceCompressedBlock+0x3855>
 10c324e:	4c 89 ff             	mov    %r15,%rdi
 10c3251:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10c3255:	4c 89 ea             	mov    %r13,%rdx
 10c3258:	31 c9                	xor    %ecx,%ecx
 10c325a:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c325e:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 10c3262:	ff 50 18             	call   *0x18(%rax)
 10c3265:	e9 2b fe ff ff       	jmp    10c3095 <zstd.emitBestSequenceCompressedBlock+0x3855>
 10c326a:	66 89 45 b0          	mov    %ax,-0x50(%rbp)
 10c326e:	e9 bb f0 ff ff       	jmp    10c232e <zstd.emitBestSequenceCompressedBlock+0x2aee>
 10c3273:	41 89 c5             	mov    %eax,%r13d
 10c3276:	48 8b 95 c0 ed ff ff 	mov    -0x1240(%rbp),%rdx
 10c327d:	48 85 d2             	test   %rdx,%rdx
 10c3280:	74 1b                	je     10c329d <zstd.emitBestSequenceCompressedBlock+0x3a5d>
 10c3282:	48 8b b5 b0 ed ff ff 	mov    -0x1250(%rbp),%rsi
 10c3289:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c328d:	48 8b 38             	mov    (%rax),%rdi
 10c3290:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c3294:	31 c9                	xor    %ecx,%ecx
 10c3296:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c329a:	ff 50 18             	call   *0x18(%rax)
 10c329d:	48 8b 95 d8 ed ff ff 	mov    -0x1228(%rbp),%rdx
 10c32a4:	48 85 d2             	test   %rdx,%rdx
 10c32a7:	74 1b                	je     10c32c4 <zstd.emitBestSequenceCompressedBlock+0x3a84>
 10c32a9:	48 8b b5 c8 ed ff ff 	mov    -0x1238(%rbp),%rsi
 10c32b0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c32b4:	48 8b 38             	mov    (%rax),%rdi
 10c32b7:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c32bb:	31 c9                	xor    %ecx,%ecx
 10c32bd:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c32c1:	ff 50 18             	call   *0x18(%rax)
 10c32c4:	48 8b 95 f0 ed ff ff 	mov    -0x1210(%rbp),%rdx
 10c32cb:	48 85 d2             	test   %rdx,%rdx
 10c32ce:	74 1b                	je     10c32eb <zstd.emitBestSequenceCompressedBlock+0x3aab>
 10c32d0:	48 8b b5 e0 ed ff ff 	mov    -0x1220(%rbp),%rsi
 10c32d7:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c32db:	48 8b 38             	mov    (%rax),%rdi
 10c32de:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c32e2:	31 c9                	xor    %ecx,%ecx
 10c32e4:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c32e8:	ff 50 18             	call   *0x18(%rax)
 10c32eb:	48 8b 95 08 ee ff ff 	mov    -0x11f8(%rbp),%rdx
 10c32f2:	48 85 d2             	test   %rdx,%rdx
 10c32f5:	0f 84 24 fc ff ff    	je     10c2f1f <zstd.emitBestSequenceCompressedBlock+0x36df>
 10c32fb:	48 8b b5 f8 ed ff ff 	mov    -0x1208(%rbp),%rsi
 10c3302:	e9 ac f5 ff ff       	jmp    10c28b3 <zstd.emitBestSequenceCompressedBlock+0x3073>
 10c3307:	49 83 ff 81          	cmp    $0xffffffffffffff81,%r15
 10c330b:	72 1a                	jb     10c3327 <zstd.emitBestSequenceCompressedBlock+0x3ae7>
 10c330d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c3311:	48 8b 38             	mov    (%rax),%rdi
 10c3314:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c3318:	4c 89 f6             	mov    %r14,%rsi
 10c331b:	4c 89 e2             	mov    %r12,%rdx
 10c331e:	31 c9                	xor    %ecx,%ecx
 10c3320:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c3324:	ff 50 18             	call   *0x18(%rax)
 10c3327:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 10c332c:	74 18                	je     10c3346 <zstd.emitBestSequenceCompressedBlock+0x3b06>
 10c332e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c3332:	48 8b 38             	mov    (%rax),%rdi
 10c3335:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c3339:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c333d:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 10c3341:	e9 5a f0 ff ff       	jmp    10c23a0 <zstd.emitBestSequenceCompressedBlock+0x2b60>
 10c3346:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 10c334a:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 10c3351:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c3355:	48 8b 38             	mov    (%rax),%rdi
 10c3358:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c335c:	48 85 d2             	test   %rdx,%rdx
 10c335f:	74 1d                	je     10c337e <zstd.emitBestSequenceCompressedBlock+0x3b3e>
 10c3361:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 10c3368:	31 c9                	xor    %ecx,%ecx
 10c336a:	4d 89 e0             	mov    %r12,%r8
 10c336d:	c5 f8 77             	vzeroupper 
 10c3370:	ff 50 18             	call   *0x18(%rax)
 10c3373:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c3377:	48 8b 38             	mov    (%rax),%rdi
 10c337a:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c337e:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c3382:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 10c3389:	31 c9                	xor    %ecx,%ecx
 10c338b:	4d 89 e0             	mov    %r12,%r8
 10c338e:	c5 f8 77             	vzeroupper 
 10c3391:	ff 50 18             	call   *0x18(%rax)
 10c3394:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 10c3398:	0f b7 4d b0          	movzwl -0x50(%rbp),%ecx
 10c339c:	e9 a1 c6 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>
 10c33a1:	41 89 c5             	mov    %eax,%r13d
 10c33a4:	48 8b 95 b0 e4 ff ff 	mov    -0x1b50(%rbp),%rdx
 10c33ab:	48 85 d2             	test   %rdx,%rdx
 10c33ae:	0f 85 f8 f4 ff ff    	jne    10c28ac <zstd.emitBestSequenceCompressedBlock+0x306c>
 10c33b4:	e9 66 fb ff ff       	jmp    10c2f1f <zstd.emitBestSequenceCompressedBlock+0x36df>
 10c33b9:	41 89 c5             	mov    %eax,%r13d
 10c33bc:	48 8b 95 c0 ed ff ff 	mov    -0x1240(%rbp),%rdx
 10c33c3:	48 85 d2             	test   %rdx,%rdx
 10c33c6:	0f 84 d1 fe ff ff    	je     10c329d <zstd.emitBestSequenceCompressedBlock+0x3a5d>
 10c33cc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c33d0:	48 8b 38             	mov    (%rax),%rdi
 10c33d3:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c33d7:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10c33db:	e9 b4 fe ff ff       	jmp    10c3294 <zstd.emitBestSequenceCompressedBlock+0x3a54>
 10c33e0:	41 89 c7             	mov    %eax,%r15d
 10c33e3:	4d 85 e4             	test   %r12,%r12
 10c33e6:	74 1b                	je     10c3403 <zstd.emitBestSequenceCompressedBlock+0x3bc3>
 10c33e8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c33ec:	48 8b 38             	mov    (%rax),%rdi
 10c33ef:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c33f3:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10c33f7:	4c 89 e2             	mov    %r12,%rdx
 10c33fa:	31 c9                	xor    %ecx,%ecx
 10c33fc:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c3400:	ff 50 18             	call   *0x18(%rax)
 10c3403:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 10c340a:	48 85 d2             	test   %rdx,%rdx
 10c340d:	74 18                	je     10c3427 <zstd.emitBestSequenceCompressedBlock+0x3be7>
 10c340f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 10c3413:	48 8b 38             	mov    (%rax),%rdi
 10c3416:	48 8b 40 08          	mov    0x8(%rax),%rax
 10c341a:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 10c341e:	31 c9                	xor    %ecx,%ecx
 10c3420:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c3424:	ff 50 18             	call   *0x18(%rax)
 10c3427:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 10c342b:	48 8b 3b             	mov    (%rbx),%rdi
 10c342e:	48 8b 43 08          	mov    0x8(%rbx),%rax
 10c3432:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 10c3436:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 10c343d:	31 c9                	xor    %ecx,%ecx
 10c343f:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 10c3443:	ff 50 18             	call   *0x18(%rax)
 10c3446:	48 89 de             	mov    %rbx,%rsi
 10c3449:	44 89 f9             	mov    %r15d,%ecx
 10c344c:	e9 f1 c5 ff ff       	jmp    10bfa42 <zstd.emitBestSequenceCompressedBlock+0x202>

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_dense_huffman:
