
/home/passchaos/project-z/vort-zstd-work-accounting/.zig-cache/o/cb5827954aa0d116f6d48f2b2bf9daeb/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000115db40 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase>:
 115db40:	55                   	push   %rbp
 115db41:	48 89 e5             	mov    %rsp,%rbp
 115db44:	48 83 fe 10          	cmp    $0x10,%rsi
 115db48:	73 05                	jae    115db4f <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0xf>
 115db4a:	48 89 f0             	mov    %rsi,%rax
 115db4d:	eb 5c                	jmp    115dbab <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x6b>
 115db4f:	48 83 fe 17          	cmp    $0x17,%rsi
 115db53:	77 13                	ja     115db68 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x28>
 115db55:	48 81 c6 f0 01 00 00 	add    $0x1f0,%rsi
 115db5c:	48 d1 ee             	shr    %rsi
 115db5f:	48 83 c6 10          	add    $0x10,%rsi
 115db63:	48 89 f0             	mov    %rsi,%rax
 115db66:	eb 43                	jmp    115dbab <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x6b>
 115db68:	48 83 fe 1f          	cmp    $0x1f,%rsi
 115db6c:	77 14                	ja     115db82 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x42>
 115db6e:	48 81 c6 e8 03 00 00 	add    $0x3e8,%rsi
 115db75:	48 c1 ee 02          	shr    $0x2,%rsi
 115db79:	48 83 c6 14          	add    $0x14,%rsi
 115db7d:	48 89 f0             	mov    %rsi,%rax
 115db80:	eb 29                	jmp    115dbab <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x6b>
 115db82:	48 83 fe 2f          	cmp    $0x2f,%rsi
 115db86:	77 14                	ja     115db9c <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x5c>
 115db88:	48 81 c6 e0 07 00 00 	add    $0x7e0,%rsi
 115db8f:	48 c1 ee 03          	shr    $0x3,%rsi
 115db93:	48 83 c6 16          	add    $0x16,%rsi
 115db97:	48 89 f0             	mov    %rsi,%rax
 115db9a:	eb 0f                	jmp    115dbab <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x6b>
 115db9c:	b8 18 00 00 00       	mov    $0x18,%eax
 115dba1:	48 83 fe 40          	cmp    $0x40,%rsi
 115dba5:	0f 83 df 00 00 00    	jae    115dc8a <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x14a>
 115dbab:	48 85 d2             	test   %rdx,%rdx
 115dbae:	74 7f                	je     115dc2f <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0xef>
 115dbb0:	4c 8d 05 79 48 ea ff 	lea    -0x15b787(%rip),%r8        # 1002430 <__anon_1386>
 115dbb7:	48 83 fa fc          	cmp    $0xfffffffffffffffc,%rdx
 115dbbb:	0f 87 e1 01 00 00    	ja     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dbc1:	be fc ff ff ff       	mov    $0xfffffffc,%esi
 115dbc6:	48 39 f2             	cmp    %rsi,%rdx
 115dbc9:	0f 87 d3 01 00 00    	ja     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dbcf:	48 8d 72 03          	lea    0x3(%rdx),%rsi
 115dbd3:	f3 48 0f bd f6       	lzcnt  %rsi,%rsi
 115dbd8:	f7 d6                	not    %esi
 115dbda:	41 89 f1             	mov    %esi,%r9d
 115dbdd:	41 83 e1 3f          	and    $0x3f,%r9d
 115dbe1:	4c 8d 15 50 91 ec ff 	lea    -0x136eb0(%rip),%r10        # 1026d38 <__anon_35839>
 115dbe8:	4b 2b 14 ca          	sub    (%r10,%r9,8),%rdx
 115dbec:	0f 82 b0 01 00 00    	jb     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dbf2:	4c 8d 15 a7 4c ea ff 	lea    -0x15b359(%rip),%r10        # 10028a0 <__anon_35844>
 115dbf9:	47 0f b6 0c 11       	movzbl (%r9,%r10,1),%r9d
 115dbfe:	c4 e2 b3 f7 d2       	shrx   %r9,%rdx,%rdx
 115dc03:	48 85 d2             	test   %rdx,%rdx
 115dc06:	0f 85 96 01 00 00    	jne    115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dc0c:	40 80 e6 3f          	and    $0x3f,%sil
 115dc10:	40 80 fe 1f          	cmp    $0x1f,%sil
 115dc14:	0f 87 88 01 00 00    	ja     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dc1a:	48 83 f9 22          	cmp    $0x22,%rcx
 115dc1e:	77 17                	ja     115dc37 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0xf7>
 115dc20:	48 81 c1 fd 00 00 00 	add    $0xfd,%rcx
 115dc27:	48 89 ca             	mov    %rcx,%rdx
 115dc2a:	e9 d8 00 00 00       	jmp    115dd07 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x1c7>
 115dc2f:	31 f6                	xor    %esi,%esi
 115dc31:	48 83 f9 22          	cmp    $0x22,%rcx
 115dc35:	76 e9                	jbe    115dc20 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0xe0>
 115dc37:	48 83 f9 2a          	cmp    $0x2a,%rcx
 115dc3b:	77 16                	ja     115dc53 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x113>
 115dc3d:	48 81 c1 dd 01 00 00 	add    $0x1dd,%rcx
 115dc44:	48 d1 e9             	shr    %rcx
 115dc47:	48 83 c1 20          	add    $0x20,%rcx
 115dc4b:	48 89 ca             	mov    %rcx,%rdx
 115dc4e:	e9 b4 00 00 00       	jmp    115dd07 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x1c7>
 115dc53:	48 83 f9 32          	cmp    $0x32,%rcx
 115dc57:	77 17                	ja     115dc70 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x130>
 115dc59:	48 81 c1 d5 03 00 00 	add    $0x3d5,%rcx
 115dc60:	48 c1 e9 02          	shr    $0x2,%rcx
 115dc64:	48 83 c1 24          	add    $0x24,%rcx
 115dc68:	48 89 ca             	mov    %rcx,%rdx
 115dc6b:	e9 97 00 00 00       	jmp    115dd07 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x1c7>
 115dc70:	48 83 f9 42          	cmp    $0x42,%rcx
 115dc74:	77 65                	ja     115dcdb <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x19b>
 115dc76:	48 81 c1 cd 07 00 00 	add    $0x7cd,%rcx
 115dc7d:	48 c1 e9 03          	shr    $0x3,%rcx
 115dc81:	48 83 c1 26          	add    $0x26,%rcx
 115dc85:	48 89 ca             	mov    %rcx,%rdx
 115dc88:	eb 7d                	jmp    115dd07 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x1c7>
 115dc8a:	4c 8d 05 9f 47 ea ff 	lea    -0x15b861(%rip),%r8        # 1002430 <__anon_1386>
 115dc91:	48 81 fe ff ff 01 00 	cmp    $0x1ffff,%rsi
 115dc98:	0f 87 04 01 00 00    	ja     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dc9e:	f3 4c 0f bd ce       	lzcnt  %rsi,%r9
 115dca3:	b8 52 00 00 00       	mov    $0x52,%eax
 115dca8:	4c 29 c8             	sub    %r9,%rax
 115dcab:	4c 8d 0d 2e 93 ec ff 	lea    -0x136cd2(%rip),%r9        # 1026fe0 <__anon_35791>
 115dcb2:	49 2b 34 c1          	sub    (%r9,%rax,8),%rsi
 115dcb6:	0f 82 e6 00 00 00    	jb     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dcbc:	4c 8d 0d 3d d4 ed ff 	lea    -0x122bc3(%rip),%r9        # 103b100 <zstd.match.hq_parser.prices.ll_bits>
 115dcc3:	46 0f b6 0c 08       	movzbl (%rax,%r9,1),%r9d
 115dcc8:	c4 e2 b3 f7 f6       	shrx   %r9,%rsi,%rsi
 115dccd:	48 85 f6             	test   %rsi,%rsi
 115dcd0:	0f 85 cc 00 00 00    	jne    115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dcd6:	e9 d0 fe ff ff       	jmp    115dbab <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x6b>
 115dcdb:	48 83 f9 62          	cmp    $0x62,%rcx
 115dcdf:	77 14                	ja     115dcf5 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x1b5>
 115dce1:	48 81 c1 bd 0f 00 00 	add    $0xfbd,%rcx
 115dce8:	48 c1 e9 04          	shr    $0x4,%rcx
 115dcec:	48 83 c1 28          	add    $0x28,%rcx
 115dcf0:	48 89 ca             	mov    %rcx,%rdx
 115dcf3:	eb 12                	jmp    115dd07 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x1c7>
 115dcf5:	ba 2a 00 00 00       	mov    $0x2a,%edx
 115dcfa:	48 81 f9 83 00 00 00 	cmp    $0x83,%rcx
 115dd01:	0f 83 a6 00 00 00    	jae    115ddad <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x26d>
 115dd07:	4c 8d 05 22 47 ea ff 	lea    -0x15b8de(%rip),%r8        # 1002430 <__anon_1386>
 115dd0e:	31 c9                	xor    %ecx,%ecx
 115dd10:	84 c9                	test   %cl,%cl
 115dd12:	0f 85 8a 00 00 00    	jne    115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dd18:	44 0f b6 c8          	movzbl %al,%r9d
 115dd1c:	48 8d 05 dd d3 ed ff 	lea    -0x122c23(%rip),%rax        # 103b100 <zstd.match.hq_parser.prices.ll_bits>
 115dd23:	41 0f b6 04 01       	movzbl (%r9,%rax,1),%eax
 115dd28:	40 0f b6 f6          	movzbl %sil,%esi
 115dd2c:	48 8d 0d 6d 4b ea ff 	lea    -0x15b493(%rip),%rcx        # 10028a0 <__anon_35844>
 115dd33:	44 0f b6 14 0e       	movzbl (%rsi,%rcx,1),%r10d
 115dd38:	49 01 c2             	add    %rax,%r10
 115dd3b:	0f b6 d2             	movzbl %dl,%edx
 115dd3e:	48 8d 05 83 ad ed ff 	lea    -0x12527d(%rip),%rax        # 1038ac8 <zstd.match.hq_parser.prices.ml_bits>
 115dd45:	0f b6 0c 02          	movzbl (%rdx,%rax,1),%ecx
 115dd49:	4c 01 d1             	add    %r10,%rcx
 115dd4c:	89 c8                	mov    %ecx,%eax
 115dd4e:	c1 e8 03             	shr    $0x3,%eax
 115dd51:	48 83 c0 06          	add    $0x6,%rax
 115dd55:	4c 8d 15 7c f4 ec ff 	lea    -0x130b84(%rip),%r10        # 102d1d8 <__anon_40686>
 115dd5c:	4b 83 3c ca 00       	cmpq   $0x0,(%r10,%r9,8)
 115dd61:	74 33                	je     115dd96 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x256>
 115dd63:	4c 8d 0d 36 f7 ec ff 	lea    -0x1308ca(%rip),%r9        # 102d4a0 <__anon_41663>
 115dd6a:	49 83 3c f1 00       	cmpq   $0x0,(%r9,%rsi,8)
 115dd6f:	74 25                	je     115dd96 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x256>
 115dd71:	48 8d 35 80 f5 ec ff 	lea    -0x130a80(%rip),%rsi        # 102d2f8 <__anon_40813>
 115dd78:	48 83 3c d6 00       	cmpq   $0x0,(%rsi,%rdx,8)
 115dd7d:	74 17                	je     115dd96 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x256>
 115dd7f:	31 d2                	xor    %edx,%edx
 115dd81:	84 d2                	test   %dl,%dl
 115dd83:	75 1d                	jne    115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dd85:	83 c1 19             	add    $0x19,%ecx
 115dd88:	c1 e9 03             	shr    $0x3,%ecx
 115dd8b:	48 83 c1 02          	add    $0x2,%rcx
 115dd8f:	48 39 c1             	cmp    %rax,%rcx
 115dd92:	48 0f 42 c1          	cmovb  %rcx,%rax
 115dd96:	48 89 45 f0          	mov    %rax,-0x10(%rbp)
 115dd9a:	c6 45 f8 01          	movb   $0x1,-0x8(%rbp)
 115dd9e:	4c 8d 45 f0          	lea    -0x10(%rbp),%r8
 115dda2:	c4 c1 78 10 00       	vmovups (%r8),%xmm0
 115dda7:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 115ddab:	5d                   	pop    %rbp
 115ddac:	c3                   	ret    
 115ddad:	48 8d 51 fd          	lea    -0x3(%rcx),%rdx
 115ddb1:	4c 8d 05 78 46 ea ff 	lea    -0x15b988(%rip),%r8        # 1002430 <__anon_1386>
 115ddb8:	48 81 fa ff ff 01 00 	cmp    $0x1ffff,%rdx
 115ddbf:	77 e1                	ja     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115ddc1:	f3 4c 0f bd ca       	lzcnt  %rdx,%r9
 115ddc6:	ba 63 00 00 00       	mov    $0x63,%edx
 115ddcb:	4c 29 ca             	sub    %r9,%rdx
 115ddce:	4c 8d 0d 63 90 ec ff 	lea    -0x136f9d(%rip),%r9        # 1026e38 <__anon_35859>
 115ddd5:	49 2b 0c d1          	sub    (%r9,%rdx,8),%rcx
 115ddd9:	72 c7                	jb     115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115dddb:	4c 8d 0d e6 ac ed ff 	lea    -0x12531a(%rip),%r9        # 1038ac8 <zstd.match.hq_parser.prices.ml_bits>
 115dde2:	46 0f b6 0c 0a       	movzbl (%rdx,%r9,1),%r9d
 115dde7:	c4 e2 b3 f7 c9       	shrx   %r9,%rcx,%rcx
 115ddec:	48 85 c9             	test   %rcx,%rcx
 115ddef:	75 b1                	jne    115dda2 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x262>
 115ddf1:	e9 11 ff ff ff       	jmp    115dd07 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase+0x1c7>

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
