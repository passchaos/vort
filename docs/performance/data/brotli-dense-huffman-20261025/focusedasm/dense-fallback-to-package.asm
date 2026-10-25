 11bac8b:	48 81 ec 00 06 00 00 	sub    $0x600,%rsp
 11bac92:	48 89 d3             	mov    %rdx,%rbx
 11bac95:	49 89 f7             	mov    %rsi,%r15
 11bac98:	49 89 fe             	mov    %rdi,%r14
 11bac9b:	4c 8b 27             	mov    (%rdi),%r12
 11bac9e:	48 8d bd e0 f9 ff ff 	lea    -0x620(%rbp),%rdi
 11baca5:	ba 00 04 00 00       	mov    $0x400,%edx
 11bacaa:	31 f6                	xor    %esi,%esi
 11bacac:	e8 cf cb 0d 00       	call   1297880 <compiler_rt.memset>
 11bacb1:	4d 85 e4             	test   %r12,%r12
 11bacb4:	74 13                	je     11bacc9 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x49>
 11bacb6:	44 89 e0             	mov    %r12d,%eax
 11bacb9:	83 e0 07             	and    $0x7,%eax
 11bacbc:	49 83 fc 08          	cmp    $0x8,%r12
 11bacc0:	73 24                	jae    11bace6 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x66>
 11bacc2:	31 c9                	xor    %ecx,%ecx
 11bacc4:	e9 cc 00 00 00       	jmp    11bad95 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x115>
 11bacc9:	48 8d bd e0 fd ff ff 	lea    -0x220(%rbp),%rdi
 11bacd0:	48 8d b5 e0 f9 ff ff 	lea    -0x620(%rbp),%rsi
 11bacd7:	ba 0f 00 00 00       	mov    $0xf,%edx
 11bacdc:	e8 5f fd fc ff       	call   118aa40 <huffman.treeCodeLengths__anon_40857>
 11bace1:	e9 83 02 00 00       	jmp    11baf69 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x2e9>
 11bace6:	44 89 e2             	mov    %r12d,%edx
 11bace9:	81 e2 f8 01 00 00    	and    $0x1f8,%edx
 11bacef:	31 c9                	xor    %ecx,%ecx
