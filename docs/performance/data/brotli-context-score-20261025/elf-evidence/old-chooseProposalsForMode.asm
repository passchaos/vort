
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000012179f0 <br.encoder.literal_context_split.chooseProposalsForMode>:
 12179f0:	55                   	push   %rbp
 12179f1:	48 89 e5             	mov    %rsp,%rbp
 12179f4:	41 56                	push   %r14
 12179f6:	53                   	push   %rbx
 12179f7:	48 81 ec 10 01 00 00 	sub    $0x110,%rsp
 12179fe:	48 89 fb             	mov    %rdi,%rbx
 1217a01:	4c 8d b5 e0 fe ff ff 	lea    -0x120(%rbp),%r14
 1217a08:	4c 89 f7             	mov    %r14,%rdi
 1217a0b:	6a 00                	push   $0x0
 1217a0d:	6a 00                	push   $0x0
 1217a0f:	e8 cc fc ff ff       	call   12176e0 <br.encoder.literal_context_split.chooseModeProposals>
 1217a14:	48 83 c4 10          	add    $0x10,%rsp
 1217a18:	ba 10 01 00 00       	mov    $0x110,%edx
 1217a1d:	48 89 df             	mov    %rbx,%rdi
 1217a20:	4c 89 f6             	mov    %r14,%rsi
 1217a23:	e8 98 e6 07 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 1217a28:	48 81 c4 10 01 00 00 	add    $0x110,%rsp
 1217a2f:	5b                   	pop    %rbx
 1217a30:	41 5e                	pop    %r14
 1217a32:	5d                   	pop    %rbp
 1217a33:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
