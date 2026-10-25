 120d362:	41 0f b7 45 00       	movzwl 0x0(%r13),%eax
 120d367:	48 85 c0             	test   %rax,%rax
 120d36a:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 120d36e:	0f 84 ce 00 00 00    	je     120d442 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x292>
 120d374:	66 83 f8 04          	cmp    $0x4,%ax

 120d442:	48 8d bd d8 f3 ff ff 	lea    -0xc28(%rbp),%rdi
 120d449:	48 8d b5 b0 f6 ff ff 	lea    -0x950(%rbp),%rsi
 120d450:	4c 89 ea             	mov    %r13,%rdx
 120d453:	49 89 cd             	mov    %rcx,%r13
 120d456:	e8 15 f2 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 120d45b:	0f b7 85 e0 f3 ff ff 	movzwl -0xc20(%rbp),%eax
 120d462:	66 85 c0             	test   %ax,%ax
 120d465:	0f 85 2c 18 00 00    	jne    120ec97 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ae7>
 120d46b:	4c 89 e9             	mov    %r13,%rcx
 120d46e:	4c 8b ad d8 f3 ff ff 	mov    -0xc28(%rbp),%r13
 120d475:	48 8d bd 38 6c ff ff 	lea    -0x93c8(%rbp),%rdi
 120d47c:	48 8d b5 38 6c fe ff 	lea    -0x193c8(%rbp),%rsi
 120d483:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 120d487:	e8 e4 f1 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 120d48c:	0f b7 85 40 6c ff ff 	movzwl -0x93c0(%rbp),%eax
 120d493:	66 85 c0             	test   %ax,%ax
 120d496:	0f 85 fb 17 00 00    	jne    120ec97 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ae7>

 120e93f:	4c 8d a5 38 6c fe ff 	lea    -0x193c8(%rbp),%r12
 120e946:	4d 89 fd             	mov    %r15,%r13
 120e949:	45 31 ff             	xor    %r15d,%r15d
 120e94c:	48 89 f1             	mov    %rsi,%rcx
 120e94f:	90                   	nop
 120e950:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 120e957:	4c 89 e6             	mov    %r12,%rsi
 120e95a:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 120e95e:	c5 f8 77             	vzeroupper 
 120e961:	e8 0a dd ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 120e966:	0f b7 85 58 fe ff ff 	movzwl -0x1a8(%rbp),%eax
 120e96d:	66 85 c0             	test   %ax,%ax
 120e970:	0f 85 21 03 00 00    	jne    120ec97 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ae7>
 120e976:	4c 03 bd 50 fe ff ff 	add    -0x1b0(%rbp),%r15
 120e97d:	49 81 c4 00 04 00 00 	add    $0x400,%r12
 120e984:	49 ff cd             	dec    %r13
 120e987:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 120e98b:	75 c3                	jne    120e950 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x17a0>
