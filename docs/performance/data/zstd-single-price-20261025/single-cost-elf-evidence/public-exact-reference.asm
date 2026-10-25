
/home/passchaos/project-z/vort-zstd-single-price/.zig-cache/o/42267594774fd3ad0fdebe27688508e1/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000115de80 <zstd.singleBestSequencePayloadLen>:
 115de80:	push   %rbp
 115de81:	mov    %rsp,%rbp
 115de84:	push   %r15
 115de86:	push   %r14
 115de88:	push   %r12
 115de8a:	push   %rbx
 115de8b:	sub    $0x50,%rsp
 115de8f:	mov    %rdi,%rbx
 115de92:	mov    0x10(%rbp),%rax
 115de96:	mov    %rcx,-0x28(%rbp)
 115de9a:	mov    %r8,-0x30(%rbp)
 115de9e:	mov    %r9,-0x38(%rbp)
 115dea2:	lea    -0x48(%rbp),%rdi
 115dea6:	lea    -0x28(%rbp),%rcx
 115deaa:	lea    0x10(%rbp),%r9
 115deae:	mov    $0x1,%r8d
 115deb4:	push   %rax
 115deb5:	push   $0x1
 115deb7:	call   1152c20 <zstd.sequenceLiteralsPayloadSectionLen>
 115debc:	add    $0x10,%rsp
 115dec0:	movzwl -0x40(%rbp),%eax
 115dec4:	test   %ax,%ax
 115dec7:	jne    115df78 <zstd.singleBestSequencePayloadLen+0xf8>
 115decd:	mov    -0x48(%rbp),%r15
 115ded1:	lea    -0x58(%rbp),%rdi
 115ded5:	lea    -0x28(%rbp),%rsi
 115ded9:	lea    -0x30(%rbp),%rcx
 115dedd:	lea    -0x38(%rbp),%r9
 115dee1:	mov    $0x1,%edx
 115dee6:	mov    $0x1,%r8d
 115deec:	push   %r15
 115deee:	push   $0x1
 115def0:	call   1155620 <zstd.rleSequencePayloadLenForValuesWithLiteralsLen>
 115def5:	add    $0x10,%rsp
 115def9:	movzwl -0x50(%rbp),%eax
 115defd:	test   %eax,%eax
 115deff:	jne    115df60 <zstd.singleBestSequencePayloadLen+0xe0>
 115df01:	mov    -0x58(%rbp),%r14
 115df05:	xor    %r12d,%r12d
 115df08:	lea    -0x68(%rbp),%rdi
 115df0c:	lea    -0x28(%rbp),%rsi
 115df10:	lea    -0x30(%rbp),%rcx
 115df14:	lea    -0x38(%rbp),%r9
 115df18:	mov    $0x1,%edx
 115df1d:	mov    $0x1,%r8d
 115df23:	push   %r15
 115df25:	push   $0x1
 115df27:	call   1155120 <zstd.predefinedSequencePayloadLenWithLiteralsLen>
 115df2c:	add    $0x10,%rsp
 115df30:	movzwl -0x60(%rbp),%eax
 115df34:	test   %eax,%eax
 115df36:	jne    115df6a <zstd.singleBestSequencePayloadLen+0xea>
 115df38:	mov    -0x68(%rbp),%rax
 115df3c:	cmp    %r14,%rax
 115df3f:	cmovb  %rax,%r14
 115df43:	test   %r12b,%r12b
 115df46:	cmovne %rax,%r14
 115df4a:	movw   $0x0,0x8(%rbx)
 115df50:	mov    %r14,(%rbx)
 115df53:	add    $0x50,%rsp
 115df57:	pop    %rbx
 115df58:	pop    %r12
 115df5a:	pop    %r14
 115df5c:	pop    %r15
 115df5e:	pop    %rbp
 115df5f:	ret    
 115df60:	cmp    $0x28,%eax
 115df63:	jne    115df7e <zstd.singleBestSequencePayloadLen+0xfe>
 115df65:	mov    $0x1,%r12b
 115df68:	jmp    115df08 <zstd.singleBestSequencePayloadLen+0x88>
 115df6a:	cmp    $0x28,%eax
 115df6d:	jne    115df7e <zstd.singleBestSequencePayloadLen+0xfe>
 115df6f:	mov    $0x28,%ax
 115df73:	test   %r12b,%r12b
 115df76:	je     115df4a <zstd.singleBestSequencePayloadLen+0xca>
 115df78:	mov    %ax,0x8(%rbx)
 115df7c:	jmp    115df53 <zstd.singleBestSequencePayloadLen+0xd3>
 115df7e:	test   %ax,%ax
 115df81:	je     115df4a <zstd.singleBestSequencePayloadLen+0xca>
 115df83:	jmp    115df78 <zstd.singleBestSequencePayloadLen+0xf8>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_zstd_huffman_wide_x2:

Disassembly of section .vort_zstd_huffman_only_decode:

Disassembly of section .vort_zstd_frr_decode:

Disassembly of section .vort_zstd_zz_frr_pair:

Disassembly of section .vort_zstd_ffr_decode:

Disassembly of section .vort_zstd_raw_fse_decode:

Disassembly of section .vort_zstd_zz_ffr_pair:

Disassembly of section .vort_zstd_split_zz:

Disassembly of section .vort_zstd_split_wide_literal_decode:

Disassembly of section .vort_zstd_split_dense_literal_decode:

Disassembly of section .vort_zstd_split_literal_decode:

Disassembly of section .vort_zstd_zzz_long_match:

Disassembly of section .vort_zstd_zz_fse_mapped:

Disassembly of section .vort_zstd_fse_256:

Disassembly of section .vort_zstd_fse_counts:

Disassembly of section .vort_zstd_huffman_build:

Disassembly of section .vort_zstd_medium_split:

Disassembly of section .vort_zstd_tiny_raw:

Disassembly of section .vort_zstd_small_frame_decode:

Disassembly of section .vort_zstd_small_sequence_decode:

Disassembly of section .vort_zstd_fast_records:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_dense_huffman:

Disassembly of section .vort_zstd_fast_encode:

Disassembly of section .vort_zstd_fast_large:

Disassembly of section .vort_zstd_fast_plan:

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_zz_optimal:

Disassembly of section .vort_zstd_single_beam:

Disassembly of section .plt:
