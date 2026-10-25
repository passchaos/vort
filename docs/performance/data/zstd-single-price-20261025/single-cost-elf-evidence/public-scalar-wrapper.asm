
/home/passchaos/project-z/vort-zstd-single-price/.zig-cache/o/42267594774fd3ad0fdebe27688508e1/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000115df90 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase>:
 115df90:	push   %rbp
 115df91:	mov    %rsp,%rbp
 115df94:	cmp    $0x10,%rsi
 115df98:	jae    115df9f <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xf>
 115df9a:	mov    %rsi,%rax
 115df9d:	jmp    115dffb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115df9f:	cmp    $0x17,%rsi
 115dfa3:	ja     115dfb8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x28>
 115dfa5:	add    $0x1f0,%rsi
 115dfac:	shr    %rsi
 115dfaf:	add    $0x10,%rsi
 115dfb3:	mov    %rsi,%rax
 115dfb6:	jmp    115dffb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115dfb8:	cmp    $0x1f,%rsi
 115dfbc:	ja     115dfd2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x42>
 115dfbe:	add    $0x3e8,%rsi
 115dfc5:	shr    $0x2,%rsi
 115dfc9:	add    $0x14,%rsi
 115dfcd:	mov    %rsi,%rax
 115dfd0:	jmp    115dffb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115dfd2:	cmp    $0x2f,%rsi
 115dfd6:	ja     115dfec <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x5c>
 115dfd8:	add    $0x7e0,%rsi
 115dfdf:	shr    $0x3,%rsi
 115dfe3:	add    $0x16,%rsi
 115dfe7:	mov    %rsi,%rax
 115dfea:	jmp    115dffb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115dfec:	mov    $0x18,%eax
 115dff1:	cmp    $0x40,%rsi
 115dff5:	jae    115e0da <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x14a>
 115dffb:	test   %rdx,%rdx
 115dffe:	je     115e07f <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xef>
 115e000:	lea    -0x15bbd7(%rip),%r8        # 1002430 <__anon_1386>
 115e007:	cmp    $0xfffffffffffffffc,%rdx
 115e00b:	ja     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e011:	mov    $0xfffffffc,%esi
 115e016:	cmp    %rsi,%rdx
 115e019:	ja     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e01f:	lea    0x3(%rdx),%rsi
 115e023:	lzcnt  %rsi,%rsi
 115e028:	not    %esi
 115e02a:	mov    %esi,%r9d
 115e02d:	and    $0x3f,%r9d
 115e031:	lea    -0x137300(%rip),%r10        # 1026d38 <__anon_35839>
 115e038:	sub    (%r10,%r9,8),%rdx
 115e03c:	jb     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e042:	lea    -0x15b7a9(%rip),%r10        # 10028a0 <__anon_35844>
 115e049:	movzbl (%r9,%r10,1),%r9d
 115e04e:	shrx   %r9,%rdx,%rdx
 115e053:	test   %rdx,%rdx
 115e056:	jne    115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e05c:	and    $0x3f,%sil
 115e060:	cmp    $0x1f,%sil
 115e064:	ja     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e06a:	cmp    $0x22,%rcx
 115e06e:	ja     115e087 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xf7>
 115e070:	add    $0xfd,%rcx
 115e077:	mov    %rcx,%rdx
 115e07a:	jmp    115e157 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e07f:	xor    %esi,%esi
 115e081:	cmp    $0x22,%rcx
 115e085:	jbe    115e070 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xe0>
 115e087:	cmp    $0x2a,%rcx
 115e08b:	ja     115e0a3 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x113>
 115e08d:	add    $0x1dd,%rcx
 115e094:	shr    %rcx
 115e097:	add    $0x20,%rcx
 115e09b:	mov    %rcx,%rdx
 115e09e:	jmp    115e157 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e0a3:	cmp    $0x32,%rcx
 115e0a7:	ja     115e0c0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x130>
 115e0a9:	add    $0x3d5,%rcx
 115e0b0:	shr    $0x2,%rcx
 115e0b4:	add    $0x24,%rcx
 115e0b8:	mov    %rcx,%rdx
 115e0bb:	jmp    115e157 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e0c0:	cmp    $0x42,%rcx
 115e0c4:	ja     115e12b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x19b>
 115e0c6:	add    $0x7cd,%rcx
 115e0cd:	shr    $0x3,%rcx
 115e0d1:	add    $0x26,%rcx
 115e0d5:	mov    %rcx,%rdx
 115e0d8:	jmp    115e157 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e0da:	lea    -0x15bcb1(%rip),%r8        # 1002430 <__anon_1386>
 115e0e1:	cmp    $0x1ffff,%rsi
 115e0e8:	ja     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e0ee:	lzcnt  %rsi,%r9
 115e0f3:	mov    $0x52,%eax
 115e0f8:	sub    %r9,%rax
 115e0fb:	lea    -0x137122(%rip),%r9        # 1026fe0 <__anon_35791>
 115e102:	sub    (%r9,%rax,8),%rsi
 115e106:	jb     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e10c:	lea    -0x123013(%rip),%r9        # 103b100 <zstd.match.hq_parser.prices.ll_bits>
 115e113:	movzbl (%rax,%r9,1),%r9d
 115e118:	shrx   %r9,%rsi,%rsi
 115e11d:	test   %rsi,%rsi
 115e120:	jne    115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e126:	jmp    115dffb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115e12b:	cmp    $0x62,%rcx
 115e12f:	ja     115e145 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1b5>
 115e131:	add    $0xfbd,%rcx
 115e138:	shr    $0x4,%rcx
 115e13c:	add    $0x28,%rcx
 115e140:	mov    %rcx,%rdx
 115e143:	jmp    115e157 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e145:	mov    $0x2a,%edx
 115e14a:	cmp    $0x83,%rcx
 115e151:	jae    115e1fd <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x26d>
 115e157:	lea    -0x15bd2e(%rip),%r8        # 1002430 <__anon_1386>
 115e15e:	xor    %ecx,%ecx
 115e160:	test   %cl,%cl
 115e162:	jne    115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e168:	movzbl %al,%r9d
 115e16c:	lea    -0x123073(%rip),%rax        # 103b100 <zstd.match.hq_parser.prices.ll_bits>
 115e173:	movzbl (%r9,%rax,1),%eax
 115e178:	movzbl %sil,%esi
 115e17c:	lea    -0x15b8e3(%rip),%rcx        # 10028a0 <__anon_35844>
 115e183:	movzbl (%rsi,%rcx,1),%r10d
 115e188:	add    %rax,%r10
 115e18b:	movzbl %dl,%edx
 115e18e:	lea    -0x1256cd(%rip),%rax        # 1038ac8 <zstd.match.hq_parser.prices.ml_bits>
 115e195:	movzbl (%rdx,%rax,1),%ecx
 115e199:	add    %r10,%rcx
 115e19c:	mov    %ecx,%eax
 115e19e:	shr    $0x3,%eax
 115e1a1:	add    $0x6,%rax
 115e1a5:	lea    -0x130fd4(%rip),%r10        # 102d1d8 <__anon_40686>
 115e1ac:	cmpq   $0x0,(%r10,%r9,8)
 115e1b1:	je     115e1e6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x256>
 115e1b3:	lea    -0x130d1a(%rip),%r9        # 102d4a0 <__anon_41663>
 115e1ba:	cmpq   $0x0,(%r9,%rsi,8)
 115e1bf:	je     115e1e6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x256>
 115e1c1:	lea    -0x130ed0(%rip),%rsi        # 102d2f8 <__anon_40813>
 115e1c8:	cmpq   $0x0,(%rsi,%rdx,8)
 115e1cd:	je     115e1e6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x256>
 115e1cf:	xor    %edx,%edx
 115e1d1:	test   %dl,%dl
 115e1d3:	jne    115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e1d5:	add    $0x19,%ecx
 115e1d8:	shr    $0x3,%ecx
 115e1db:	add    $0x2,%rcx
 115e1df:	cmp    %rax,%rcx
 115e1e2:	cmovb  %rcx,%rax
 115e1e6:	mov    %rax,-0x10(%rbp)
 115e1ea:	movb   $0x1,-0x8(%rbp)
 115e1ee:	lea    -0x10(%rbp),%r8
 115e1f2:	vmovups (%r8),%xmm0
 115e1f7:	vmovups %xmm0,(%rdi)
 115e1fb:	pop    %rbp
 115e1fc:	ret    
 115e1fd:	lea    -0x3(%rcx),%rdx
 115e201:	lea    -0x15bdd8(%rip),%r8        # 1002430 <__anon_1386>
 115e208:	cmp    $0x1ffff,%rdx
 115e20f:	ja     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e211:	lzcnt  %rdx,%r9
 115e216:	mov    $0x63,%edx
 115e21b:	sub    %r9,%rdx
 115e21e:	lea    -0x1373ed(%rip),%r9        # 1026e38 <__anon_35859>
 115e225:	sub    (%r9,%rdx,8),%rcx
 115e229:	jb     115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e22b:	lea    -0x12576a(%rip),%r9        # 1038ac8 <zstd.match.hq_parser.prices.ml_bits>
 115e232:	movzbl (%rdx,%r9,1),%r9d
 115e237:	shrx   %r9,%rcx,%rcx
 115e23c:	test   %rcx,%rcx
 115e23f:	jne    115e1f2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e241:	jmp    115e157 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>

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
