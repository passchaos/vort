 115ca34:	mov    %rdx,0x2880(%rsp)
 115ca3c:	mov    $0x1,%edx
 115ca41:	mov    $0x1,%r8d
 115ca47:	lea    0x230(%rsp),%rsi
 115ca4f:	lea    0x3190(%rsp),%rcx
 115ca57:	lea    0x2880(%rsp),%r9
 115ca5f:	push   %r13
 115ca61:	push   $0x1
 115ca63:	vzeroupper 
 115ca66:	call   1155620 <zstd.rleSequencePayloadLenForValuesWithLiteralsLen>
 115ca6b:	add    $0x10,%rsp
 115ca6f:	movzwl 0x3c8(%rsp),%r14d
 115ca78:	test   %r14w,%r14w
 115ca7c:	jne    115cfb5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2615>
 115ca82:	mov    0x3c0(%rsp),%rbx
 115ca8a:	mov    0x18(%rsp),%rax
 115ca8f:	mov    0xd8(%rsp),%rcx
 115ca97:	mov    %rcx,0x230(%rsp)
 115ca9f:	mov    %r12,0x3190(%rsp)
 115caa7:	mov    %rax,0x2880(%rsp)
 115caaf:	mov    $0x1,%edx
 115cab4:	mov    $0x1,%r8d
 115caba:	lea    0x3c0(%rsp),%rdi
 115cac2:	lea    0x230(%rsp),%rsi
 115caca:	lea    0x3190(%rsp),%rcx
 115cad2:	lea    0x2880(%rsp),%r9
 115cada:	push   %r13
 115cadc:	push   $0x1
 115cade:	call   1155120 <zstd.predefinedSequencePayloadLenWithLiteralsLen>
 115cae3:	add    $0x10,%rsp
 115cae7:	movzwl 0x3c8(%rsp),%eax
 115caef:	test   %eax,%eax
 115caf1:	jne    115cfe3 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2643>
 115caf7:	mov    0x3c0(%rsp),%rax
 115caff:	cmp    %rbx,%rax
 115cb02:	cmovb  %rax,%rbx
 115cb06:	test   %r14w,%r14w
 115cb0a:	cmovne %rax,%rbx
 115cb0e:	mov    0x30(%rsp),%rcx
 115d0fe:	test   %al,%al
 115d100:	jne    115c361 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x19c1>
 115d106:	test   %al,%al
 115d108:	jne    115c361 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x19c1>
 115d10e:	lea    0x3c0(%rsp),%rdi
 115d116:	mov    0xd8(%rsp),%rsi
 115d11e:	mov    %r12,%rdx
 115d121:	mov    0x18(%rsp),%rcx
 115d126:	vzeroupper 
 115d129:	call   115df90 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase>
 115d12e:	mov    0x18(%rsp),%rdx
 115d133:	cmpb   $0x0,0x3c8(%rsp)
 115d13b:	je     115c361 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x19c1>
 115d141:	add    %r13,%r14
 115d144:	mov    0x48(%rsp),%rax
 115d149:	cmp    %r14,%rax
 115d14c:	cmovb  %rax,%r14
 115d150:	add    0x3c0(%rsp),%r14
 115d158:	setb   0x2880(%rsp)
 115d160:	jae    115d1f6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2856>
 115d166:	mov    0x18(%rsp),%rdx
 115d16b:	mov    0x60(%rsp),%r12
 115d170:	jmp    115c36d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x19cd>
 115d175:	mov    0xc8(%rsp),%r13
 115d17d:	mov    0x90(%rsp),%r12
