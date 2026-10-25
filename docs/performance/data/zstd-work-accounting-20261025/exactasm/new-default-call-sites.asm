0000000001159b60 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42341>:
 115a3e1:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 115a3e5:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 115a3e9:	4c 89 f9             	mov    %r15,%rcx
 115a3ec:	49 89 d8             	mov    %rbx,%r8
 115a3ef:	44 8b 4d bc          	mov    -0x44(%rbp),%r9d
 115a3f3:	50                   	push   %rax
 115a3f4:	ff 75 98             	push   -0x68(%rbp)
 115a3f7:	c5 f8 77             	vzeroupper 
 115a3fa:	e8 a1 05 00 00       	call   115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>
 115a3ff:	48 83 c4 10          	add    $0x10,%rsp
 115a403:	44 0f b7 b5 6c ff ff 	movzwl -0x94(%rbp),%r14d
 115a40a:	ff 
 115a40b:	66 45 85 f6          	test   %r14w,%r14w
 115a40f:	0f 85 84 03 00 00    	jne    115a799 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42341+0xc39>
 115a415:	80 bd 6e ff ff ff 01 	cmpb   $0x1,-0x92(%rbp)
 115a41c:	75 6b                	jne    115a489 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42341+0x929>

0000000001168dd0 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42340>:
 116a1a3:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 116a1a7:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 116a1ab:	4c 89 f9             	mov    %r15,%rcx
 116a1ae:	49 89 d8             	mov    %rbx,%r8
 116a1b1:	44 8b 4d c4          	mov    -0x3c(%rbp),%r9d
 116a1b5:	50                   	push   %rax
 116a1b6:	41 54                	push   %r12
 116a1b8:	c5 f8 77             	vzeroupper 
 116a1bb:	e8 e0 07 ff ff       	call   115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>
 116a1c0:	48 83 c4 10          	add    $0x10,%rsp
 116a1c4:	44 0f b7 b5 24 ff ff 	movzwl -0xdc(%rbp),%r14d
 116a1cb:	ff 
 116a1cc:	66 45 85 f6          	test   %r14w,%r14w
 116a1d0:	0f 85 a3 05 00 00    	jne    116a779 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42340+0x19a9>
 116a1d6:	80 bd 26 ff ff ff 01 	cmpb   $0x1,-0xda(%rbp)
 116a1dd:	75 65                	jne    116a244 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42340+0x1474>

000000000116be60 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42253>:
 116c732:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 116c736:	4c 89 e2             	mov    %r12,%rdx
 116c739:	48 89 d9             	mov    %rbx,%rcx
 116c73c:	4d 89 e8             	mov    %r13,%r8
 116c73f:	44 8b 4d cc          	mov    -0x34(%rbp),%r9d
 116c743:	50                   	push   %rax
 116c744:	ff 75 98             	push   -0x68(%rbp)
 116c747:	c5 f8 77             	vzeroupper 
 116c74a:	e8 51 e2 fe ff       	call   115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>
 116c74f:	48 83 c4 10          	add    $0x10,%rsp
 116c753:	44 0f b7 b5 6c ff ff 	movzwl -0x94(%rbp),%r14d
 116c75a:	ff 
 116c75b:	66 45 85 f6          	test   %r14w,%r14w
 116c75f:	0f 85 8a 04 00 00    	jne    116cbef <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42253+0xd8f>
 116c765:	80 bd 6e ff ff ff 01 	cmpb   $0x1,-0x92(%rbp)
 116c76c:	75 64                	jne    116c7d2 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42253+0x972>

000000000116fd60 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42246>:
 1170d39:	4c 89 e6             	mov    %r12,%rsi
 1170d3c:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1170d40:	4c 89 f9             	mov    %r15,%rcx
 1170d43:	49 89 d8             	mov    %rbx,%r8
 1170d46:	44 8b 4d c4          	mov    -0x3c(%rbp),%r9d
 1170d4a:	50                   	push   %rax
 1170d4b:	ff 75 a0             	push   -0x60(%rbp)
 1170d4e:	c5 f8 77             	vzeroupper 
 1170d51:	e8 4a 9c fe ff       	call   115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>
 1170d56:	48 83 c4 10          	add    $0x10,%rsp
 1170d5a:	44 0f b7 b5 4c ff ff 	movzwl -0xb4(%rbp),%r14d
 1170d61:	ff 
 1170d62:	66 45 85 f6          	test   %r14w,%r14w
 1170d66:	0f 85 01 05 00 00    	jne    117126d <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42246+0x150d>
 1170d6c:	80 bd 4e ff ff ff 01 	cmpb   $0x1,-0xb2(%rbp)
 1170d73:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
