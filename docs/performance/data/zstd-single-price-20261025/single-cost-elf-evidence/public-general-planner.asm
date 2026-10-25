
/home/passchaos/project-z/vort-zstd-single-price/.zig-cache/o/42267594774fd3ad0fdebe27688508e1/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001152700 <zstd.planPredefinedSequenceValues>:
 1152700:	push   %rbp
 1152701:	mov    %rsp,%rbp
 1152704:	push   %r15
 1152706:	push   %r14
 1152708:	push   %r13
 115270a:	push   %r12
 115270c:	push   %rbx
 115270d:	sub    $0x8248,%rsp
 1152714:	mov    %rsi,-0x58(%rbp)
 1152718:	lea    -0x201(%rdx),%rax
 115271f:	cmp    $0xfffffffffffffdff,%rax
 1152725:	jbe    1152730 <zstd.planPredefinedSequenceValues+0x30>
 1152727:	mov    %r8,%r14
 115272a:	cmp    $0x40,%r8
 115272e:	jbe    115274d <zstd.planPredefinedSequenceValues+0x4d>
 1152730:	mov    $0x218,%edx
 1152735:	xor    %esi,%esi
 1152737:	add    $0x8248,%rsp
 115273e:	pop    %rbx
 115273f:	pop    %r12
 1152741:	pop    %r13
 1152743:	pop    %r14
 1152745:	pop    %r15
 1152747:	pop    %rbp
 1152748:	jmp    119dff0 <compiler_rt.memset>
 115274d:	mov    %rcx,%r13
 1152750:	mov    %rdi,-0x48(%rbp)
 1152754:	lea    -0x141267(%rip),%rax        # 10114f4 <__anon_35603>
 115275b:	cmp    %rax,%rcx
 115275e:	sete   %cl
 1152761:	test   %r9b,%r9b
 1152764:	sete   %al
 1152767:	and    %al,%cl
 1152769:	mov    %cl,-0x2b(%rbp)
 115276c:	lea    -0x14157f(%rip),%rcx        # 10111f4 <__anon_35443>
 1152773:	cmp    %rcx,%r13
 1152776:	sete   %cl
 1152779:	cmp    $0x2,%r9b
 115277d:	sete   %sil
 1152781:	and    %cl,%sil
 1152784:	mov    %sil,-0x2a(%rbp)
 1152788:	lea    -0x14149b(%rip),%rcx        # 10112f4 <__anon_35529>
 115278f:	cmp    %rcx,%r13
 1152792:	sete   %cl
 1152795:	and    %al,%cl
 1152797:	mov    %cl,-0x29(%rbp)
 115279a:	mov    %r14d,%eax
 115279d:	and    $0x7e,%eax
 11527a0:	mov    %rax,-0x60(%rbp)
 11527a4:	mov    $0x1,%r11d
 11527aa:	mov    %rdx,-0x50(%rbp)
 11527ae:	mov    %rdx,%r12
 11527b1:	xor    %ecx,%ecx
 11527b3:	mov    %r9d,-0x30(%rbp)
 11527b7:	jmp    1152807 <zstd.planPredefinedSequenceValues+0x107>
 11527b9:	nopl   0x0(%rax)
 11527c0:	mov    $0x24,%ecx
 11527c5:	lea    -0x34(%rbp),%rdi
 11527c9:	lea    -0x12b7f0(%rip),%rdx        # 1026fe0 <__anon_35791>
 11527d0:	lea    -0x1176d7(%rip),%r8        # 103b100 <zstd.match.hq_parser.prices.ll_bits>
 11527d7:	call   1147f20 <zstd.sequenceCodeForValue>
 11527dc:	mov    $0x1,%r11d
 11527e2:	mov    -0x30(%rbp),%r9d
 11527e6:	cmpw   $0x0,-0x34(%rbp)
 11527eb:	lea    -0x32(%rbp),%rax
 11527ef:	lea    -0x12561e(%rip),%rcx        # 102d1d8 <__anon_40686>
 11527f6:	je     11528b0 <zstd.planPredefinedSequenceValues+0x1b0>
 11527fc:	xor    %ecx,%ecx
 11527fe:	test   %r12,%r12
 1152801:	je     1152a5a <zstd.planPredefinedSequenceValues+0x35a>
 1152807:	mov    %rcx,%r15
 115280a:	mov    %r12,%rbx
 115280d:	dec    %r12
 1152810:	mov    -0x58(%rbp),%rax
 1152814:	mov    -0x8(%rax,%rbx,8),%rsi
 1152819:	cmpb   $0x0,-0x2b(%rbp)
 115281d:	jne    11527c0 <zstd.planPredefinedSequenceValues+0xc0>
 115281f:	cmpb   $0x0,-0x2a(%rbp)
 1152823:	je     1152860 <zstd.planPredefinedSequenceValues+0x160>
 1152825:	mov    $0x20,%ecx
 115282a:	lea    -0x38(%rbp),%rdi
 115282e:	lea    -0x12bafd(%rip),%rdx        # 1026d38 <__anon_35839>
 1152835:	lea    -0x14ff9c(%rip),%r8        # 10028a0 <__anon_35844>
 115283c:	call   1147f20 <zstd.sequenceCodeForValue>
 1152841:	mov    $0x1,%r11d
 1152847:	mov    -0x30(%rbp),%r9d
 115284b:	cmpw   $0x0,-0x38(%rbp)
 1152850:	lea    -0x36(%rbp),%rax
 1152854:	lea    -0x1253bb(%rip),%rcx        # 102d4a0 <__anon_41663>
 115285b:	jne    11527fc <zstd.planPredefinedSequenceValues+0xfc>
 115285d:	jmp    11528b0 <zstd.planPredefinedSequenceValues+0x1b0>
 115285f:	nop
 1152860:	cmpb   $0x0,-0x29(%rbp)
 1152864:	je     115296c <zstd.planPredefinedSequenceValues+0x26c>
 115286a:	mov    $0x35,%ecx
 115286f:	lea    -0x3c(%rbp),%rdi
 1152873:	lea    -0x12ba42(%rip),%rdx        # 1026e38 <__anon_35859>
 115287a:	lea    -0x119db9(%rip),%r8        # 1038ac8 <zstd.match.hq_parser.prices.ml_bits>
 1152881:	call   1147f20 <zstd.sequenceCodeForValue>
 1152886:	mov    $0x1,%r11d
 115288c:	mov    -0x30(%rbp),%r9d
 1152890:	cmpw   $0x0,-0x3c(%rbp)
 1152895:	lea    -0x3a(%rbp),%rax
 1152899:	lea    -0x1255a8(%rip),%rcx        # 102d2f8 <__anon_40813>
 11528a0:	jne    11527fc <zstd.planPredefinedSequenceValues+0xfc>
 11528a6:	cs nopw 0x0(%rax,%rax,1)
 11528b0:	movzbl (%rax),%eax
 11528b3:	mov    (%rcx,%rax,8),%rax
 11528b7:	test   %rax,%rax
 11528ba:	je     11527fc <zstd.planPredefinedSequenceValues+0xfc>
 11528c0:	cmp    -0x50(%rbp),%rbx
 11528c4:	jne    11528e4 <zstd.planPredefinedSequenceValues+0x1e4>
 11528c6:	xor    %ecx,%ecx
 11528c8:	nopl   0x0(%rax,%rax,1)
 11528d0:	blsi   %rax,%rdx
 11528d5:	or     %rdx,%rcx
 11528d8:	blsr   %rax,%rax
 11528dd:	jne    11528d0 <zstd.planPredefinedSequenceValues+0x1d0>
 11528df:	jmp    11527fe <zstd.planPredefinedSequenceValues+0xfe>
 11528e4:	mov    %r12,%rcx
 11528e7:	shl    $0x6,%rcx
 11528eb:	lea    (%rcx,%rbp,1),%rdx
 11528ef:	add    $0xffffffffffff7d98,%rdx
 11528f6:	xor    %ecx,%ecx
 11528f8:	mov    $0xffffffffffffffff,%r10
 11528ff:	jmp    115291b <zstd.planPredefinedSequenceValues+0x21b>
 1152901:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1152910:	blsr   %rax,%rax
 1152915:	je     11527fe <zstd.planPredefinedSequenceValues+0xfe>
 115291b:	tzcnt  %rax,%rsi
 1152920:	movzwl 0x4(%r13,%rsi,8),%edi
 1152926:	cmp    %rdi,%r14
 1152929:	jbe    1152910 <zstd.planPredefinedSequenceValues+0x210>
 115292b:	movzbl 0x7(%r13,%rsi,8),%r8d
 1152931:	shlx   %r8,%r11,%r8
 1152936:	add    %rdi,%r8
 1152939:	cmp    %r8,%r14
 115293c:	cmovb  %r14,%r8
 1152940:	sub    %rdi,%r8
 1152943:	cmp    $0x40,%r8
 1152947:	shlx   %r8,%r10,%r8
 115294c:	not    %r8
 115294f:	cmove  %r10,%r8
 1152953:	shlx   %rdi,%r8,%rdi
 1152958:	and    %r15,%rdi
 115295b:	je     1152910 <zstd.planPredefinedSequenceValues+0x210>
 115295d:	bts    %rsi,%rcx
 1152961:	tzcnt  %rdi,%rdi
 1152966:	mov    %dil,(%rdx,%rsi,1)
 115296a:	jmp    1152910 <zstd.planPredefinedSequenceValues+0x210>
 115296c:	test   %r14,%r14
 115296f:	je     11527fc <zstd.planPredefinedSequenceValues+0xfc>
 1152975:	xor    %ecx,%ecx
 1152977:	xor    %eax,%eax
 1152979:	cmp    $0x1,%r14
 115297d:	jne    11529da <zstd.planPredefinedSequenceValues+0x2da>
 115297f:	test   $0x1,%r14b
 1152983:	je     11528b7 <zstd.planPredefinedSequenceValues+0x1b7>
 1152989:	mov    0x0(%r13,%rcx,8),%rdx
 115298e:	mov    %edx,%edi
 1152990:	shr    $0x30,%rdx
 1152994:	cmp    %dl,%r9b
 1152997:	seta   %r8b
 115299b:	sub    %rdi,%rsi
 115299e:	setb   %dil
 11529a2:	or     %r8b,%dil
 11529a5:	jne    11528b7 <zstd.planPredefinedSequenceValues+0x1b7>
 11529ab:	shrx   %rdx,%rsi,%rdx
 11529b0:	test   %rdx,%rdx
 11529b3:	shlx   %rcx,%r11,%rcx
 11529b8:	mov    $0x0,%edx
 11529bd:	cmovne %rdx,%rcx
 11529c1:	or     %rcx,%rax
 11529c4:	jmp    11528b7 <zstd.planPredefinedSequenceValues+0x1b7>
 11529c9:	nopl   0x0(%rax)
 11529d0:	add    $0x2,%rcx
 11529d4:	cmp    %rcx,-0x60(%rbp)
 11529d8:	je     115297f <zstd.planPredefinedSequenceValues+0x27f>
 11529da:	mov    0x0(%r13,%rcx,8),%rdx
 11529df:	mov    %edx,%r8d
 11529e2:	shr    $0x30,%rdx
 11529e6:	cmp    %dl,%r9b
 11529e9:	seta   %r10b
 11529ed:	mov    %rsi,%rdi
 11529f0:	sub    %r8,%rdi
 11529f3:	setb   %r8b
 11529f7:	or     %r10b,%r8b
 11529fa:	jne    1152a15 <zstd.planPredefinedSequenceValues+0x315>
 11529fc:	shrx   %rdx,%rdi,%rdx
 1152a01:	test   %rdx,%rdx
 1152a04:	shlx   %rcx,%r11,%rdx
 1152a09:	mov    $0x0,%edi
 1152a0e:	cmovne %rdi,%rdx
 1152a12:	or     %rdx,%rax
 1152a15:	mov    0x8(%r13,%rcx,8),%rdx
 1152a1a:	mov    %edx,%r8d
 1152a1d:	shr    $0x30,%rdx
 1152a21:	cmp    %dl,%r9b
 1152a24:	seta   %r10b
 1152a28:	mov    %rsi,%rdi
 1152a2b:	sub    %r8,%rdi
 1152a2e:	setb   %r8b
 1152a32:	or     %r10b,%r8b
 1152a35:	jne    11529d0 <zstd.planPredefinedSequenceValues+0x2d0>
 1152a37:	shrx   %rdx,%rdi,%rdx
 1152a3c:	test   %rdx,%rdx
 1152a3f:	mov    $0x2,%edx
 1152a44:	shlx   %rcx,%rdx,%rdx
 1152a49:	mov    $0x0,%edi
 1152a4e:	cmovne %rdi,%rdx
 1152a52:	or     %rdx,%rax
 1152a55:	jmp    11529d0 <zstd.planPredefinedSequenceValues+0x2d0>
 1152a5a:	test   %rcx,%rcx
 1152a5d:	je     1152abc <zstd.planPredefinedSequenceValues+0x3bc>
 1152a5f:	tzcnt  %rcx,%rax
 1152a64:	mov    -0x50(%rbp),%rsi
 1152a68:	mov    %rsi,-0x268(%rbp)
 1152a6f:	mov    %al,-0x260(%rbp)
 1152a75:	dec    %rsi
 1152a78:	lea    -0x8268(%rbp),%rcx
 1152a7f:	xor    %edx,%edx
 1152a81:	mov    -0x48(%rbp),%rbx
 1152a85:	data16 cs nopw 0x0(%rax,%rax,1)
 1152a90:	cmp    %rdx,%rsi
 1152a93:	je     1152aca <zstd.planPredefinedSequenceValues+0x3ca>
 1152a95:	movzbl %al,%eax
 1152a98:	movzbl (%rcx,%rax,1),%eax
 1152a9c:	mov    %al,-0x25f(%rbp,%rdx,1)
 1152aa3:	inc    %rdx
 1152aa6:	add    $0x40,%rcx
 1152aaa:	cmp    %rax,%r14
 1152aad:	ja     1152a90 <zstd.planPredefinedSequenceValues+0x390>
 1152aaf:	mov    $0x218,%edx
 1152ab4:	mov    %rbx,%rdi
 1152ab7:	jmp    1152735 <zstd.planPredefinedSequenceValues+0x35>
 1152abc:	mov    $0x218,%edx
 1152ac1:	mov    -0x48(%rbp),%rdi
 1152ac5:	jmp    1152735 <zstd.planPredefinedSequenceValues+0x35>
 1152aca:	movw   $0x0,0x210(%rbx)
 1152ad3:	lea    -0x268(%rbp),%rsi
 1152ada:	mov    $0x208,%edx
 1152adf:	mov    %rbx,%rdi
 1152ae2:	call   119e410 <compiler_rt.memcpy.memcpyFast>
 1152ae7:	movb   $0x1,0x208(%rbx)
 1152aee:	add    $0x8248,%rsp
 1152af5:	pop    %rbx
 1152af6:	pop    %r12
 1152af8:	pop    %r13
 1152afa:	pop    %r14
 1152afc:	pop    %r15
 1152afe:	pop    %rbp
 1152aff:	ret    

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
