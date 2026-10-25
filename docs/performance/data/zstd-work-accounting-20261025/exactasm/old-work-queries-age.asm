 115ae71:	48 89 5c 24 60       	mov    %rbx,0x60(%rsp)
 115ae76:	48 8b b4 24 d0 22 00 	mov    0x22d0(%rsp),%rsi
 115ae7d:	00 
 115ae7e:	48 ff c6             	inc    %rsi
 115ae81:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 115ae88:	48 0f 44 f2          	cmove  %rdx,%rsi
 115ae8c:	48 89 b4 24 d0 22 00 	mov    %rsi,0x22d0(%rsp)
 115ae93:	00 
 115ae94:	80 bc 24 c0 22 00 00 	cmpb   $0x0,0x22c0(%rsp)
 115ae9b:	00 
 115ae9c:	74 17                	je     115aeb5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x515>
 115ae9e:	48 8b b4 24 c8 22 00 	mov    0x22c8(%rsp),%rsi
 115aea5:	00 
 115aea6:	48 ff c6             	inc    %rsi
 115aea9:	48 0f 44 f2          	cmove  %rdx,%rsi
 115aead:	48 89 b4 24 c8 22 00 	mov    %rsi,0x22c8(%rsp)
 115aeb4:	00 
