 120e0ed:	48 81 ec b8 06 00 00 	sub    $0x6b8,%rsp
 120e0f4:	49 89 f6             	mov    %rsi,%r14
 120e0f7:	48 89 fb             	mov    %rdi,%rbx
 120e0fa:	44 0f b7 0a          	movzwl (%rdx),%r9d
 120e0fe:	48 83 c2 02          	add    $0x2,%rdx
 120e102:	49 83 f9 3f          	cmp    $0x3f,%r9
 120e106:	0f 87 93 00 00 00    	ja     120e19f <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0xbf>
 120e10c:	48 c7 85 20 f9 ff ff 	movq   $0x0,-0x6e0(%rbp)
 120e113:	00 00 00 00 
 120e117:	66 b8 1f 00          	mov    $0x1f,%ax
 120e11b:	4d 85 c9             	test   %r9,%r9
 120e11e:	0f 84 e3 05 00 00    	je     120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e124:	31 c9                	xor    %ecx,%ecx
 120e126:	31 f6                	xor    %esi,%esi
 120e128:	31 ff                	xor    %edi,%edi
 120e12a:	eb 26                	jmp    120e152 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x72>

 120e152:	44 0f b6 04 3a       	movzbl (%rdx,%rdi,1),%r8d
 120e157:	47 8b 14 86          	mov    (%r14,%r8,4),%r10d
 120e15b:	45 85 d2             	test   %r10d,%r10d
 120e15e:	74 ea                	je     120e14a <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x6a>
 120e160:	44 0f b7 de          	movzwl %si,%r11d
 120e164:	46 88 84 1d 30 fc ff 	mov    %r8b,-0x3d0(%rbp,%r11,1)
 120e16b:	ff 
 120e16c:	48 85 c9             	test   %rcx,%rcx
 120e16f:	74 bd                	je     120e12e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4e>
 120e171:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 120e178:	0f 84 89 05 00 00    	je     120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e17e:	66 90                	xchg   %ax,%ax
 120e180:	44 0f b7 9c 4d 26 f9 	movzwl -0x6da(%rbp,%rcx,2),%r11d
 120e187:	ff ff 
 120e189:	47 3b 14 9e          	cmp    (%r14,%r11,4),%r10d
 120e18d:	76 9f                	jbe    120e12e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4e>
 120e18f:	48 ff c9             	dec    %rcx
 120e192:	66 44 89 9c 4d 2a f9 	mov    %r11w,-0x6d6(%rbp,%rcx,2)
 120e199:	ff ff 
 120e19b:	75 e3                	jne    120e180 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0xa0>
 120e19d:	eb 8d                	jmp    120e12c <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4c>
 120e19f:	48 8d 8d 20 f9 ff ff 	lea    -0x6e0(%rbp),%rcx
 120e1a6:	4c 8d 85 2e fc ff ff 	lea    -0x3d2(%rbp),%r8
 120e1ad:	4c 89 f7             	mov    %r14,%rdi
 120e1b0:	48 89 d6             	mov    %rdx,%rsi
 120e1b3:	4c 89 ca             	mov    %r9,%rdx
 120e1b6:	e8 25 50 00 00       	call   12131e0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625>
 120e1bb:	66 85 c0             	test   %ax,%ax
 120e1be:	74 15                	je     120e1d5 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0xf5>
 120e1c0:	e9 42 05 00 00       	jmp    120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e1c5:	66 89 b5 2e fc ff ff 	mov    %si,-0x3d2(%rbp)
 120e1cc:	48 85 c9             	test   %rcx,%rcx
 120e1cf:	0f 84 32 05 00 00    	je     120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e1d5:	48 8d bd 2c fb ff ff 	lea    -0x4d4(%rbp),%rdi
 120e1dc:	48 8d b5 20 f9 ff ff 	lea    -0x6e0(%rbp),%rsi
 120e1e3:	4c 89 f2             	mov    %r14,%rdx
 120e1e6:	e8 65 70 f6 ff       	call   1175250 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
