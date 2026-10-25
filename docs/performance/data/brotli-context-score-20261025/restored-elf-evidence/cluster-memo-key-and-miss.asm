 120e4e3:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 120e4e9:	75 95                	jne    120e480 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1800>
 120e4eb:	89 c8                	mov    %ecx,%eax
 120e4ed:	c1 e8 03             	shr    $0x3,%eax
 120e4f0:	83 e0 08             	and    $0x8,%eax
 120e4f3:	48 8b 84 05 08 2a fd 	mov    -0x2d5f8(%rbp,%rax,1),%rax
 120e4fa:	ff 
 120e4fb:	48 0f a3 c8          	bt     %rcx,%rax
 120e4ff:	0f 83 7b 03 00 00    	jae    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e505:	89 c8                	mov    %ecx,%eax
 120e507:	83 e0 7f             	and    $0x7f,%eax
 120e50a:	48 69 c0 10 04 00 00 	imul   $0x410,%rax,%rax
 120e511:	48 39 8c 05 08 22 fb 	cmp    %rcx,-0x4ddf8(%rbp,%rax,1)
 120e518:	ff 
 120e519:	0f 85 61 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e51f:	48 01 e8             	add    %rbp,%rax
 120e522:	48 05 08 22 fb ff    	add    $0xfffffffffffb2208,%rax
 120e528:	c5 fe 6f 40 10       	vmovdqu 0x10(%rax),%ymm0
 120e52d:	c4 c1 7d ef 06       	vpxor  (%r14),%ymm0,%ymm0
 120e532:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e537:	0f 85 43 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e53d:	c5 fe 6f 40 30       	vmovdqu 0x30(%rax),%ymm0
 120e542:	c4 c1 7d ef 46 20    	vpxor  0x20(%r14),%ymm0,%ymm0
 120e548:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e54d:	0f 85 2d 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>

 120e880:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 120e887:	4c 89 f6             	mov    %r14,%rsi
 120e88a:	4c 89 e2             	mov    %r12,%rdx
 120e88d:	c5 f8 77             	vzeroupper 
 120e890:	e8 db dd ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120e895:	0f b7 85 58 fe ff ff 	movzwl -0x1a8(%rbp),%eax
 120e89c:	66 85 c0             	test   %ax,%ax
 120e89f:	0f 85 42 04 00 00    	jne    120ece7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2067>
 120e8a5:	4d 89 f0             	mov    %r14,%r8
 120e8a8:	49 89 dd             	mov    %rbx,%r13
 120e8ab:	48 ff 85 70 ff ff ff 	incq   -0x90(%rbp)
 120e8b2:	48 8b 9d 50 fe ff ff 	mov    -0x1b0(%rbp),%rbx

 120e93b:	44 89 f0             	mov    %r14d,%eax
 120e93e:	83 e0 7f             	and    $0x7f,%eax
 120e941:	4c 69 e0 10 04 00 00 	imul   $0x410,%rax,%r12
 120e948:	4e 89 b4 25 08 22 fb 	mov    %r14,-0x4ddf8(%rbp,%r12,1)
 120e94f:	ff 
 120e950:	49 8d 3c 2c          	lea    (%r12,%rbp,1),%rdi
 120e954:	48 81 c7 18 22 fb ff 	add    $0xfffffffffffb2218,%rdi
 120e95b:	ba 00 04 00 00       	mov    $0x400,%edx
 120e960:	4c 89 c6             	mov    %r8,%rsi
 120e963:	e8 f8 78 08 00       	call   1296260 <compiler_rt.memcpy.memcpyFast>
 120e968:	4a 89 9c 25 10 22 fb 	mov    %rbx,-0x4ddf0(%rbp,%r12,1)
 120e96f:	ff 
 120e970:	44 89 f0             	mov    %r14d,%eax
 120e973:	c1 e8 03             	shr    $0x3,%eax
 120e976:	83 e0 08             	and    $0x8,%eax
