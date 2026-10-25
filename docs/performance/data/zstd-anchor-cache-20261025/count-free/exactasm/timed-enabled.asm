
/tmp/vort-zstd-anchor-cache-20261025/count-free/anchor-count-free:     file format elf64-x86-64


Disassembly of section .text:

0000000001060c00 <probe.timed__anon_3146>:
 1060c00:	55                   	push   %rbp
 1060c01:	48 89 e5             	mov    %rsp,%rbp
 1060c04:	41 57                	push   %r15
 1060c06:	41 56                	push   %r14
 1060c08:	41 55                	push   %r13
 1060c0a:	41 54                	push   %r12
 1060c0c:	53                   	push   %rbx
 1060c0d:	48 83 ec 78          	sub    $0x78,%rsp
 1060c11:	4c 89 4d 88          	mov    %r9,-0x78(%rbp)
 1060c15:	4d 89 c5             	mov    %r8,%r13
 1060c18:	48 89 cb             	mov    %rcx,%rbx
 1060c1b:	49 89 d6             	mov    %rdx,%r14
 1060c1e:	49 89 f4             	mov    %rsi,%r12
 1060c21:	49 89 ff             	mov    %rdi,%r15
 1060c24:	c5 f8 10 05 1c f1 fa 	vmovups -0x50ee4(%rip),%xmm0        # 100fd48 <__anon_3065>
 1060c2b:	ff 
 1060c2c:	c5 f8 29 45 a0       	vmovaps %xmm0,-0x60(%rbp)
 1060c31:	48 c7 45 b0 00 00 00 	movq   $0x0,-0x50(%rbp)
 1060c38:	00 
 1060c39:	48 8b 36             	mov    (%rsi),%rsi
 1060c3c:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1060c41:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1060c45:	ba 01 00 00 00       	mov    $0x1,%edx
 1060c4a:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 1060c50:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 1060c54:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 1060c58:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1060c5c:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 1060c63:	48 8d 7d d4          	lea    -0x2c(%rbp),%rdi
 1060c67:	48 8d 55 a0          	lea    -0x60(%rbp),%rdx
 1060c6b:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 1060c6f:	4c 89 f6             	mov    %r14,%rsi
 1060c72:	48 89 d9             	mov    %rbx,%rcx
 1060c75:	4d 89 e8             	mov    %r13,%r8
 1060c78:	e8 53 e2 05 00       	call   10beed0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091>
 1060c7d:	0f b7 5d d4          	movzwl -0x2c(%rbp),%ebx
 1060c81:	66 85 db             	test   %bx,%bx
 1060c84:	0f 85 23 01 00 00    	jne    1060dad <probe.timed__anon_3146+0x1ad>
 1060c8a:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 1060c8e:	44 0f b6 75 18       	movzbl 0x18(%rbp),%r14d
 1060c93:	49 8b 34 24          	mov    (%r12),%rsi
 1060c97:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1060c9c:	44 0f b6 65 d6       	movzbl -0x2a(%rbp),%r12d
 1060ca1:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1060ca5:	ba 01 00 00 00       	mov    $0x1,%edx
 1060caa:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 1060cb0:	48 8b 5d 90          	mov    -0x70(%rbp),%rbx
 1060cb4:	4c 8b 6d 98          	mov    -0x68(%rbp),%r13
 1060cb8:	48 2b 5d 80          	sub    -0x80(%rbp),%rbx
 1060cbc:	4c 1b ad 78 ff ff ff 	sbb    -0x88(%rbp),%r13
 1060cc3:	41 80 e6 01          	and    $0x1,%r14b
 1060cc7:	45 38 e6             	cmp    %r12b,%r14b
 1060cca:	0f 85 89 00 00 00    	jne    1060d59 <probe.timed__anon_3146+0x159>
 1060cd0:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 1060cd4:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 1060cd8:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 1060cdc:	48 85 f6             	test   %rsi,%rsi
 1060cdf:	b8 01 00 00 00       	mov    $0x1,%eax
 1060ce4:	4c 89 e7             	mov    %r12,%rdi
 1060ce7:	48 0f 44 f8          	cmove  %rax,%rdi
 1060ceb:	48 85 c9             	test   %rcx,%rcx
 1060cee:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 1060cf2:	48 0f 44 d0          	cmove  %rax,%rdx
 1060cf6:	e8 c5 4b 09 00       	call   10f58c0 <mem.eqlBytes>
 1060cfb:	a8 01                	test   $0x1,%al
 1060cfd:	74 5a                	je     1060d59 <probe.timed__anon_3146+0x159>
 1060cff:	49 63 c5             	movslq %r13d,%rax
 1060d02:	31 c9                	xor    %ecx,%ecx
 1060d04:	48 89 da             	mov    %rbx,%rdx
 1060d07:	48 f7 da             	neg    %rdx
 1060d0a:	48 19 c1             	sbb    %rax,%rcx
 1060d0d:	0f 8d 86 00 00 00    	jge    1060d99 <probe.timed__anon_3146+0x199>
 1060d13:	66 c7 85 70 ff ff ff 	movw   $0x0,-0x90(%rbp)
 1060d1a:	00 00 
 1060d1c:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 1060d23:	48 8d 9d 68 ff ff ff 	lea    -0x98(%rbp),%rbx
 1060d2a:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 1060d2e:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060d32:	48 85 d2             	test   %rdx,%rdx
 1060d35:	74 17                	je     1060d4e <probe.timed__anon_3146+0x14e>
 1060d37:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1060d3b:	48 8b 38             	mov    (%rax),%rdi
 1060d3e:	48 8b 40 08          	mov    0x8(%rax),%rax
 1060d42:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1060d46:	4c 89 e6             	mov    %r12,%rsi
 1060d49:	31 c9                	xor    %ecx,%ecx
 1060d4b:	ff 50 18             	call   *0x18(%rax)
 1060d4e:	c5 f8 10 03          	vmovups (%rbx),%xmm0
 1060d52:	c4 c1 78 11 06       	vmovups %xmm0,(%r14)
 1060d57:	eb 31                	jmp    1060d8a <probe.timed__anon_3146+0x18a>
 1060d59:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060d5d:	48 85 d2             	test   %rdx,%rdx
 1060d60:	74 18                	je     1060d7a <probe.timed__anon_3146+0x17a>
 1060d62:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 1060d66:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1060d6a:	48 8b 38             	mov    (%rax),%rdi
 1060d6d:	48 8b 40 08          	mov    0x8(%rax),%rax
 1060d71:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1060d75:	31 c9                	xor    %ecx,%ecx
 1060d77:	ff 50 18             	call   *0x18(%rax)
 1060d7a:	c5 f8 10 05 ae f5 f9 	vmovups -0x60a52(%rip),%xmm0        # 1000330 <__anon_3151>
 1060d81:	ff 
 1060d82:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1060d86:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1060d8a:	48 83 c4 78          	add    $0x78,%rsp
 1060d8e:	5b                   	pop    %rbx
 1060d8f:	41 5c                	pop    %r12
 1060d91:	41 5d                	pop    %r13
 1060d93:	41 5e                	pop    %r14
 1060d95:	41 5f                	pop    %r15
 1060d97:	5d                   	pop    %rbp
 1060d98:	c3                   	ret    
 1060d99:	bb 70 05 00 01       	mov    $0x1000570,%ebx
 1060d9e:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 1060da2:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060da6:	48 85 d2             	test   %rdx,%rdx
 1060da9:	75 8c                	jne    1060d37 <probe.timed__anon_3146+0x137>
 1060dab:	eb a1                	jmp    1060d4e <probe.timed__anon_3146+0x14e>
 1060dad:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1060db1:	48 85 d2             	test   %rdx,%rdx
 1060db4:	74 18                	je     1060dce <probe.timed__anon_3146+0x1ce>
 1060db6:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 1060dba:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1060dbe:	48 8b 38             	mov    (%rax),%rdi
 1060dc1:	48 8b 40 08          	mov    0x8(%rax),%rax
 1060dc5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1060dc9:	31 c9                	xor    %ecx,%ecx
 1060dcb:	ff 50 18             	call   *0x18(%rax)
 1060dce:	66 41 89 5f 08       	mov    %bx,0x8(%r15)
 1060dd3:	eb b5                	jmp    1060d8a <probe.timed__anon_3146+0x18a>

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_dense_huffman:
