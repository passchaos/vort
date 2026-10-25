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

00000000011691b0 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42340>:
 116a583:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 116a587:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 116a58b:	4c 89 f9             	mov    %r15,%rcx
 116a58e:	49 89 d8             	mov    %rbx,%r8
 116a591:	44 8b 4d c4          	mov    -0x3c(%rbp),%r9d
 116a595:	50                   	push   %rax
 116a596:	41 54                	push   %r12
 116a598:	c5 f8 77             	vzeroupper 
 116a59b:	e8 00 04 ff ff       	call   115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>
 116a5a0:	48 83 c4 10          	add    $0x10,%rsp
 116a5a4:	44 0f b7 b5 24 ff ff 	movzwl -0xdc(%rbp),%r14d
 116a5ab:	ff 
 116a5ac:	66 45 85 f6          	test   %r14w,%r14w
 116a5b0:	0f 85 a3 05 00 00    	jne    116ab59 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42340+0x19a9>
 116a5b6:	80 bd 26 ff ff ff 01 	cmpb   $0x1,-0xda(%rbp)
 116a5bd:	75 65                	jne    116a624 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42340+0x1474>

000000000116c240 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42253>:
 116cb12:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 116cb16:	4c 89 e2             	mov    %r12,%rdx
 116cb19:	48 89 d9             	mov    %rbx,%rcx
 116cb1c:	4d 89 e8             	mov    %r13,%r8
 116cb1f:	44 8b 4d cc          	mov    -0x34(%rbp),%r9d
 116cb23:	50                   	push   %rax
 116cb24:	ff 75 98             	push   -0x68(%rbp)
 116cb27:	c5 f8 77             	vzeroupper 
 116cb2a:	e8 71 de fe ff       	call   115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>
 116cb2f:	48 83 c4 10          	add    $0x10,%rsp
 116cb33:	44 0f b7 b5 6c ff ff 	movzwl -0x94(%rbp),%r14d
 116cb3a:	ff 
 116cb3b:	66 45 85 f6          	test   %r14w,%r14w
 116cb3f:	0f 85 8a 04 00 00    	jne    116cfcf <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42253+0xd8f>
 116cb45:	80 bd 6e ff ff ff 01 	cmpb   $0x1,-0x92(%rbp)
 116cb4c:	75 64                	jne    116cbb2 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42253+0x972>

0000000001170140 <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42246>:
 1171119:	4c 89 e6             	mov    %r12,%rsi
 117111c:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1171120:	4c 89 f9             	mov    %r15,%rcx
 1171123:	49 89 d8             	mov    %rbx,%r8
 1171126:	44 8b 4d c4          	mov    -0x3c(%rbp),%r9d
 117112a:	50                   	push   %rax
 117112b:	ff 75 a0             	push   -0x60(%rbp)
 117112e:	c5 f8 77             	vzeroupper 
 1171131:	e8 6a 98 fe ff       	call   115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>
 1171136:	48 83 c4 10          	add    $0x10,%rsp
 117113a:	44 0f b7 b5 4c ff ff 	movzwl -0xb4(%rbp),%r14d
 1171141:	ff 
 1171142:	66 45 85 f6          	test   %r14w,%r14w
 1171146:	0f 85 01 05 00 00    	jne    117164d <zstd.emitNativeMatchCompressedBlockSerialWithBeamImpl__anon_42246+0x150d>
 117114c:	80 bd 4e ff ff ff 01 	cmpb   $0x1,-0xb2(%rbp)
 1171153:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
