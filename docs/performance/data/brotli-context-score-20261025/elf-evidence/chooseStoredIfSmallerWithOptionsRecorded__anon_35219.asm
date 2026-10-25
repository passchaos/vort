
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001174910 <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219>:
 1174910:	55                   	push   %rbp
 1174911:	48 89 e5             	mov    %rsp,%rbp
 1174914:	41 57                	push   %r15
 1174916:	41 56                	push   %r14
 1174918:	41 55                	push   %r13
 117491a:	41 54                	push   %r12
 117491c:	53                   	push   %rbx
 117491d:	48 83 ec 48          	sub    $0x48,%rsp
 1174921:	4d 89 ce             	mov    %r9,%r14
 1174924:	4c 89 45 d0          	mov    %r8,-0x30(%rbp)
 1174928:	49 89 cd             	mov    %rcx,%r13
 117492b:	48 89 55 c0          	mov    %rdx,-0x40(%rbp)
 117492f:	49 89 f4             	mov    %rsi,%r12
 1174932:	48 89 fb             	mov    %rdi,%rbx
 1174935:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 1174939:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 117493d:	48 89 ce             	mov    %rcx,%rsi
 1174940:	e8 6b 55 07 00       	call   11e9eb0 <br.encodedStoredStreamBoundWithOptions>
 1174945:	44 0f b7 7d b8       	movzwl -0x48(%rbp),%r15d
 117494a:	66 45 85 ff          	test   %r15w,%r15w
 117494e:	75 7c                	jne    11749cc <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219+0xbc>
 1174950:	4c 3b 75 b0          	cmp    -0x50(%rbp),%r14
 1174954:	76 56                	jbe    11749ac <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219+0x9c>
 1174956:	48 8d 7d 98          	lea    -0x68(%rbp),%rdi
 117495a:	4c 89 e6             	mov    %r12,%rsi
 117495d:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 1174961:	4c 89 e9             	mov    %r13,%rcx
 1174964:	4c 8b 45 10          	mov    0x10(%rbp),%r8
 1174968:	e8 13 47 07 00       	call   11e9080 <br.encodeStoredStreamWithOptionsAlloc>
 117496d:	44 0f b7 7d a8       	movzwl -0x58(%rbp),%r15d
 1174972:	66 45 85 ff          	test   %r15w,%r15w
 1174976:	75 59                	jne    11749d1 <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219+0xc1>
 1174978:	c5 f8 10 45 98       	vmovups -0x68(%rbp),%xmm0
 117497d:	c5 f8 29 45 c0       	vmovaps %xmm0,-0x40(%rbp)
 1174982:	49 8b 3c 24          	mov    (%r12),%rdi
 1174986:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 117498b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 117498f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1174993:	4c 89 f2             	mov    %r14,%rdx
 1174996:	31 c9                	xor    %ecx,%ecx
 1174998:	ff 50 18             	call   *0x18(%rax)
 117499b:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 11749a1:	c5 f8 28 45 c0       	vmovaps -0x40(%rbp),%xmm0
 11749a6:	c5 f8 11 03          	vmovups %xmm0,(%rbx)
 11749aa:	eb 11                	jmp    11749bd <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219+0xad>
 11749ac:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 11749b2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 11749b6:	48 89 03             	mov    %rax,(%rbx)
 11749b9:	4c 89 73 08          	mov    %r14,0x8(%rbx)
 11749bd:	48 83 c4 48          	add    $0x48,%rsp
 11749c1:	5b                   	pop    %rbx
 11749c2:	41 5c                	pop    %r12
 11749c4:	41 5d                	pop    %r13
 11749c6:	41 5e                	pop    %r14
 11749c8:	41 5f                	pop    %r15
 11749ca:	5d                   	pop    %rbp
 11749cb:	c3                   	ret    
 11749cc:	4d 85 f6             	test   %r14,%r14
 11749cf:	74 19                	je     11749ea <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219+0xda>
 11749d1:	49 8b 3c 24          	mov    (%r12),%rdi
 11749d5:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 11749da:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11749de:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 11749e2:	4c 89 f2             	mov    %r14,%rdx
 11749e5:	31 c9                	xor    %ecx,%ecx
 11749e7:	ff 50 18             	call   *0x18(%rax)
 11749ea:	66 44 89 7b 10       	mov    %r15w,0x10(%rbx)
 11749ef:	eb cc                	jmp    11749bd <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219+0xad>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
