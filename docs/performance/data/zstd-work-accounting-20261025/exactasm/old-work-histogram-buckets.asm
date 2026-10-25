 115ceb0:	31 ff                	xor    %edi,%edi
 115ceb2:	48 8b 94 24 c8 22 00 	mov    0x22c8(%rsp),%rdx
 115ceb9:	00 
 115ceba:	48 8b b4 24 f0 22 00 	mov    0x22f0(%rsp),%rsi
 115cec1:	00 
 115cec2:	48 ff c6             	inc    %rsi
 115cec5:	49 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%r8
 115cecc:	49 0f 44 f0          	cmove  %r8,%rsi
 115ced0:	48 89 b4 24 f0 22 00 	mov    %rsi,0x22f0(%rsp)
 115ced7:	00 
 115ced8:	48 8b b4 24 38 23 00 	mov    0x2338(%rsp),%rsi
 115cedf:	00 
 115cee0:	48 01 ce             	add    %rcx,%rsi
 115cee3:	49 0f 42 f0          	cmovb  %r8,%rsi
 115cee7:	48 89 b4 24 38 23 00 	mov    %rsi,0x2338(%rsp)
 115ceee:	00 
 115ceef:	48 8b b4 24 40 23 00 	mov    0x2340(%rsp),%rsi
 115cef6:	00 
 115cef7:	48 39 ce             	cmp    %rcx,%rsi
 115cefa:	48 0f 46 f1          	cmovbe %rcx,%rsi
 115cefe:	48 89 b4 24 40 23 00 	mov    %rsi,0x2340(%rsp)
 115cf05:	00 
 115cf06:	48 8b b4 24 48 23 00 	mov    0x2348(%rsp),%rsi
 115cf0d:	00 
 115cf0e:	48 39 d6             	cmp    %rdx,%rsi
 115cf11:	48 0f 46 f2          	cmovbe %rdx,%rsi
 115cf15:	48 89 b4 24 48 23 00 	mov    %rsi,0x2348(%rsp)
 115cf1c:	00 
 115cf1d:	48 85 c9             	test   %rcx,%rcx
 115cf20:	0f 84 8d 00 00 00    	je     115cfb3 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2613>
 115cf26:	f3 48 0f bd c9       	lzcnt  %rcx,%rcx
 115cf2b:	f6 d1                	not    %cl
 115cf2d:	80 e1 3f             	and    $0x3f,%cl
 115cf30:	0f b6 c9             	movzbl %cl,%ecx
 115cf33:	80 f9 10             	cmp    $0x10,%cl
 115cf36:	be 10 00 00 00       	mov    $0x10,%esi
 115cf3b:	0f 43 ce             	cmovae %esi,%ecx
 115cf3e:	fe c1                	inc    %cl
 115cf40:	0f b6 c9             	movzbl %cl,%ecx
 115cf43:	eb 70                	jmp    115cfb5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2615>

 115cfb3:	31 c9                	xor    %ecx,%ecx
 115cfb5:	48 8b b4 cc 50 23 00 	mov    0x2350(%rsp,%rcx,8),%rsi
 115cfbc:	00 
 115cfbd:	48 ff c6             	inc    %rsi
 115cfc0:	49 0f 44 f0          	cmove  %r8,%rsi
 115cfc4:	48 89 b4 cc 50 23 00 	mov    %rsi,0x2350(%rsp,%rcx,8)
 115cfcb:	00 
 115cfcc:	48 85 d2             	test   %rdx,%rdx
 115cfcf:	74 1f                	je     115cff0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2650>
 115cfd1:	f3 48 0f bd ca       	lzcnt  %rdx,%rcx
 115cfd6:	f6 d1                	not    %cl
 115cfd8:	80 e1 3f             	and    $0x3f,%cl
 115cfdb:	0f b6 c9             	movzbl %cl,%ecx
 115cfde:	80 f9 0e             	cmp    $0xe,%cl
 115cfe1:	ba 0e 00 00 00       	mov    $0xe,%edx
 115cfe6:	0f 43 ca             	cmovae %edx,%ecx
 115cfe9:	fe c1                	inc    %cl
 115cfeb:	0f b6 c9             	movzbl %cl,%ecx
 115cfee:	eb 02                	jmp    115cff2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2652>
 115cff0:	31 c9                	xor    %ecx,%ecx
 115cff2:	48 8b 94 cc e0 23 00 	mov    0x23e0(%rsp,%rcx,8),%rdx
 115cff9:	00 
 115cffa:	48 ff c2             	inc    %rdx
 115cffd:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 115d004:	48 0f 44 d6          	cmove  %rsi,%rdx
 115d008:	48 89 94 cc e0 23 00 	mov    %rdx,0x23e0(%rsp,%rcx,8)
 115d00f:	00 
