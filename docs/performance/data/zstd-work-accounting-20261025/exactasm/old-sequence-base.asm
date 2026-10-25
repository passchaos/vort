
/home/passchaos/project-z/vort-zstd-anchor-cache/.zig-cache/o/cb65c150ad435ec3299a71a1ad71caff/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000115df20 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase>:
 115df20:	55                   	push   %rbp
 115df21:	48 89 e5             	mov    %rsp,%rbp
 115df24:	48 83 fe 10          	cmp    $0x10,%rsi
 115df28:	73 05                	jae    115df2f <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xf>
 115df2a:	48 89 f0             	mov    %rsi,%rax
 115df2d:	eb 5c                	jmp    115df8b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115df2f:	48 83 fe 17          	cmp    $0x17,%rsi
 115df33:	77 13                	ja     115df48 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x28>
 115df35:	48 81 c6 f0 01 00 00 	add    $0x1f0,%rsi
 115df3c:	48 d1 ee             	shr    %rsi
 115df3f:	48 83 c6 10          	add    $0x10,%rsi
 115df43:	48 89 f0             	mov    %rsi,%rax
 115df46:	eb 43                	jmp    115df8b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115df48:	48 83 fe 1f          	cmp    $0x1f,%rsi
 115df4c:	77 14                	ja     115df62 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x42>
 115df4e:	48 81 c6 e8 03 00 00 	add    $0x3e8,%rsi
 115df55:	48 c1 ee 02          	shr    $0x2,%rsi
 115df59:	48 83 c6 14          	add    $0x14,%rsi
 115df5d:	48 89 f0             	mov    %rsi,%rax
 115df60:	eb 29                	jmp    115df8b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115df62:	48 83 fe 2f          	cmp    $0x2f,%rsi
 115df66:	77 14                	ja     115df7c <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x5c>
 115df68:	48 81 c6 e0 07 00 00 	add    $0x7e0,%rsi
 115df6f:	48 c1 ee 03          	shr    $0x3,%rsi
 115df73:	48 83 c6 16          	add    $0x16,%rsi
 115df77:	48 89 f0             	mov    %rsi,%rax
 115df7a:	eb 0f                	jmp    115df8b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115df7c:	b8 18 00 00 00       	mov    $0x18,%eax
 115df81:	48 83 fe 40          	cmp    $0x40,%rsi
 115df85:	0f 83 df 00 00 00    	jae    115e06a <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x14a>
 115df8b:	48 85 d2             	test   %rdx,%rdx
 115df8e:	74 7f                	je     115e00f <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xef>
 115df90:	4c 8d 05 99 44 ea ff 	lea    -0x15bb67(%rip),%r8        # 1002430 <__anon_1386>
 115df97:	48 83 fa fc          	cmp    $0xfffffffffffffffc,%rdx
 115df9b:	0f 87 e1 01 00 00    	ja     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115dfa1:	be fc ff ff ff       	mov    $0xfffffffc,%esi
 115dfa6:	48 39 f2             	cmp    %rsi,%rdx
 115dfa9:	0f 87 d3 01 00 00    	ja     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115dfaf:	48 8d 72 03          	lea    0x3(%rdx),%rsi
 115dfb3:	f3 48 0f bd f6       	lzcnt  %rsi,%rsi
 115dfb8:	f7 d6                	not    %esi
 115dfba:	41 89 f1             	mov    %esi,%r9d
 115dfbd:	41 83 e1 3f          	and    $0x3f,%r9d
 115dfc1:	4c 8d 15 70 8d ec ff 	lea    -0x137290(%rip),%r10        # 1026d38 <__anon_35839>
 115dfc8:	4b 2b 14 ca          	sub    (%r10,%r9,8),%rdx
 115dfcc:	0f 82 b0 01 00 00    	jb     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115dfd2:	4c 8d 15 c7 48 ea ff 	lea    -0x15b739(%rip),%r10        # 10028a0 <__anon_35844>
 115dfd9:	47 0f b6 0c 11       	movzbl (%r9,%r10,1),%r9d
 115dfde:	c4 e2 b3 f7 d2       	shrx   %r9,%rdx,%rdx
 115dfe3:	48 85 d2             	test   %rdx,%rdx
 115dfe6:	0f 85 96 01 00 00    	jne    115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115dfec:	40 80 e6 3f          	and    $0x3f,%sil
 115dff0:	40 80 fe 1f          	cmp    $0x1f,%sil
 115dff4:	0f 87 88 01 00 00    	ja     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115dffa:	48 83 f9 22          	cmp    $0x22,%rcx
 115dffe:	77 17                	ja     115e017 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xf7>
 115e000:	48 81 c1 fd 00 00 00 	add    $0xfd,%rcx
 115e007:	48 89 ca             	mov    %rcx,%rdx
 115e00a:	e9 d8 00 00 00       	jmp    115e0e7 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e00f:	31 f6                	xor    %esi,%esi
 115e011:	48 83 f9 22          	cmp    $0x22,%rcx
 115e015:	76 e9                	jbe    115e000 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0xe0>
 115e017:	48 83 f9 2a          	cmp    $0x2a,%rcx
 115e01b:	77 16                	ja     115e033 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x113>
 115e01d:	48 81 c1 dd 01 00 00 	add    $0x1dd,%rcx
 115e024:	48 d1 e9             	shr    %rcx
 115e027:	48 83 c1 20          	add    $0x20,%rcx
 115e02b:	48 89 ca             	mov    %rcx,%rdx
 115e02e:	e9 b4 00 00 00       	jmp    115e0e7 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e033:	48 83 f9 32          	cmp    $0x32,%rcx
 115e037:	77 17                	ja     115e050 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x130>
 115e039:	48 81 c1 d5 03 00 00 	add    $0x3d5,%rcx
 115e040:	48 c1 e9 02          	shr    $0x2,%rcx
 115e044:	48 83 c1 24          	add    $0x24,%rcx
 115e048:	48 89 ca             	mov    %rcx,%rdx
 115e04b:	e9 97 00 00 00       	jmp    115e0e7 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e050:	48 83 f9 42          	cmp    $0x42,%rcx
 115e054:	77 65                	ja     115e0bb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x19b>
 115e056:	48 81 c1 cd 07 00 00 	add    $0x7cd,%rcx
 115e05d:	48 c1 e9 03          	shr    $0x3,%rcx
 115e061:	48 83 c1 26          	add    $0x26,%rcx
 115e065:	48 89 ca             	mov    %rcx,%rdx
 115e068:	eb 7d                	jmp    115e0e7 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e06a:	4c 8d 05 bf 43 ea ff 	lea    -0x15bc41(%rip),%r8        # 1002430 <__anon_1386>
 115e071:	48 81 fe ff ff 01 00 	cmp    $0x1ffff,%rsi
 115e078:	0f 87 04 01 00 00    	ja     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e07e:	f3 4c 0f bd ce       	lzcnt  %rsi,%r9
 115e083:	b8 52 00 00 00       	mov    $0x52,%eax
 115e088:	4c 29 c8             	sub    %r9,%rax
 115e08b:	4c 8d 0d 4e 8f ec ff 	lea    -0x1370b2(%rip),%r9        # 1026fe0 <__anon_35791>
 115e092:	49 2b 34 c1          	sub    (%r9,%rax,8),%rsi
 115e096:	0f 82 e6 00 00 00    	jb     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e09c:	4c 8d 0d 5d d0 ed ff 	lea    -0x122fa3(%rip),%r9        # 103b100 <zstd.match.hq_parser.prices.ll_bits>
 115e0a3:	46 0f b6 0c 08       	movzbl (%rax,%r9,1),%r9d
 115e0a8:	c4 e2 b3 f7 f6       	shrx   %r9,%rsi,%rsi
 115e0ad:	48 85 f6             	test   %rsi,%rsi
 115e0b0:	0f 85 cc 00 00 00    	jne    115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e0b6:	e9 d0 fe ff ff       	jmp    115df8b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x6b>
 115e0bb:	48 83 f9 62          	cmp    $0x62,%rcx
 115e0bf:	77 14                	ja     115e0d5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1b5>
 115e0c1:	48 81 c1 bd 0f 00 00 	add    $0xfbd,%rcx
 115e0c8:	48 c1 e9 04          	shr    $0x4,%rcx
 115e0cc:	48 83 c1 28          	add    $0x28,%rcx
 115e0d0:	48 89 ca             	mov    %rcx,%rdx
 115e0d3:	eb 12                	jmp    115e0e7 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>
 115e0d5:	ba 2a 00 00 00       	mov    $0x2a,%edx
 115e0da:	48 81 f9 83 00 00 00 	cmp    $0x83,%rcx
 115e0e1:	0f 83 a6 00 00 00    	jae    115e18d <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x26d>
 115e0e7:	4c 8d 05 42 43 ea ff 	lea    -0x15bcbe(%rip),%r8        # 1002430 <__anon_1386>
 115e0ee:	31 c9                	xor    %ecx,%ecx
 115e0f0:	84 c9                	test   %cl,%cl
 115e0f2:	0f 85 8a 00 00 00    	jne    115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e0f8:	44 0f b6 c8          	movzbl %al,%r9d
 115e0fc:	48 8d 05 fd cf ed ff 	lea    -0x123003(%rip),%rax        # 103b100 <zstd.match.hq_parser.prices.ll_bits>
 115e103:	41 0f b6 04 01       	movzbl (%r9,%rax,1),%eax
 115e108:	40 0f b6 f6          	movzbl %sil,%esi
 115e10c:	48 8d 0d 8d 47 ea ff 	lea    -0x15b873(%rip),%rcx        # 10028a0 <__anon_35844>
 115e113:	44 0f b6 14 0e       	movzbl (%rsi,%rcx,1),%r10d
 115e118:	49 01 c2             	add    %rax,%r10
 115e11b:	0f b6 d2             	movzbl %dl,%edx
 115e11e:	48 8d 05 a3 a9 ed ff 	lea    -0x12565d(%rip),%rax        # 1038ac8 <zstd.match.hq_parser.prices.ml_bits>
 115e125:	0f b6 0c 02          	movzbl (%rdx,%rax,1),%ecx
 115e129:	4c 01 d1             	add    %r10,%rcx
 115e12c:	89 c8                	mov    %ecx,%eax
 115e12e:	c1 e8 03             	shr    $0x3,%eax
 115e131:	48 83 c0 06          	add    $0x6,%rax
 115e135:	4c 8d 15 9c f0 ec ff 	lea    -0x130f64(%rip),%r10        # 102d1d8 <__anon_40686>
 115e13c:	4b 83 3c ca 00       	cmpq   $0x0,(%r10,%r9,8)
 115e141:	74 33                	je     115e176 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x256>
 115e143:	4c 8d 0d 56 f3 ec ff 	lea    -0x130caa(%rip),%r9        # 102d4a0 <__anon_41663>
 115e14a:	49 83 3c f1 00       	cmpq   $0x0,(%r9,%rsi,8)
 115e14f:	74 25                	je     115e176 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x256>
 115e151:	48 8d 35 a0 f1 ec ff 	lea    -0x130e60(%rip),%rsi        # 102d2f8 <__anon_40813>
 115e158:	48 83 3c d6 00       	cmpq   $0x0,(%rsi,%rdx,8)
 115e15d:	74 17                	je     115e176 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x256>
 115e15f:	31 d2                	xor    %edx,%edx
 115e161:	84 d2                	test   %dl,%dl
 115e163:	75 1d                	jne    115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e165:	83 c1 19             	add    $0x19,%ecx
 115e168:	c1 e9 03             	shr    $0x3,%ecx
 115e16b:	48 83 c1 02          	add    $0x2,%rcx
 115e16f:	48 39 c1             	cmp    %rax,%rcx
 115e172:	48 0f 42 c1          	cmovb  %rcx,%rax
 115e176:	48 89 45 f0          	mov    %rax,-0x10(%rbp)
 115e17a:	c6 45 f8 01          	movb   $0x1,-0x8(%rbp)
 115e17e:	4c 8d 45 f0          	lea    -0x10(%rbp),%r8
 115e182:	c4 c1 78 10 00       	vmovups (%r8),%xmm0
 115e187:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 115e18b:	5d                   	pop    %rbp
 115e18c:	c3                   	ret    
 115e18d:	48 8d 51 fd          	lea    -0x3(%rcx),%rdx
 115e191:	4c 8d 05 98 42 ea ff 	lea    -0x15bd68(%rip),%r8        # 1002430 <__anon_1386>
 115e198:	48 81 fa ff ff 01 00 	cmp    $0x1ffff,%rdx
 115e19f:	77 e1                	ja     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e1a1:	f3 4c 0f bd ca       	lzcnt  %rdx,%r9
 115e1a6:	ba 63 00 00 00       	mov    $0x63,%edx
 115e1ab:	4c 29 ca             	sub    %r9,%rdx
 115e1ae:	4c 8d 0d 83 8c ec ff 	lea    -0x13737d(%rip),%r9        # 1026e38 <__anon_35859>
 115e1b5:	49 2b 0c d1          	sub    (%r9,%rdx,8),%rcx
 115e1b9:	72 c7                	jb     115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e1bb:	4c 8d 0d 06 a9 ed ff 	lea    -0x1256fa(%rip),%r9        # 1038ac8 <zstd.match.hq_parser.prices.ml_bits>
 115e1c2:	46 0f b6 0c 0a       	movzbl (%rdx,%r9,1),%r9d
 115e1c7:	c4 e2 b3 f7 c9       	shrx   %r9,%rcx,%rcx
 115e1cc:	48 85 c9             	test   %rcx,%rcx
 115e1cf:	75 b1                	jne    115e182 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x262>
 115e1d1:	e9 11 ff ff ff       	jmp    115e0e7 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase+0x1c7>

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
