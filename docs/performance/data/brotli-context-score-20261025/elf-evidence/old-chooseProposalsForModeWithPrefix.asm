
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000123ea90 <br.encoder.literal_context_split.chooseProposalsForModeWithPrefix>:
 123ea90:	55                   	push   %rbp
 123ea91:	48 89 e5             	mov    %rsp,%rbp
 123ea94:	41 56                	push   %r14
 123ea96:	53                   	push   %rbx
 123ea97:	48 81 ec 10 01 00 00 	sub    $0x110,%rsp
 123ea9e:	48 89 fb             	mov    %rdi,%rbx
 123eaa1:	8b 45 18             	mov    0x18(%rbp),%eax
 123eaa4:	44 8b 55 10          	mov    0x10(%rbp),%r10d
 123eaa8:	4c 8d b5 e0 fe ff ff 	lea    -0x120(%rbp),%r14
 123eaaf:	4c 89 f7             	mov    %r14,%rdi
 123eab2:	50                   	push   %rax
 123eab3:	41 52                	push   %r10
 123eab5:	e8 26 8c fd ff       	call   12176e0 <br.encoder.literal_context_split.chooseModeProposals>
 123eaba:	48 83 c4 10          	add    $0x10,%rsp
 123eabe:	ba 10 01 00 00       	mov    $0x110,%edx
 123eac3:	48 89 df             	mov    %rbx,%rdi
 123eac6:	4c 89 f6             	mov    %r14,%rsi
 123eac9:	e8 f2 75 05 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 123eace:	48 81 c4 10 01 00 00 	add    $0x110,%rsp
 123ead5:	5b                   	pop    %rbx
 123ead6:	41 5e                	pop    %r14
 123ead8:	5d                   	pop    %rbp
 123ead9:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
