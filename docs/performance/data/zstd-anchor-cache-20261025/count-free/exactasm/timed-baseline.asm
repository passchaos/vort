
/tmp/vort-zstd-anchor-cache-20261025/count-free/anchor-count-free:     file format elf64-x86-64


Disassembly of section .text:

0000000001060a20 <probe.timed__anon_3112>:
 1060a20:	55                   	push   %rbp
 1060a21:	48 89 e5             	mov    %rsp,%rbp
 1060a24:	41 57                	push   %r15
 1060a26:	41 56                	push   %r14
 1060a28:	41 55                	push   %r13
 1060a2a:	41 54                	push   %r12
 1060a2c:	53                   	push   %rbx
 1060a2d:	48 83 ec 78          	sub    $0x78,%rsp
 1060a31:	4c 89 4d 88          	mov    %r9,-0x78(%rbp)
 1060a35:	4d 89 c5             	mov    %r8,%r13
 1060a38:	48 89 cb             	mov    %rcx,%rbx
 1060a3b:	49 89 d6             	mov    %rdx,%r14
 1060a3e:	49 89 f4             	mov    %rsi,%r12
 1060a41:	49 89 ff             	mov    %rdi,%r15
 1060a44:	c5 f8 10 05 fc f2 fa 	vmovups -0x50d04(%rip),%xmm0        # 100fd48 <__anon_3065>
 1060a4b:	ff 
 1060a4c:	c5 f8 29 45 a0       	vmovaps %xmm0,-0x60(%rbp)
 1060a51:	48 c7 45 b0 00 00 00 	movq   $0x0,-0x50(%rbp)
 1060a58:	00 
 1060a59:	48 8b 36             	mov    (%rsi),%rsi
 1060a5c:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1060a61:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1060a65:	ba 01 00 00 00       	mov    $0x1,%edx
 1060a6a:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 1060a70:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 1060a74:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 1060a78:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1060a7c:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 1060a83:	48 8d 7d d4          	lea    -0x2c(%rbp),%rdi
 1060a87:	48 8d 55 a0          	lea    -0x60(%rbp),%rdx
 1060a8b:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 1060a8f:	4c 89 f6             	mov    %r14,%rsi
 1060a92:	48 89 d9             	mov    %rbx,%rcx
 1060a95:	4d 89 e8             	mov    %r13,%r8
 1060a98:	e8 03 40 09 00       	call   10f4aa0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085>
 1060a9d:	0f b7 5d d4          	movzwl -0x2c(%rbp),%ebx
 1060aa1:	66 85 db             	test   %bx,%bx
 1060aa4:	0f 85 23 01 00 00    	jne    1060bcd <probe.timed__anon_3112+0x1ad>
 1060aaa:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 1060aae:	44 0f b6 75 18       	movzbl 0x18(%rbp),%r14d
 1060ab3:	49 8b 34 24          	mov    (%r12),%rsi
 1060ab7:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1060abc:	44 0f b6 65 d6       	movzbl -0x2a(%rbp),%r12d
 1060ac1:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1060ac5:	ba 01 00 00 00       	mov    $0x1,%edx
 1060aca:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 1060ad0:	48 8b 5d 90          	mov    -0x70(%rbp),%rbx
 1060ad4:	4c 8b 6d 98          	mov    -0x68(%rbp),%r13
 1060ad8:	48 2b 5d 80          	sub    -0x80(%rbp),%rbx
 1060adc:	4c 1b ad 78 ff ff ff 	sbb    -0x88(%rbp),%r13
 1060ae3:	41 80 e6 01          	and    $0x1,%r14b
 1060ae7:	45 38 e6             	cmp    %r12b,%r14b
 1060aea:	0f 85 89 00 00 00    	jne    1060b79 <probe.timed__anon_3112+0x159>
 1060af0:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 1060af4:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 1060af8:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 1060afc:	48 85 f6             	test   %rsi,%rsi
 1060aff:	b8 01 00 00 00       	mov    $0x1,%eax
 1060b04:	4c 89 e7             	mov    %r12,%rdi
 1060b07:	48 0f 44 f8          	cmove  %rax,%rdi
 1060b0b:	48 85 c9             	test   %rcx,%rcx
 1060b0e:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 1060b12:	48 0f 44 d0          	cmove  %rax,%rdx
 1060b16:	e8 a5 4d 09 00       	call   10f58c0 <mem.eqlBytes>
 1060b1b:	a8 01                	test   $0x1,%al
 1060b1d:	74 5a                	je     1060b79 <probe.timed__anon_3112+0x159>
 1060b1f:	49 63 c5             	movslq %r13d,%rax
 1060b22:	31 c9                	xor    %ecx,%ecx
 1060b24:	48 89 da             	mov    %rbx,%rdx
 1060b27:	48 f7 da             	neg    %rdx
 1060b2a:	48 19 c1             	sbb    %rax,%rcx
 1060b2d:	0f 8d 86 00 00 00    	jge    1060bb9 <probe.timed__anon_3112+0x199>
 1060b33:	66 c7 85 70 ff ff ff 	movw   $0x0,-0x90(%rbp)
 1060b3a:	00 00 
 1060b3c:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 1060b43:	48 8d 9d 68 ff ff ff 	lea    -0x98(%rbp),%rbx
 1060b4a:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 1060b4e:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060b52:	48 85 d2             	test   %rdx,%rdx
 1060b55:	74 17                	je     1060b6e <probe.timed__anon_3112+0x14e>
 1060b57:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1060b5b:	48 8b 38             	mov    (%rax),%rdi
 1060b5e:	48 8b 40 08          	mov    0x8(%rax),%rax
 1060b62:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1060b66:	4c 89 e6             	mov    %r12,%rsi
 1060b69:	31 c9                	xor    %ecx,%ecx
 1060b6b:	ff 50 18             	call   *0x18(%rax)
 1060b6e:	c5 f8 10 03          	vmovups (%rbx),%xmm0
 1060b72:	c4 c1 78 11 06       	vmovups %xmm0,(%r14)
 1060b77:	eb 31                	jmp    1060baa <probe.timed__anon_3112+0x18a>
 1060b79:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060b7d:	48 85 d2             	test   %rdx,%rdx
 1060b80:	74 18                	je     1060b9a <probe.timed__anon_3112+0x17a>
 1060b82:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 1060b86:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1060b8a:	48 8b 38             	mov    (%rax),%rdi
 1060b8d:	48 8b 40 08          	mov    0x8(%rax),%rax
 1060b91:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1060b95:	31 c9                	xor    %ecx,%ecx
 1060b97:	ff 50 18             	call   *0x18(%rax)
 1060b9a:	c5 f8 10 05 8e f7 f9 	vmovups -0x60872(%rip),%xmm0        # 1000330 <__anon_3151>
 1060ba1:	ff 
 1060ba2:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1060ba6:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1060baa:	48 83 c4 78          	add    $0x78,%rsp
 1060bae:	5b                   	pop    %rbx
 1060baf:	41 5c                	pop    %r12
 1060bb1:	41 5d                	pop    %r13
 1060bb3:	41 5e                	pop    %r14
 1060bb5:	41 5f                	pop    %r15
 1060bb7:	5d                   	pop    %rbp
 1060bb8:	c3                   	ret    
 1060bb9:	bb 70 05 00 01       	mov    $0x1000570,%ebx
 1060bbe:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 1060bc2:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060bc6:	48 85 d2             	test   %rdx,%rdx
 1060bc9:	75 8c                	jne    1060b57 <probe.timed__anon_3112+0x137>
 1060bcb:	eb a1                	jmp    1060b6e <probe.timed__anon_3112+0x14e>
 1060bcd:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060bd1:	48 85 d2             	test   %rdx,%rdx
 1060bd4:	74 18                	je     1060bee <probe.timed__anon_3112+0x1ce>
 1060bd6:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 1060bda:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1060bde:	48 8b 38             	mov    (%rax),%rdi
 1060be1:	48 8b 40 08          	mov    0x8(%rax),%rax
 1060be5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1060be9:	31 c9                	xor    %ecx,%ecx
 1060beb:	ff 50 18             	call   *0x18(%rax)
 1060bee:	66 41 89 5f 08       	mov    %bx,0x8(%r15)
 1060bf3:	eb b5                	jmp    1060baa <probe.timed__anon_3112+0x18a>

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_dense_huffman:
