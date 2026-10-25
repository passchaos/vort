 120cefa:	48 8d bd 38 6c ff ff 	lea    -0x93c8(%rbp),%rdi
 120cf01:	48 8d b5 b0 f6 ff ff 	lea    -0x950(%rbp),%rsi
 120cf08:	4c 89 e2             	mov    %r12,%rdx
 120cf0b:	c5 f8 77             	vzeroupper 
 120cf0e:	e8 5d f7 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120cf13:	0f b7 85 40 6c ff ff 	movzwl -0x93c0(%rbp),%eax
 120cf1a:	66 85 c0             	test   %ax,%ax
 120cf1d:	0f 85 c4 1d 00 00    	jne    120ece7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2067>
 120cf23:	48 8b 85 38 6c ff ff 	mov    -0x93c8(%rbp),%rax
 120cf2a:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 120cf31:	48 8d bd 38 6c ff ff 	lea    -0x93c8(%rbp),%rdi
 120cf38:	48 8d b5 38 6c fe ff 	lea    -0x193c8(%rbp),%rsi
 120cf3f:	4c 89 e2             	mov    %r12,%rdx
 120cf42:	e8 29 f7 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120cf47:	0f b7 85 40 6c ff ff 	movzwl -0x93c0(%rbp),%eax
 120cf4e:	66 85 c0             	test   %ax,%ax
 120cf51:	0f 85 90 1d 00 00    	jne    120ece7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2067>

 120d1a1:	01 b9 00 04 00 00    	add    %edi,0x400(%rcx)
 120d1a7:	eb 97                	jmp    120d140 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x4c0>
 120d1a9:	48 8d bd 10 ef ff ff 	lea    -0x10f0(%rbp),%rdi
 120d1b0:	ba a0 07 00 00       	mov    $0x7a0,%edx
 120d1b5:	31 f6                	xor    %esi,%esi
 120d1b7:	c5 f8 77             	vzeroupper 
 120d1ba:	e8 81 8c 08 00       	call   1295e40 <compiler_rt.memset>
 120d1bf:	48 8d bd 08 22 fb ff 	lea    -0x4ddf8(%rbp),%rdi
 120d1c6:	ba 30 08 02 00       	mov    $0x20830,%edx
 120d1cb:	31 f6                	xor    %esi,%esi
 120d1cd:	e8 6e 8c 08 00       	call   1295e40 <compiler_rt.memset>
