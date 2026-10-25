
/home/passchaos/project-z/vort/.zig-cache/o/ed94ec1c4a213c549af1a1d632f56d71/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000111db20 <sort.block.block__anon_39113>:
 111db20:	push   %rbp
 111db21:	mov    %rsp,%rbp
 111db24:	push   %r15
 111db26:	push   %r14
 111db28:	push   %r13
 111db2a:	push   %r12
 111db2c:	push   %rbx
 111db2d:	sub    $0x628,%rsp
 111db34:	mov    %rdx,-0x30(%rbp)
 111db38:	cmp    $0x3,%rsi
 111db3c:	mov    %rdi,-0x38(%rbp)
 111db40:	ja     111dbaa <sort.block.block__anon_39113+0x8a>
 111db42:	cmp    $0x2,%rsi
 111db46:	je     1127052 <sort.block.block__anon_39113+0x9532>
 111db4c:	cmp    $0x3,%rsi
 111db50:	jne    112716d <sort.block.block__anon_39113+0x964d>
 111db56:	movzwl 0x2(%rdi),%ecx
 111db5a:	movzwl (%rdi),%r8d
 111db5e:	mov    -0x30(%rbp),%rax
 111db62:	mov    (%rax),%rdx
 111db65:	mov    %ecx,%r9d
 111db68:	shl    $0x4,%r9d
 111db6c:	mov    (%rdx,%r9,1),%rdi
 111db70:	mov    %r8d,%r10d
 111db73:	shl    $0x4,%r10d
 111db77:	mov    (%rdx,%r10,1),%r11
 111db7b:	mov    %ecx,%eax
 111db7d:	shr    $0x8,%eax
 111db80:	mov    %ecx,%esi
 111db82:	cmp    %r11,%rdi
 111db85:	jne    11270a9 <sort.block.block__anon_39113+0x9589>
 111db8b:	add    %rdx,%r9
 111db8e:	add    %rdx,%r10
 111db91:	movzwl 0xe(%r9),%r9d
 111db96:	cmp    0xe(%r10),%r9w
 111db9b:	jb     11270af <sort.block.block__anon_39113+0x958f>
 111dba1:	mov    -0x38(%rbp),%r10
 111dba5:	jmp    11270e4 <sort.block.block__anon_39113+0x95c4>
 111dbaa:	lzcnt  %rsi,%rax
 111dbaf:	mov    $0x3d,%cl
 111dbb1:	sub    %al,%cl
 111dbb3:	not    %al
 111dbb5:	mov    $0x1,%edx
 111dbba:	shlx   %rax,%rdx,%rax
 111dbbf:	shr    $0x2,%rax
 111dbc3:	shrx   %rcx,%rsi,%rdi
 111dbc8:	mov    %rax,-0x120(%rbp)
 111dbcf:	dec    %rax
 111dbd2:	and    %rsi,%rax
 111dbd5:	mov    %rax,-0xf8(%rbp)
 111dbdc:	xor    %eax,%eax
 111dbde:	xor    %edx,%edx
 111dbe0:	mov    %rsi,-0x118(%rbp)
 111dbe7:	mov    %rdi,-0xb8(%rbp)
 111dbee:	jmp    111dc35 <sort.block.block__anon_39113+0x115>
 111dbf0:	mov    %r9d,%ecx
 111dbf3:	shr    $0x8,%ecx
 111dbf6:	mov    %r9b,0x2(%r8)
 111dbfa:	mov    %r14b,0x4(%r8)
 111dbfe:	mov    $0x5,%edi
 111dc03:	mov    $0x3,%r9d
 111dc09:	mov    %cl,(%r8,%r9,1)
 111dc0d:	mov    %r15b,(%r8,%rdi,1)
 111dc11:	mov    -0xb8(%rbp),%rdi
 111dc18:	add    %rdi,%rax
 111dc1b:	sub    -0x98(%rbp),%rdx
 111dc22:	add    %r13,%rax
 111dc25:	mov    -0x118(%rbp),%rsi
 111dc2c:	cmp    %rsi,%rax
 111dc2f:	jae    111f80b <sort.block.block__anon_39113+0x1ceb>
 111dc35:	add    -0xf8(%rbp),%rdx
 111dc3c:	xor    %r13d,%r13d
 111dc3f:	mov    -0x120(%rbp),%rcx
 111dc46:	cmp    %rcx,%rdx
 111dc49:	setae  %r13b
 111dc4d:	mov    $0x0,%esi
 111dc52:	cmovae %rcx,%rsi
 111dc56:	mov    %rsi,-0x98(%rbp)
 111dc5d:	lea    (%rdi,%r13,1),%rcx
 111dc61:	add    $0xfffffffffffffffc,%rcx
 111dc65:	cmp    $0x4,%rcx
 111dc69:	ja     111dc11 <sort.block.block__anon_39113+0xf1>
 111dc6b:	mov    -0x38(%rbp),%rsi
 111dc6f:	lea    (%rsi,%rax,2),%r8
 111dc73:	lea    -0x113c36(%rip),%rsi        # 100a044 <__anon_3623+0x763c>
 111dc7a:	movslq (%rsi,%rcx,4),%rcx
 111dc7e:	add    %rsi,%rcx
 111dc81:	jmp    *%rcx
 111dc83:	mov    -0x30(%rbp),%rcx
 111dc87:	mov    (%rcx),%rcx
 111dc8a:	movzwl 0x2(%r8),%edi
 111dc8f:	movzwl (%r8),%r9d
 111dc93:	mov    %edi,%esi
 111dc95:	shl    $0x4,%esi
 111dc98:	mov    (%rcx,%rsi,1),%r11
 111dc9c:	mov    %r9d,%r10d
 111dc9f:	shl    $0x4,%r10d
 111dca3:	mov    (%rcx,%r10,1),%rbx
 111dca7:	cmp    %rbx,%r11
 111dcaa:	jne    111e66d <sort.block.block__anon_39113+0xb4d>
 111dcb0:	add    %rcx,%rsi
 111dcb3:	add    %rcx,%r10
 111dcb6:	movzwl 0xe(%rsi),%esi
 111dcba:	cmp    0xe(%r10),%si
 111dcbf:	jb     111e673 <sort.block.block__anon_39113+0xb53>
 111dcc5:	mov    $0x1,%sil
 111dcc8:	mov    %esi,-0x48(%rbp)
 111dccb:	xor    %r14d,%r14d
 111dcce:	jmp    111e69e <sort.block.block__anon_39113+0xb7e>
 111dcd3:	mov    -0x30(%rbp),%rcx
 111dcd7:	mov    (%rcx),%r10
 111dcda:	movzwl 0x2(%r8),%ecx
 111dcdf:	movzwl (%r8),%edi
 111dce3:	mov    %ecx,%esi
 111dce5:	shl    $0x4,%esi
 111dce8:	mov    (%r10,%rsi,1),%r11
 111dcec:	mov    %edi,%r9d
 111dcef:	shl    $0x4,%r9d
 111dcf3:	mov    (%r10,%r9,1),%rbx
 111dcf7:	cmp    %rbx,%r11
 111dcfa:	jne    111de1c <sort.block.block__anon_39113+0x2fc>
 111dd00:	add    %r10,%rsi
 111dd03:	add    %r10,%r9
 111dd06:	movzwl 0xe(%rsi),%esi
 111dd0a:	cmp    0xe(%r9),%si
 111dd0f:	jb     111de22 <sort.block.block__anon_39113+0x302>
 111dd15:	mov    $0x1,%cl
 111dd17:	mov    %ecx,-0x48(%rbp)
 111dd1a:	movl   $0x0,-0x58(%rbp)
 111dd21:	jmp    111de50 <sort.block.block__anon_39113+0x330>
 111dd26:	mov    -0x30(%rbp),%rcx
 111dd2a:	mov    (%rcx),%r10
 111dd2d:	movzwl 0x4(%r8),%ecx
 111dd32:	movzwl 0x2(%r8),%edi
 111dd37:	mov    %ecx,%esi
 111dd39:	shl    $0x4,%esi
 111dd3c:	mov    (%r10,%rsi,1),%r11
 111dd40:	mov    %edi,%r9d
 111dd43:	shl    $0x4,%r9d
 111dd47:	mov    (%r10,%r9,1),%rbx
 111dd4b:	cmp    %rbx,%r11
 111dd4e:	jne    111e1c0 <sort.block.block__anon_39113+0x6a0>
 111dd54:	add    %r10,%rsi
 111dd57:	add    %r10,%r9
 111dd5a:	movzwl 0xe(%rsi),%esi
 111dd5e:	cmp    0xe(%r9),%si
 111dd63:	jb     111e1c6 <sort.block.block__anon_39113+0x6a6>
 111dd69:	mov    $0x2,%r14b
 111dd6c:	mov    $0x1,%r15b
 111dd6f:	jmp    111e1ef <sort.block.block__anon_39113+0x6cf>
 111dd74:	mov    -0x30(%rbp),%rcx
 111dd78:	mov    (%rcx),%r10
 111dd7b:	movzwl 0x4(%r8),%ecx
 111dd80:	movzwl 0x2(%r8),%edi
 111dd85:	mov    %ecx,%esi
 111dd87:	shl    $0x4,%esi
 111dd8a:	mov    (%r10,%rsi,1),%r11
 111dd8e:	mov    %edi,%r9d
 111dd91:	shl    $0x4,%r9d
 111dd95:	mov    (%r10,%r9,1),%rbx
 111dd99:	cmp    %rbx,%r11
 111dd9c:	jne    111e3ac <sort.block.block__anon_39113+0x88c>
 111dda2:	add    %r10,%rsi
 111dda5:	add    %r10,%r9
 111dda8:	movzwl 0xe(%rsi),%esi
 111ddac:	cmp    0xe(%r9),%si
 111ddb1:	jb     111e3b2 <sort.block.block__anon_39113+0x892>
 111ddb7:	mov    $0x2,%cl
 111ddb9:	mov    %ecx,-0x48(%rbp)
 111ddbc:	movb   $0x1,-0x80(%rbp)
 111ddc0:	jmp    111e3de <sort.block.block__anon_39113+0x8be>
 111ddc5:	mov    -0x30(%rbp),%rcx
 111ddc9:	mov    (%rcx),%r10
 111ddcc:	movzwl 0x2(%r8),%ecx
 111ddd1:	movzwl (%r8),%edi
 111ddd5:	mov    %ecx,%esi
 111ddd7:	shl    $0x4,%esi
 111ddda:	mov    (%r10,%rsi,1),%r11
 111ddde:	mov    %edi,%r9d
 111dde1:	shl    $0x4,%r9d
 111dde5:	mov    (%r10,%r9,1),%rbx
 111dde9:	cmp    %rbx,%r11
 111ddec:	mov    %r13,-0x40(%rbp)
 111ddf0:	jne    111e6ee <sort.block.block__anon_39113+0xbce>
 111ddf6:	add    %r10,%rsi
 111ddf9:	add    %r10,%r9
 111ddfc:	movzwl 0xe(%rsi),%esi
 111de00:	cmp    0xe(%r9),%si
 111de05:	jb     111e6f4 <sort.block.block__anon_39113+0xbd4>
 111de0b:	mov    $0x1,%cl
 111de0d:	mov    %ecx,-0x50(%rbp)
 111de10:	movl   $0x0,-0x48(%rbp)
 111de17:	jmp    111e722 <sort.block.block__anon_39113+0xc02>
 111de1c:	jae    111dd15 <sort.block.block__anon_39113+0x1f5>
 111de22:	mov    %edi,%esi
 111de24:	shr    $0x8,%esi
 111de27:	mov    %ecx,%r9d
 111de2a:	shr    $0x8,%r9d
 111de2e:	mov    %cl,(%r8)
 111de31:	mov    %dil,0x2(%r8)
 111de35:	mov    %r9b,0x1(%r8)
 111de39:	mov    %sil,0x3(%r8)
 111de3d:	mov    -0x30(%rbp),%rcx
 111de41:	mov    (%rcx),%r10
 111de44:	mov    $0x1,%cl
 111de46:	mov    %ecx,-0x58(%rbp)
 111de49:	movl   $0x0,-0x48(%rbp)
 111de50:	movzwl 0x6(%r8),%ecx
 111de55:	movzwl 0x4(%r8),%edi
 111de5a:	mov    %ecx,%esi
 111de5c:	shl    $0x4,%esi
 111de5f:	mov    (%r10,%rsi,1),%r11
 111de63:	mov    %edi,%r9d
 111de66:	shl    $0x4,%r9d
 111de6a:	mov    (%r10,%r9,1),%rbx
 111de6e:	cmp    %rbx,%r11
 111de71:	jne    111de8d <sort.block.block__anon_39113+0x36d>
 111de73:	add    %r10,%rsi
 111de76:	add    %r10,%r9
 111de79:	movzwl 0xe(%rsi),%esi
 111de7d:	cmp    0xe(%r9),%si
 111de82:	jb     111de8f <sort.block.block__anon_39113+0x36f>
 111de84:	movb   $0x3,-0x50(%rbp)
 111de88:	mov    $0x2,%r15b
 111de8b:	jmp    111deb9 <sort.block.block__anon_39113+0x399>
 111de8d:	jae    111de84 <sort.block.block__anon_39113+0x364>
 111de8f:	mov    %edi,%esi
 111de91:	shr    $0x8,%esi
 111de94:	mov    %ecx,%r9d
 111de97:	shr    $0x8,%r9d
 111de9b:	mov    %cl,0x4(%r8)
 111de9f:	mov    %dil,0x6(%r8)
 111dea3:	mov    %r9b,0x5(%r8)
 111dea7:	mov    %sil,0x7(%r8)
 111deab:	mov    -0x30(%rbp),%rcx
 111deaf:	mov    (%rcx),%r10
 111deb2:	movb   $0x2,-0x50(%rbp)
 111deb6:	mov    $0x3,%r15b
 111deb9:	movzwl 0xa(%r8),%edi
 111debe:	movzwl 0x8(%r8),%r9d
 111dec3:	mov    %edi,%esi
 111dec5:	shl    $0x4,%esi
 111dec8:	mov    (%r10,%rsi,1),%rbx
 111decc:	mov    %r9d,%r11d
 111decf:	shl    $0x4,%r11d
 111ded3:	mov    (%r10,%r11,1),%r14
 111ded7:	cmp    %r14,%rbx
 111deda:	jne    111def6 <sort.block.block__anon_39113+0x3d6>
 111dedc:	add    %r10,%rsi
 111dedf:	add    %r10,%r11
 111dee2:	movzwl 0xe(%rsi),%esi
 111dee6:	cmp    0xe(%r11),%si
 111deeb:	jb     111def8 <sort.block.block__anon_39113+0x3d8>
 111deed:	movb   $0x5,-0x80(%rbp)
 111def1:	mov    $0x4,%r11b
 111def4:	jmp    111df23 <sort.block.block__anon_39113+0x403>
 111def6:	jae    111deed <sort.block.block__anon_39113+0x3cd>
 111def8:	mov    %r9d,%esi
 111defb:	shr    $0x8,%esi
 111defe:	mov    %edi,%r10d
 111df01:	shr    $0x8,%r10d
 111df05:	mov    %dil,0x8(%r8)
 111df09:	mov    %r9b,0xa(%r8)
 111df0d:	mov    %r10b,0x9(%r8)
 111df11:	mov    %sil,0xb(%r8)
 111df15:	mov    -0x30(%rbp),%rcx
 111df19:	mov    (%rcx),%r10
 111df1c:	movb   $0x4,-0x80(%rbp)
 111df20:	mov    $0x5,%r11b
 111df23:	movzwl 0xe(%r8),%edi
 111df28:	movzwl 0xc(%r8),%ebx
 111df2d:	mov    %edi,%esi
 111df2f:	shl    $0x4,%esi
 111df32:	mov    (%r10,%rsi,1),%r9
 111df36:	mov    %ebx,%r14d
 111df39:	shl    $0x4,%r14d
 111df3d:	mov    (%r10,%r14,1),%r12
 111df41:	cmp    %r12,%r9
 111df44:	mov    %r13,-0x40(%rbp)
 111df48:	jne    111df63 <sort.block.block__anon_39113+0x443>
 111df4a:	add    %r10,%rsi
 111df4d:	add    %r10,%r14
 111df50:	movzwl 0xe(%rsi),%esi
 111df54:	cmp    0xe(%r14),%si
 111df59:	jb     111df65 <sort.block.block__anon_39113+0x445>
 111df5b:	mov    $0x7,%r14b
 111df5e:	mov    $0x6,%r12b
 111df61:	jmp    111df8e <sort.block.block__anon_39113+0x46e>
 111df63:	jae    111df5b <sort.block.block__anon_39113+0x43b>
 111df65:	mov    %ebx,%esi
 111df67:	shr    $0x8,%esi
 111df6a:	mov    %edi,%r9d
 111df6d:	shr    $0x8,%r9d
 111df71:	mov    %dil,0xc(%r8)
 111df75:	mov    %bl,0xe(%r8)
 111df79:	mov    %r9b,0xd(%r8)
 111df7d:	mov    %sil,0xf(%r8)
 111df81:	mov    -0x30(%rbp),%rcx
 111df85:	mov    (%rcx),%r10
 111df88:	mov    $0x6,%r14b
 111df8b:	mov    $0x7,%r12b
 111df8e:	movzwl 0x4(%r8),%edi
 111df93:	movzwl (%r8),%ebx
 111df97:	mov    %edi,%esi
 111df99:	shl    $0x4,%esi
 111df9c:	mov    (%r10,%rsi,1),%r13
 111dfa0:	mov    %ebx,%r9d
 111dfa3:	shl    $0x4,%r9d
 111dfa7:	mov    (%r10,%r9,1),%rcx
 111dfab:	cmp    %rcx,%r13
 111dfae:	jne    111dfd2 <sort.block.block__anon_39113+0x4b2>
 111dfb0:	add    %r10,%rsi
 111dfb3:	add    %r10,%r9
 111dfb6:	movzwl 0xe(%rsi),%ecx
 111dfba:	cmp    0xe(%r9),%cx
 111dfbf:	jb     111dfd4 <sort.block.block__anon_39113+0x4b4>
 111dfc1:	mov    -0x58(%rbp),%ecx
 111dfc4:	mov    %cl,-0xc8(%rbp)
 111dfca:	mov    %r15d,%ecx
 111dfcd:	mov    %ecx,-0x58(%rbp)
 111dfd0:	jmp    111dffb <sort.block.block__anon_39113+0x4db>
 111dfd2:	jae    111dfc1 <sort.block.block__anon_39113+0x4a1>
 111dfd4:	mov    %ebx,%ecx
 111dfd6:	shr    $0x8,%ecx
 111dfd9:	mov    %edi,%esi
 111dfdb:	shr    $0x8,%esi
 111dfde:	mov    %dil,(%r8)
 111dfe1:	mov    %bl,0x4(%r8)
 111dfe5:	mov    %sil,0x1(%r8)
 111dfe9:	mov    %cl,0x5(%r8)
 111dfed:	mov    -0x30(%rbp),%rcx
 111dff1:	mov    (%rcx),%r10
 111dff4:	mov    %r15b,-0xc8(%rbp)
 111dffb:	movzwl 0x6(%r8),%edi
 111e000:	movzwl 0x2(%r8),%ebx
 111e005:	mov    %edi,%esi
 111e007:	shl    $0x4,%esi
 111e00a:	mov    (%r10,%rsi,1),%rcx
 111e00e:	mov    %ebx,%r9d
 111e011:	shl    $0x4,%r9d
 111e015:	mov    (%r10,%r9,1),%r15
 111e019:	cmp    %r15,%rcx
 111e01c:	jne    111e03e <sort.block.block__anon_39113+0x51e>
 111e01e:	add    %r10,%rsi
 111e021:	add    %r10,%r9
 111e024:	movzwl 0xe(%rsi),%ecx
 111e028:	cmp    0xe(%r9),%cx
 111e02d:	jb     111e040 <sort.block.block__anon_39113+0x520>
 111e02f:	mov    -0x48(%rbp),%ecx
 111e032:	mov    %ecx,%r15d
 111e035:	movzbl -0x50(%rbp),%ecx
 111e039:	mov    %ecx,-0x48(%rbp)
 111e03c:	jmp    111e066 <sort.block.block__anon_39113+0x546>
 111e03e:	jae    111e02f <sort.block.block__anon_39113+0x50f>
 111e040:	mov    %ebx,%ecx
 111e042:	shr    $0x8,%ecx
 111e045:	mov    %edi,%esi
 111e047:	shr    $0x8,%esi
 111e04a:	mov    %dil,0x2(%r8)
 111e04e:	mov    %bl,0x6(%r8)
 111e052:	mov    %sil,0x3(%r8)
 111e056:	mov    %cl,0x7(%r8)
 111e05a:	mov    -0x30(%rbp),%rcx
 111e05e:	mov    (%rcx),%r10
 111e061:	movzbl -0x50(%rbp),%r15d
 111e066:	movzwl 0xc(%r8),%ecx
 111e06b:	movzwl 0x8(%r8),%edi
 111e070:	mov    %ecx,%esi
 111e072:	shl    $0x4,%esi
 111e075:	mov    (%r10,%rsi,1),%rbx
 111e079:	mov    %edi,%r9d
 111e07c:	shl    $0x4,%r9d
 111e080:	mov    (%r10,%r9,1),%r13
 111e084:	cmp    %r13,%rbx
 111e087:	jne    111e0a3 <sort.block.block__anon_39113+0x583>
 111e089:	add    %r10,%rsi
 111e08c:	add    %r10,%r9
 111e08f:	movzwl 0xe(%rsi),%esi
 111e093:	cmp    0xe(%r9),%si
 111e098:	jb     111e0a5 <sort.block.block__anon_39113+0x585>
 111e09a:	mov    %r11b,-0x50(%rbp)
 111e09e:	mov    %r12d,%r11d
 111e0a1:	jmp    111e0cc <sort.block.block__anon_39113+0x5ac>
 111e0a3:	jae    111e09a <sort.block.block__anon_39113+0x57a>
 111e0a5:	mov    %edi,%esi
 111e0a7:	shr    $0x8,%esi
 111e0aa:	mov    %ecx,%r9d
 111e0ad:	shr    $0x8,%r9d
 111e0b1:	mov    %cl,0x8(%r8)
 111e0b5:	mov    %dil,0xc(%r8)
 111e0b9:	mov    %r9b,0x9(%r8)
 111e0bd:	mov    %sil,0xd(%r8)
 111e0c1:	mov    -0x30(%rbp),%rcx
 111e0c5:	mov    (%rcx),%r10
 111e0c8:	mov    %r12b,-0x50(%rbp)
 111e0cc:	movzwl 0xe(%r8),%edi
 111e0d1:	movzwl 0xa(%r8),%ebx
 111e0d6:	mov    %edi,%esi
 111e0d8:	shl    $0x4,%esi
 111e0db:	mov    (%r10,%rsi,1),%rcx
 111e0df:	mov    %ebx,%r9d
 111e0e2:	shl    $0x4,%r9d
 111e0e6:	mov    (%r10,%r9,1),%r12
 111e0ea:	cmp    %r12,%rcx
 111e0ed:	jne    111e10b <sort.block.block__anon_39113+0x5eb>
 111e0ef:	add    %r10,%rsi
 111e0f2:	add    %r10,%r9
 111e0f5:	movzwl 0xe(%rsi),%ecx
 111e0f9:	cmp    0xe(%r9),%cx
 111e0fe:	jb     111e10d <sort.block.block__anon_39113+0x5ed>
 111e100:	movzbl -0x80(%rbp),%r12d
 111e105:	mov    %r14b,-0x80(%rbp)
 111e109:	jmp    111e131 <sort.block.block__anon_39113+0x611>
 111e10b:	jae    111e100 <sort.block.block__anon_39113+0x5e0>
 111e10d:	mov    %ebx,%ecx
 111e10f:	shr    $0x8,%ecx
 111e112:	mov    %edi,%esi
 111e114:	shr    $0x8,%esi
 111e117:	mov    %dil,0xa(%r8)
 111e11b:	mov    %bl,0xe(%r8)
 111e11f:	mov    %sil,0xb(%r8)
 111e123:	mov    %cl,0xf(%r8)
 111e127:	mov    -0x30(%rbp),%rcx
 111e12b:	mov    (%rcx),%r10
 111e12e:	mov    %r14d,%r12d
 111e131:	movzwl 0x4(%r8),%edi
 111e136:	movzwl 0x2(%r8),%ebx
 111e13b:	mov    %edi,%esi
 111e13d:	shl    $0x4,%esi
 111e140:	mov    (%r10,%rsi,1),%r14
 111e144:	mov    %ebx,%r9d
 111e147:	shl    $0x4,%r9d
 111e14b:	mov    (%r10,%r9,1),%rcx
 111e14f:	cmp    %rcx,%r14
 111e152:	jne    111e17f <sort.block.block__anon_39113+0x65f>
 111e154:	add    %r10,%rsi
 111e157:	add    %r10,%r9
 111e15a:	movzwl 0xe(%r9),%ecx
 111e15f:	movzwl 0xe(%rsi),%esi
 111e163:	cmp    %cx,%si
 111e166:	mov    -0x58(%rbp),%r9d
 111e16a:	jb     111e197 <sort.block.block__anon_39113+0x677>
 111e16c:	cmp    %r9b,%r15b
 111e16f:	jbe    111e8cf <sort.block.block__anon_39113+0xdaf>
 111e175:	cmp    %si,%cx
 111e178:	jae    111e197 <sort.block.block__anon_39113+0x677>
 111e17a:	jmp    111e8cf <sort.block.block__anon_39113+0xdaf>
 111e17f:	mov    -0x58(%rbp),%r9d
 111e183:	jb     111e197 <sort.block.block__anon_39113+0x677>
 111e185:	cmp    %r9b,%r15b
 111e188:	jbe    111e8cf <sort.block.block__anon_39113+0xdaf>
 111e18e:	cmp    %r14,%rcx
 111e191:	jb     111e8cf <sort.block.block__anon_39113+0xdaf>
 111e197:	mov    %ebx,%ecx
 111e199:	shr    $0x8,%ecx
 111e19c:	mov    %edi,%esi
 111e19e:	shr    $0x8,%esi
 111e1a1:	mov    %dil,0x2(%r8)
 111e1a5:	mov    %bl,0x4(%r8)
 111e1a9:	mov    %sil,0x3(%r8)
 111e1ad:	mov    %cl,0x5(%r8)
 111e1b1:	mov    -0x30(%rbp),%rcx
 111e1b5:	mov    (%rcx),%r10
 111e1b8:	mov    %r9d,%r14d
 111e1bb:	jmp    111e8d5 <sort.block.block__anon_39113+0xdb5>
 111e1c0:	jae    111dd69 <sort.block.block__anon_39113+0x249>
 111e1c6:	mov    %edi,%esi
 111e1c8:	shr    $0x8,%esi
 111e1cb:	mov    %ecx,%r9d
 111e1ce:	shr    $0x8,%r9d
 111e1d2:	mov    %cl,0x2(%r8)
 111e1d6:	mov    %dil,0x4(%r8)
 111e1da:	mov    %r9b,0x3(%r8)
 111e1de:	mov    %sil,0x5(%r8)
 111e1e2:	mov    -0x30(%rbp),%rcx
 111e1e6:	mov    (%rcx),%r10
 111e1e9:	mov    $0x1,%r14b
 111e1ec:	mov    $0x2,%r15b
 111e1ef:	movzwl 0xa(%r8),%ecx
 111e1f4:	movzwl 0x8(%r8),%edi
 111e1f9:	mov    %ecx,%esi
 111e1fb:	shl    $0x4,%esi
 111e1fe:	mov    (%r10,%rsi,1),%r9
 111e202:	mov    %edi,%r11d
 111e205:	shl    $0x4,%r11d
 111e209:	mov    (%r10,%r11,1),%rbx
 111e20d:	cmp    %rbx,%r9
 111e210:	jne    111e22c <sort.block.block__anon_39113+0x70c>
 111e212:	add    %r10,%rsi
 111e215:	add    %r10,%r11
 111e218:	movzwl 0xe(%rsi),%esi
 111e21c:	cmp    0xe(%r11),%si
 111e221:	jb     111e22e <sort.block.block__anon_39113+0x70e>
 111e223:	movb   $0x5,-0x50(%rbp)
 111e227:	mov    $0x4,%r12b
 111e22a:	jmp    111e258 <sort.block.block__anon_39113+0x738>
 111e22c:	jae    111e223 <sort.block.block__anon_39113+0x703>
 111e22e:	mov    %edi,%esi
 111e230:	shr    $0x8,%esi
 111e233:	mov    %ecx,%r9d
 111e236:	shr    $0x8,%r9d
 111e23a:	mov    %cl,0x8(%r8)
 111e23e:	mov    %dil,0xa(%r8)
 111e242:	mov    %r9b,0x9(%r8)
 111e246:	mov    %sil,0xb(%r8)
 111e24a:	mov    -0x30(%rbp),%rcx
 111e24e:	mov    (%rcx),%r10
 111e251:	movb   $0x4,-0x50(%rbp)
 111e255:	mov    $0x5,%r12b
 111e258:	movzwl 0x4(%r8),%edi
 111e25d:	movzwl (%r8),%r11d
 111e261:	mov    %edi,%esi
 111e263:	shl    $0x4,%esi
 111e266:	mov    (%r10,%rsi,1),%rcx
 111e26a:	mov    %r11d,%ebx
 111e26d:	shl    $0x4,%ebx
 111e270:	mov    (%r10,%rbx,1),%r9
 111e274:	cmp    %r9,%rcx
 111e277:	mov    %r13,-0x40(%rbp)
 111e27b:	jne    111e292 <sort.block.block__anon_39113+0x772>
 111e27d:	add    %r10,%rsi
 111e280:	add    %r10,%rbx
 111e283:	movzwl 0xe(%rsi),%ecx
 111e287:	cmp    0xe(%rbx),%cx
 111e28b:	jb     111e294 <sort.block.block__anon_39113+0x774>
 111e28d:	xor    %r11d,%r11d
 111e290:	jmp    111e2bb <sort.block.block__anon_39113+0x79b>
 111e292:	jae    111e28d <sort.block.block__anon_39113+0x76d>
 111e294:	mov    %r11d,%ecx
 111e297:	shr    $0x8,%ecx
 111e29a:	mov    %edi,%esi
 111e29c:	shr    $0x8,%esi
 111e29f:	mov    %dil,(%r8)
 111e2a2:	mov    %r11b,0x4(%r8)
 111e2a6:	mov    %sil,0x1(%r8)
 111e2aa:	mov    %cl,0x5(%r8)
 111e2ae:	mov    -0x30(%rbp),%rcx
 111e2b2:	mov    (%rcx),%r10
 111e2b5:	mov    %r14d,%r11d
 111e2b8:	xor    %r14d,%r14d
 111e2bb:	mov    %r14d,-0x48(%rbp)
 111e2bf:	movzwl 0xa(%r8),%edi
 111e2c4:	movzwl 0x6(%r8),%ebx
 111e2c9:	mov    %edi,%esi
 111e2cb:	shl    $0x4,%esi
 111e2ce:	mov    (%r10,%rsi,1),%rcx
 111e2d2:	mov    %ebx,%r13d
 111e2d5:	shl    $0x4,%r13d
 111e2d9:	mov    (%r10,%r13,1),%r9
 111e2dd:	cmp    %r9,%rcx
 111e2e0:	jne    111e2f8 <sort.block.block__anon_39113+0x7d8>
 111e2e2:	add    %r10,%rsi
 111e2e5:	add    %r10,%r13
 111e2e8:	movzwl 0xe(%rsi),%ecx
 111e2ec:	mov    $0x3,%r14b
 111e2ef:	cmp    0xe(%r13),%cx
 111e2f4:	jb     111e2fd <sort.block.block__anon_39113+0x7dd>
 111e2f6:	jmp    111e327 <sort.block.block__anon_39113+0x807>
 111e2f8:	mov    $0x3,%r14b
 111e2fb:	jae    111e327 <sort.block.block__anon_39113+0x807>
 111e2fd:	mov    %ebx,%ecx
 111e2ff:	shr    $0x8,%ecx
 111e302:	mov    %edi,%esi
 111e304:	shr    $0x8,%esi
 111e307:	mov    %dil,0x6(%r8)
 111e30b:	mov    %bl,0xa(%r8)
 111e30f:	mov    %sil,0x7(%r8)
 111e313:	mov    %cl,0xb(%r8)
 111e317:	mov    -0x30(%rbp),%rcx
 111e31b:	mov    (%rcx),%r10
 111e31e:	movzbl -0x50(%rbp),%r14d
 111e323:	movb   $0x3,-0x50(%rbp)
 111e327:	movzwl 0x2(%r8),%edi
 111e32c:	movzwl (%r8),%ebx
 111e330:	mov    %edi,%esi
 111e332:	shl    $0x4,%esi
 111e335:	mov    (%r10,%rsi,1),%r13
 111e339:	mov    %ebx,%r9d
 111e33c:	shl    $0x4,%r9d
 111e340:	mov    (%r10,%r9,1),%rcx
 111e344:	cmp    %rcx,%r13
 111e347:	jne    111e370 <sort.block.block__anon_39113+0x850>
 111e349:	add    %r10,%rsi
 111e34c:	add    %r10,%r9
 111e34f:	movzwl 0xe(%r9),%ecx
 111e354:	movzwl 0xe(%rsi),%esi
 111e358:	cmp    %cx,%si
 111e35b:	jb     111e384 <sort.block.block__anon_39113+0x864>
 111e35d:	cmp    %r15b,%r11b
 111e360:	jbe    111ed49 <sort.block.block__anon_39113+0x1229>
 111e366:	cmp    %si,%cx
 111e369:	jae    111e384 <sort.block.block__anon_39113+0x864>
 111e36b:	jmp    111ed49 <sort.block.block__anon_39113+0x1229>
 111e370:	jb     111e384 <sort.block.block__anon_39113+0x864>
 111e372:	cmp    %r15b,%r11b
 111e375:	jbe    111ed49 <sort.block.block__anon_39113+0x1229>
 111e37b:	cmp    %r13,%rcx
 111e37e:	jb     111ed49 <sort.block.block__anon_39113+0x1229>
 111e384:	mov    %ebx,%ecx
 111e386:	shr    $0x8,%ecx
 111e389:	mov    %edi,%esi
 111e38b:	shr    $0x8,%esi
 111e38e:	mov    %dil,(%r8)
 111e391:	mov    %bl,0x2(%r8)
 111e395:	mov    %sil,0x1(%r8)
 111e399:	mov    %cl,0x3(%r8)
 111e39d:	mov    -0x30(%rbp),%rcx
 111e3a1:	mov    (%rcx),%r10
 111e3a4:	mov    %r15d,%r13d
 111e3a7:	jmp    111ed4f <sort.block.block__anon_39113+0x122f>
 111e3ac:	jae    111ddb7 <sort.block.block__anon_39113+0x297>
 111e3b2:	mov    %edi,%esi
 111e3b4:	shr    $0x8,%esi
 111e3b7:	mov    %ecx,%r9d
 111e3ba:	shr    $0x8,%r9d
 111e3be:	mov    %cl,0x2(%r8)
 111e3c2:	mov    %dil,0x4(%r8)
 111e3c6:	mov    %r9b,0x3(%r8)
 111e3ca:	mov    %sil,0x5(%r8)
 111e3ce:	mov    -0x30(%rbp),%rcx
 111e3d2:	mov    (%rcx),%r10
 111e3d5:	mov    $0x1,%cl
 111e3d7:	mov    %ecx,-0x48(%rbp)
 111e3da:	movb   $0x2,-0x80(%rbp)
 111e3de:	movzwl 0x8(%r8),%ecx
 111e3e3:	movzwl 0x6(%r8),%edi
 111e3e8:	mov    %ecx,%esi
 111e3ea:	shl    $0x4,%esi
 111e3ed:	mov    (%r10,%rsi,1),%r11
 111e3f1:	mov    %edi,%r9d
 111e3f4:	shl    $0x4,%r9d
 111e3f8:	mov    (%r10,%r9,1),%rbx
 111e3fc:	cmp    %rbx,%r11
 111e3ff:	jne    111e41a <sort.block.block__anon_39113+0x8fa>
 111e401:	add    %r10,%rsi
 111e404:	add    %r10,%r9
 111e407:	movzwl 0xe(%rsi),%esi
 111e40b:	cmp    0xe(%r9),%si
 111e410:	jb     111e41c <sort.block.block__anon_39113+0x8fc>
 111e412:	movb   $0x4,-0x58(%rbp)
 111e416:	mov    $0x3,%cl
 111e418:	jmp    111e445 <sort.block.block__anon_39113+0x925>
 111e41a:	jae    111e412 <sort.block.block__anon_39113+0x8f2>
 111e41c:	mov    %edi,%esi
 111e41e:	shr    $0x8,%esi
 111e421:	mov    %ecx,%r9d
 111e424:	shr    $0x8,%r9d
 111e428:	mov    %cl,0x6(%r8)
 111e42c:	mov    %dil,0x8(%r8)
 111e430:	mov    %r9b,0x7(%r8)
 111e434:	mov    %sil,0x9(%r8)
 111e438:	mov    -0x30(%rbp),%rcx
 111e43c:	mov    (%rcx),%r10
 111e43f:	movb   $0x3,-0x58(%rbp)
 111e443:	mov    $0x4,%cl
 111e445:	movzwl 0xc(%r8),%edi
 111e44a:	movzwl 0xa(%r8),%r11d
 111e44f:	mov    %edi,%esi
 111e451:	shl    $0x4,%esi
 111e454:	mov    (%r10,%rsi,1),%r9
 111e458:	mov    %r11d,%ebx
 111e45b:	shl    $0x4,%ebx
 111e45e:	mov    (%r10,%rbx,1),%r14
 111e462:	cmp    %r14,%r9
 111e465:	jne    111e47f <sort.block.block__anon_39113+0x95f>
 111e467:	add    %r10,%rsi
 111e46a:	add    %r10,%rbx
 111e46d:	movzwl 0xe(%rsi),%esi
 111e471:	cmp    0xe(%rbx),%si
 111e475:	jb     111e481 <sort.block.block__anon_39113+0x961>
 111e477:	mov    $0x6,%r14b
 111e47a:	mov    $0x5,%r12b
 111e47d:	jmp    111e4ab <sort.block.block__anon_39113+0x98b>
 111e47f:	jae    111e477 <sort.block.block__anon_39113+0x957>
 111e481:	mov    %r11d,%esi
 111e484:	shr    $0x8,%esi
 111e487:	mov    %edi,%r9d
 111e48a:	shr    $0x8,%r9d
 111e48e:	mov    %dil,0xa(%r8)
 111e492:	mov    %r11b,0xc(%r8)
 111e496:	mov    %r9b,0xb(%r8)
 111e49a:	mov    %sil,0xd(%r8)
 111e49e:	mov    -0x30(%rbp),%rsi
 111e4a2:	mov    (%rsi),%r10
 111e4a5:	mov    $0x5,%r14b
 111e4a8:	mov    $0x6,%r12b
 111e4ab:	movzwl 0x4(%r8),%edi
 111e4b0:	movzwl (%r8),%r11d
 111e4b4:	mov    %edi,%esi
 111e4b6:	shl    $0x4,%esi
 111e4b9:	mov    (%r10,%rsi,1),%r9
 111e4bd:	mov    %r11d,%ebx
 111e4c0:	shl    $0x4,%ebx
 111e4c3:	mov    (%r10,%rbx,1),%r15
 111e4c7:	cmp    %r15,%r9
 111e4ca:	mov    %r13,-0x40(%rbp)
 111e4ce:	jne    111e4e5 <sort.block.block__anon_39113+0x9c5>
 111e4d0:	add    %r10,%rsi
 111e4d3:	add    %r10,%rbx
 111e4d6:	movzwl 0xe(%rsi),%esi
 111e4da:	cmp    0xe(%rbx),%si
 111e4de:	jb     111e4e7 <sort.block.block__anon_39113+0x9c7>
 111e4e0:	xor    %r15d,%r15d
 111e4e3:	jmp    111e515 <sort.block.block__anon_39113+0x9f5>
 111e4e5:	jae    111e4e0 <sort.block.block__anon_39113+0x9c0>
 111e4e7:	mov    %r11d,%esi
 111e4ea:	shr    $0x8,%esi
 111e4ed:	mov    %edi,%r9d
 111e4f0:	shr    $0x8,%r9d
 111e4f4:	mov    %dil,(%r8)
 111e4f7:	mov    %r11b,0x4(%r8)
 111e4fb:	mov    %r9b,0x1(%r8)
 111e4ff:	mov    %sil,0x5(%r8)
 111e503:	mov    -0x30(%rbp),%rsi
 111e507:	mov    (%rsi),%r10
 111e50a:	mov    -0x48(%rbp),%r15d
 111e50e:	movl   $0x0,-0x48(%rbp)
 111e515:	movzwl 0xa(%r8),%edi
 111e51a:	movzwl 0x6(%r8),%r11d
 111e51f:	mov    %edi,%esi
 111e521:	shl    $0x4,%esi
 111e524:	mov    (%r10,%rsi,1),%r9
 111e528:	mov    %r11d,%ebx
 111e52b:	shl    $0x4,%ebx
 111e52e:	mov    (%r10,%rbx,1),%r13
 111e532:	cmp    %r13,%r9
 111e535:	jne    111e545 <sort.block.block__anon_39113+0xa25>
 111e537:	add    %r10,%rsi
 111e53a:	add    %r10,%rbx
 111e53d:	movzwl 0xe(%rsi),%esi
 111e541:	cmp    0xe(%rbx),%si
 111e545:	movzbl -0x80(%rbp),%r13d
 111e54a:	jae    111e576 <sort.block.block__anon_39113+0xa56>
 111e54c:	mov    %r11d,%esi
 111e54f:	shr    $0x8,%esi
 111e552:	mov    %edi,%r9d
 111e555:	shr    $0x8,%r9d
 111e559:	mov    %dil,0x6(%r8)
 111e55d:	mov    %r11b,0xa(%r8)
 111e561:	mov    %r9b,0x7(%r8)
 111e565:	mov    %sil,0xb(%r8)
 111e569:	mov    -0x30(%rbp),%rsi
 111e56d:	mov    (%rsi),%r10
 111e570:	mov    %r12b,-0x50(%rbp)
 111e574:	jmp    111e57c <sort.block.block__anon_39113+0xa5c>
 111e576:	mov    %cl,-0x50(%rbp)
 111e579:	mov    %r12d,%ecx
 111e57c:	movzwl 0xc(%r8),%edi
 111e581:	movzwl 0x8(%r8),%ebx
 111e586:	mov    %edi,%esi
 111e588:	shl    $0x4,%esi
 111e58b:	mov    (%r10,%rsi,1),%r9
 111e58f:	mov    %ebx,%r12d
 111e592:	shl    $0x4,%r12d
 111e596:	mov    (%r10,%r12,1),%r11
 111e59a:	cmp    %r11,%r9
 111e59d:	jne    111e5bc <sort.block.block__anon_39113+0xa9c>
 111e59f:	add    %r10,%rsi
 111e5a2:	add    %r10,%r12
 111e5a5:	movzwl 0xe(%rsi),%esi
 111e5a9:	cmp    0xe(%r12),%si
 111e5af:	jb     111e5be <sort.block.block__anon_39113+0xa9e>
 111e5b1:	movzbl -0x58(%rbp),%r12d
 111e5b6:	mov    %r14b,-0x58(%rbp)
 111e5ba:	jmp    111e5e4 <sort.block.block__anon_39113+0xac4>
 111e5bc:	jae    111e5b1 <sort.block.block__anon_39113+0xa91>
 111e5be:	mov    %ebx,%esi
 111e5c0:	shr    $0x8,%esi
 111e5c3:	mov    %edi,%r9d
 111e5c6:	shr    $0x8,%r9d
 111e5ca:	mov    %dil,0x8(%r8)
 111e5ce:	mov    %bl,0xc(%r8)
 111e5d2:	mov    %r9b,0x9(%r8)
 111e5d6:	mov    %sil,0xd(%r8)
 111e5da:	mov    -0x30(%rbp),%rsi
 111e5de:	mov    (%rsi),%r10
 111e5e1:	mov    %r14d,%r12d
 111e5e4:	movzwl 0x2(%r8),%edi
 111e5e9:	movzwl (%r8),%ebx
 111e5ed:	mov    %edi,%esi
 111e5ef:	shl    $0x4,%esi
 111e5f2:	mov    (%r10,%rsi,1),%r14
 111e5f6:	mov    %ebx,%r9d
 111e5f9:	shl    $0x4,%r9d
 111e5fd:	mov    (%r10,%r9,1),%r11
 111e601:	cmp    %r11,%r14
 111e604:	jne    111e62f <sort.block.block__anon_39113+0xb0f>
 111e606:	add    %r10,%rsi
 111e609:	add    %r10,%r9
 111e60c:	movzwl 0xe(%r9),%r9d
 111e611:	movzwl 0xe(%rsi),%esi
 111e615:	cmp    %r9w,%si
 111e619:	jb     111e643 <sort.block.block__anon_39113+0xb23>
 111e61b:	cmp    %r13b,%r15b
 111e61e:	jbe    111f062 <sort.block.block__anon_39113+0x1542>
 111e624:	cmp    %si,%r9w
 111e628:	jae    111e643 <sort.block.block__anon_39113+0xb23>
 111e62a:	jmp    111f062 <sort.block.block__anon_39113+0x1542>
 111e62f:	jb     111e643 <sort.block.block__anon_39113+0xb23>
 111e631:	cmp    %r13b,%r15b
 111e634:	jbe    111f062 <sort.block.block__anon_39113+0x1542>
 111e63a:	cmp    %r14,%r11
 111e63d:	jb     111f062 <sort.block.block__anon_39113+0x1542>
 111e643:	mov    %ebx,%esi
 111e645:	shr    $0x8,%esi
 111e648:	mov    %edi,%r9d
 111e64b:	shr    $0x8,%r9d
 111e64f:	mov    %dil,(%r8)
 111e652:	mov    %bl,0x2(%r8)
 111e656:	mov    %r9b,0x1(%r8)
 111e65a:	mov    %sil,0x3(%r8)
 111e65e:	mov    -0x30(%rbp),%rsi
 111e662:	mov    (%rsi),%r10
 111e665:	mov    %r13d,%r14d
 111e668:	jmp    111f068 <sort.block.block__anon_39113+0x1548>
 111e66d:	jae    111dcc5 <sort.block.block__anon_39113+0x1a5>
 111e673:	mov    %r9d,%ecx
 111e676:	shr    $0x8,%ecx
 111e679:	mov    %edi,%esi
 111e67b:	shr    $0x8,%esi
 111e67e:	mov    %dil,(%r8)
 111e681:	mov    %r9b,0x2(%r8)
 111e685:	mov    %sil,0x1(%r8)
 111e689:	mov    %cl,0x3(%r8)
 111e68d:	mov    -0x30(%rbp),%rcx
 111e691:	mov    (%rcx),%rcx
 111e694:	mov    $0x1,%r14b
 111e697:	movl   $0x0,-0x48(%rbp)
 111e69e:	movzwl 0x6(%r8),%r10d
 111e6a3:	movzwl 0x4(%r8),%r15d
 111e6a8:	mov    %r10d,%r11d
 111e6ab:	shl    $0x4,%r11d
 111e6af:	mov    (%rcx,%r11,1),%rdi
 111e6b3:	mov    %r15d,%esi
 111e6b6:	shl    $0x4,%esi
 111e6b9:	mov    (%rcx,%rsi,1),%rbx
 111e6bd:	mov    %r15d,%r12d
 111e6c0:	shr    $0x8,%r12d
 111e6c4:	cmp    %rbx,%rdi
 111e6c7:	jne    111e766 <sort.block.block__anon_39113+0xc46>
 111e6cd:	add    %rcx,%r11
 111e6d0:	add    %rcx,%rsi
 111e6d3:	movzwl 0xe(%r11),%r11d
 111e6d8:	cmp    0xe(%rsi),%r11w
 111e6dd:	jb     111e76c <sort.block.block__anon_39113+0xc4c>
 111e6e3:	mov    $0x3,%r10b
 111e6e6:	mov    $0x2,%r11b
 111e6e9:	jmp    111f6d2 <sort.block.block__anon_39113+0x1bb2>
 111e6ee:	jae    111de0b <sort.block.block__anon_39113+0x2eb>
 111e6f4:	mov    %edi,%esi
 111e6f6:	shr    $0x8,%esi
 111e6f9:	mov    %ecx,%r9d
 111e6fc:	shr    $0x8,%r9d
 111e700:	mov    %cl,(%r8)
 111e703:	mov    %dil,0x2(%r8)
 111e707:	mov    %r9b,0x1(%r8)
 111e70b:	mov    %sil,0x3(%r8)
 111e70f:	mov    -0x30(%rbp),%rcx
 111e713:	mov    (%rcx),%r10
 111e716:	mov    $0x1,%cl
 111e718:	mov    %ecx,-0x48(%rbp)
 111e71b:	movl   $0x0,-0x50(%rbp)
 111e722:	movzwl 0x8(%r8),%r13d
 111e727:	movzwl 0x6(%r8),%ecx
 111e72c:	mov    %r13d,%r11d
 111e72f:	shl    $0x4,%r11d
 111e733:	mov    (%r10,%r11,1),%rdi
 111e737:	mov    %ecx,%esi
 111e739:	shl    $0x4,%esi
 111e73c:	mov    (%r10,%rsi,1),%rbx
 111e740:	mov    %r13d,%r9d
 111e743:	shr    $0x8,%r9d
 111e747:	cmp    %rbx,%rdi
 111e74a:	jne    111e7aa <sort.block.block__anon_39113+0xc8a>
 111e74c:	add    %r10,%r11
 111e74f:	add    %r10,%rsi
 111e752:	movzwl 0xe(%r11),%r11d
 111e757:	cmp    0xe(%rsi),%r11w
 111e75c:	jb     111e7ac <sort.block.block__anon_39113+0xc8c>
 111e75e:	mov    $0x4,%r14b
 111e761:	mov    $0x3,%r12b
 111e764:	jmp    111e7e4 <sort.block.block__anon_39113+0xcc4>
 111e766:	jae    111f6c9 <sort.block.block__anon_39113+0x1ba9>
 111e76c:	mov    %r10d,%ecx
 111e76f:	shr    $0x8,%ecx
 111e772:	mov    %r10b,0x4(%r8)
 111e776:	mov    %r15b,0x6(%r8)
 111e77a:	mov    %cl,0x5(%r8)
 111e77e:	mov    %r12b,0x7(%r8)
 111e782:	mov    -0x30(%rbp),%rcx
 111e786:	mov    (%rcx),%rcx
 111e789:	movzwl 0x4(%r8),%r15d
 111e78e:	mov    %r15d,%esi
 111e791:	shl    $0x4,%esi
 111e794:	mov    (%rcx,%rsi,1),%rdi
 111e798:	mov    %r15d,%r12d
 111e79b:	shr    $0x8,%r12d
 111e79f:	mov    $0x2,%r10b
 111e7a2:	mov    $0x3,%r11b
 111e7a5:	jmp    111f6d2 <sort.block.block__anon_39113+0x1bb2>
 111e7aa:	jae    111e75e <sort.block.block__anon_39113+0xc3e>
 111e7ac:	mov    %ecx,%esi
 111e7ae:	shr    $0x8,%esi
 111e7b1:	mov    %r13b,0x6(%r8)
 111e7b5:	mov    %cl,0x8(%r8)
 111e7b9:	mov    %r9b,0x7(%r8)
 111e7bd:	mov    %sil,0x9(%r8)
 111e7c1:	mov    -0x30(%rbp),%rcx
 111e7c5:	mov    (%rcx),%r10
 111e7c8:	movzwl 0x8(%r8),%r13d
 111e7cd:	mov    %r13d,%ecx
 111e7d0:	shl    $0x4,%ecx
 111e7d3:	mov    (%r10,%rcx,1),%rdi
 111e7d7:	mov    %r13d,%r9d
 111e7da:	shr    $0x8,%r9d
 111e7de:	mov    $0x3,%r14b
 111e7e1:	mov    $0x4,%r12b
 111e7e4:	movzwl 0x4(%r8),%esi
 111e7e9:	mov    %esi,%ecx
 111e7eb:	shl    $0x4,%ecx
 111e7ee:	mov    (%r10,%rcx,1),%rbx
 111e7f2:	mov    %esi,%r11d
 111e7f5:	shr    $0x8,%r11d
 111e7f9:	cmp    %rbx,%rdi
 111e7fc:	jne    111e81b <sort.block.block__anon_39113+0xcfb>
 111e7fe:	add    %r10,%rcx
 111e801:	mov    %r13d,%ebx
 111e804:	shl    $0x4,%ebx
 111e807:	movzwl 0xe(%r10,%rbx,1),%ebx
 111e80d:	mov    $0x2,%r15b
 111e810:	cmp    0xe(%rcx),%bx
 111e814:	jb     111e820 <sort.block.block__anon_39113+0xd00>
 111e816:	mov    %rdi,%rbx
 111e819:	jmp    111e852 <sort.block.block__anon_39113+0xd32>
 111e81b:	mov    $0x2,%r15b
 111e81e:	jae    111e852 <sort.block.block__anon_39113+0xd32>
 111e820:	mov    %r13b,0x4(%r8)
 111e824:	mov    %sil,0x8(%r8)
 111e828:	mov    %r9b,0x5(%r8)
 111e82c:	mov    %r11b,0x9(%r8)
 111e830:	mov    -0x30(%rbp),%rcx
 111e834:	mov    (%rcx),%r10
 111e837:	movzwl 0x4(%r8),%esi
 111e83c:	mov    %esi,%ecx
 111e83e:	shl    $0x4,%ecx
 111e841:	mov    (%r10,%rcx,1),%rbx
 111e845:	mov    %esi,%r11d
 111e848:	shr    $0x8,%r11d
 111e84c:	mov    %r14d,%r15d
 111e84f:	mov    $0x2,%r14b
 111e852:	mov    -0x40(%rbp),%r13
 111e856:	movzwl 0x6(%r8),%edi
 111e85b:	mov    %edi,%ecx
 111e85d:	shl    $0x4,%ecx
 111e860:	mov    (%r10,%rcx,1),%r9
 111e864:	cmp    %rbx,%r9
 111e867:	jne    111e897 <sort.block.block__anon_39113+0xd77>
 111e869:	add    %r10,%rcx
 111e86c:	mov    %esi,%r9d
 111e86f:	shl    $0x4,%r9d
 111e873:	movzwl 0xe(%r10,%r9,1),%r9d
 111e879:	movzwl 0xe(%rcx),%ecx
 111e87d:	cmp    %r9w,%cx
 111e881:	jb     111e8ab <sort.block.block__anon_39113+0xd8b>
 111e883:	cmp    %r12b,%r15b
 111e886:	jbe    111f481 <sort.block.block__anon_39113+0x1961>
 111e88c:	cmp    %cx,%r9w
 111e890:	jae    111e8ab <sort.block.block__anon_39113+0xd8b>
 111e892:	jmp    111f481 <sort.block.block__anon_39113+0x1961>
 111e897:	jb     111e8ab <sort.block.block__anon_39113+0xd8b>
 111e899:	cmp    %r12b,%r15b
 111e89c:	jbe    111f481 <sort.block.block__anon_39113+0x1961>
 111e8a2:	cmp    %r9,%rbx
 111e8a5:	jb     111f481 <sort.block.block__anon_39113+0x1961>
 111e8ab:	mov    %edi,%ecx
 111e8ad:	shr    $0x8,%ecx
 111e8b0:	mov    %dil,0x4(%r8)
 111e8b4:	mov    %sil,0x6(%r8)
 111e8b8:	mov    %cl,0x5(%r8)
 111e8bc:	mov    %r11b,0x7(%r8)
 111e8c0:	mov    -0x30(%rbp),%rcx
 111e8c4:	mov    (%rcx),%r10
 111e8c7:	mov    %r12d,%ecx
 111e8ca:	jmp    111f487 <sort.block.block__anon_39113+0x1967>
 111e8cf:	mov    %r15d,%r14d
 111e8d2:	mov    %r9d,%r15d
 111e8d5:	movzwl 0xc(%r8),%edi
 111e8da:	movzwl 0xa(%r8),%ebx
 111e8df:	mov    %edi,%esi
 111e8e1:	shl    $0x4,%esi
 111e8e4:	mov    (%r10,%rsi,1),%r13
 111e8e8:	mov    %ebx,%r9d
 111e8eb:	shl    $0x4,%r9d
 111e8ef:	mov    (%r10,%r9,1),%rcx
 111e8f3:	cmp    %rcx,%r13
 111e8f6:	jne    111e918 <sort.block.block__anon_39113+0xdf8>
 111e8f8:	add    %r10,%rsi
 111e8fb:	add    %r10,%r9
 111e8fe:	movzwl 0xe(%r9),%ecx
 111e903:	movzwl 0xe(%rsi),%esi
 111e907:	cmp    %cx,%si
 111e90a:	jb     111e924 <sort.block.block__anon_39113+0xe04>
 111e90c:	cmp    %r11b,%r12b
 111e90f:	jbe    111e94a <sort.block.block__anon_39113+0xe2a>
 111e911:	cmp    %si,%cx
 111e914:	jae    111e924 <sort.block.block__anon_39113+0xe04>
 111e916:	jmp    111e94a <sort.block.block__anon_39113+0xe2a>
 111e918:	jb     111e924 <sort.block.block__anon_39113+0xe04>
 111e91a:	cmp    %r11b,%r12b
 111e91d:	jbe    111e94a <sort.block.block__anon_39113+0xe2a>
 111e91f:	cmp    %r13,%rcx
 111e922:	jb     111e94a <sort.block.block__anon_39113+0xe2a>
 111e924:	mov    %ebx,%ecx
 111e926:	shr    $0x8,%ecx
 111e929:	mov    %edi,%esi
 111e92b:	shr    $0x8,%esi
 111e92e:	mov    %dil,0xa(%r8)
 111e932:	mov    %bl,0xc(%r8)
 111e936:	mov    %sil,0xb(%r8)
 111e93a:	mov    %cl,0xd(%r8)
 111e93e:	mov    -0x30(%rbp),%rcx
 111e942:	mov    (%rcx),%r10
 111e945:	mov    %r11d,%r13d
 111e948:	jmp    111e950 <sort.block.block__anon_39113+0xe30>
 111e94a:	mov    %r12d,%r13d
 111e94d:	mov    %r11d,%r12d
 111e950:	movzwl 0x8(%r8),%edi
 111e955:	movzwl (%r8),%r11d
 111e959:	mov    %edi,%esi
 111e95b:	shl    $0x4,%esi
 111e95e:	mov    (%r10,%rsi,1),%rcx
 111e962:	mov    %r11d,%r9d
 111e965:	shl    $0x4,%r9d
 111e969:	mov    (%r10,%r9,1),%rbx
 111e96d:	cmp    %rbx,%rcx
 111e970:	jne    111e981 <sort.block.block__anon_39113+0xe61>
 111e972:	add    %r10,%rsi
 111e975:	add    %r10,%r9
 111e978:	movzwl 0xe(%rsi),%ecx
 111e97c:	cmp    0xe(%r9),%cx
 111e981:	jae    111e9ae <sort.block.block__anon_39113+0xe8e>
 111e983:	mov    %r11d,%ecx
 111e986:	shr    $0x8,%ecx
 111e989:	mov    %edi,%esi
 111e98b:	shr    $0x8,%esi
 111e98e:	mov    %dil,(%r8)
 111e991:	mov    %r11b,0x8(%r8)
 111e995:	mov    %sil,0x1(%r8)
 111e999:	mov    %cl,0x9(%r8)
 111e99d:	mov    -0x30(%rbp),%rcx
 111e9a1:	mov    (%rcx),%r10
 111e9a4:	movzbl -0xc8(%rbp),%ecx
 111e9ab:	mov    %cl,-0x50(%rbp)
 111e9ae:	movzwl 0xe(%r8),%edi
 111e9b3:	movzwl 0x6(%r8),%r11d
 111e9b8:	mov    %edi,%esi
 111e9ba:	shl    $0x4,%esi
 111e9bd:	mov    (%r10,%rsi,1),%rcx
 111e9c1:	mov    %r11d,%r9d
 111e9c4:	shl    $0x4,%r9d
 111e9c8:	mov    (%r10,%r9,1),%rbx
 111e9cc:	cmp    %rbx,%rcx
 111e9cf:	jne    111e9e0 <sort.block.block__anon_39113+0xec0>
 111e9d1:	add    %r10,%rsi
 111e9d4:	add    %r10,%r9
 111e9d7:	movzwl 0xe(%rsi),%ecx
 111e9db:	cmp    0xe(%r9),%cx
 111e9e0:	jae    111ea0b <sort.block.block__anon_39113+0xeeb>
 111e9e2:	mov    %r11d,%ecx
 111e9e5:	shr    $0x8,%ecx
 111e9e8:	mov    %edi,%esi
 111e9ea:	shr    $0x8,%esi
 111e9ed:	mov    %dil,0x6(%r8)
 111e9f1:	mov    %r11b,0xe(%r8)
 111e9f5:	mov    %sil,0x7(%r8)
 111e9f9:	mov    %cl,0xf(%r8)
 111e9fd:	mov    -0x30(%rbp),%rcx
 111ea01:	mov    (%rcx),%r10
 111ea04:	movzbl -0x80(%rbp),%ecx
 111ea08:	mov    %ecx,-0x48(%rbp)
 111ea0b:	movzwl 0xa(%r8),%edi
 111ea10:	movzwl 0x2(%r8),%r9d
 111ea15:	mov    %edi,%esi
 111ea17:	shl    $0x4,%esi
 111ea1a:	mov    (%r10,%rsi,1),%rcx
 111ea1e:	mov    %r9d,%r11d
 111ea21:	shl    $0x4,%r11d
 111ea25:	mov    (%r10,%r11,1),%rbx
 111ea29:	cmp    %rbx,%rcx
 111ea2c:	jne    111ea47 <sort.block.block__anon_39113+0xf27>
 111ea2e:	add    %r10,%rsi
 111ea31:	add    %r10,%r11
 111ea34:	movzwl 0xe(%rsi),%ecx
 111ea38:	cmp    0xe(%r11),%cx
 111ea3d:	jb     111ea49 <sort.block.block__anon_39113+0xf29>
 111ea3f:	mov    %r14d,%r11d
 111ea42:	mov    %r13d,%r14d
 111ea45:	jmp    111ea6e <sort.block.block__anon_39113+0xf4e>
 111ea47:	jae    111ea3f <sort.block.block__anon_39113+0xf1f>
 111ea49:	mov    %r9d,%ecx
 111ea4c:	shr    $0x8,%ecx
 111ea4f:	mov    %edi,%esi
 111ea51:	shr    $0x8,%esi
 111ea54:	mov    %dil,0x2(%r8)
 111ea58:	mov    %r9b,0xa(%r8)
 111ea5c:	mov    %sil,0x3(%r8)
 111ea60:	mov    %cl,0xb(%r8)
 111ea64:	mov    -0x30(%rbp),%rcx
 111ea68:	mov    (%rcx),%r10
 111ea6b:	mov    %r13d,%r11d
 111ea6e:	movzwl 0xc(%r8),%edi
 111ea73:	movzwl 0x4(%r8),%r9d
 111ea78:	mov    %edi,%esi
 111ea7a:	shl    $0x4,%esi
 111ea7d:	mov    (%r10,%rsi,1),%rcx
 111ea81:	mov    %r9d,%ebx
 111ea84:	shl    $0x4,%ebx
 111ea87:	mov    (%r10,%rbx,1),%r13
 111ea8b:	cmp    %r13,%rcx
 111ea8e:	jne    111eaa8 <sort.block.block__anon_39113+0xf88>
 111ea90:	add    %r10,%rsi
 111ea93:	add    %r10,%rbx
 111ea96:	movzwl 0xe(%rsi),%ecx
 111ea9a:	cmp    0xe(%rbx),%cx
 111ea9e:	jb     111eaaa <sort.block.block__anon_39113+0xf8a>
 111eaa0:	mov    %r15d,%r9d
 111eaa3:	mov    %r12d,%r15d
 111eaa6:	jmp    111eacf <sort.block.block__anon_39113+0xfaf>
 111eaa8:	jae    111eaa0 <sort.block.block__anon_39113+0xf80>
 111eaaa:	mov    %r9d,%ecx
 111eaad:	shr    $0x8,%ecx
 111eab0:	mov    %edi,%esi
 111eab2:	shr    $0x8,%esi
 111eab5:	mov    %dil,0x4(%r8)
 111eab9:	mov    %r9b,0xc(%r8)
 111eabd:	mov    %sil,0x5(%r8)
 111eac1:	mov    %cl,0xd(%r8)
 111eac5:	mov    -0x30(%rbp),%rcx
 111eac9:	mov    (%rcx),%r10
 111eacc:	mov    %r12d,%r9d
 111eacf:	movzwl 0x8(%r8),%edi
 111ead4:	movzwl 0x2(%r8),%ebx
 111ead9:	mov    %edi,%esi
 111eadb:	shl    $0x4,%esi
 111eade:	mov    (%r10,%rsi,1),%r12
 111eae2:	mov    %ebx,%r13d
 111eae5:	shl    $0x4,%r13d
 111eae9:	mov    (%r10,%r13,1),%rcx
 111eaed:	cmp    %rcx,%r12
 111eaf0:	jne    111eb17 <sort.block.block__anon_39113+0xff7>
 111eaf2:	add    %r10,%rsi
 111eaf5:	add    %r10,%r13
 111eaf8:	movzwl 0xe(%r13),%ecx
 111eafd:	movzwl 0xe(%rsi),%esi
 111eb01:	cmp    %cx,%si
 111eb04:	mov    -0x40(%rbp),%r13
 111eb08:	jb     111eb28 <sort.block.block__anon_39113+0x1008>
 111eb0a:	cmp    -0x50(%rbp),%r11b
 111eb0e:	jbe    111eb4d <sort.block.block__anon_39113+0x102d>
 111eb10:	cmp    %si,%cx
 111eb13:	jae    111eb28 <sort.block.block__anon_39113+0x1008>
 111eb15:	jmp    111eb4d <sort.block.block__anon_39113+0x102d>
 111eb17:	mov    -0x40(%rbp),%r13
 111eb1b:	jb     111eb28 <sort.block.block__anon_39113+0x1008>
 111eb1d:	cmp    -0x50(%rbp),%r11b
 111eb21:	jbe    111eb4d <sort.block.block__anon_39113+0x102d>
 111eb23:	cmp    %r12,%rcx
 111eb26:	jb     111eb4d <sort.block.block__anon_39113+0x102d>
 111eb28:	mov    %ebx,%ecx
 111eb2a:	shr    $0x8,%ecx
 111eb2d:	mov    %edi,%esi
 111eb2f:	shr    $0x8,%esi
 111eb32:	mov    %dil,0x2(%r8)
 111eb36:	mov    %bl,0x8(%r8)
 111eb3a:	mov    %sil,0x3(%r8)
 111eb3e:	mov    %cl,0x9(%r8)
 111eb42:	mov    -0x30(%rbp),%rcx
 111eb46:	mov    (%rcx),%r10
 111eb49:	mov    %r11b,-0x50(%rbp)
 111eb4d:	movzwl 0xc(%r8),%edi
 111eb52:	movzwl 0x6(%r8),%r11d
 111eb57:	mov    %edi,%esi
 111eb59:	shl    $0x4,%esi
 111eb5c:	mov    (%r10,%rsi,1),%rbx
 111eb60:	mov    %r11d,%r12d
 111eb63:	shl    $0x4,%r12d
 111eb67:	mov    (%r10,%r12,1),%rcx
 111eb6b:	cmp    %rcx,%rbx
 111eb6e:	jne    111eb92 <sort.block.block__anon_39113+0x1072>
 111eb70:	add    %r10,%rsi
 111eb73:	add    %r10,%r12
 111eb76:	movzwl 0xe(%r12),%ecx
 111eb7c:	movzwl 0xe(%rsi),%esi
 111eb80:	cmp    %cx,%si
 111eb83:	jb     111eb9f <sort.block.block__anon_39113+0x107f>
 111eb85:	cmp    %r15b,-0x48(%rbp)
 111eb89:	jbe    111ebc7 <sort.block.block__anon_39113+0x10a7>
 111eb8b:	cmp    %si,%cx
 111eb8e:	jae    111eb9f <sort.block.block__anon_39113+0x107f>
 111eb90:	jmp    111ebc7 <sort.block.block__anon_39113+0x10a7>
 111eb92:	jb     111eb9f <sort.block.block__anon_39113+0x107f>
 111eb94:	cmp    %r15b,-0x48(%rbp)
 111eb98:	jbe    111ebc7 <sort.block.block__anon_39113+0x10a7>
 111eb9a:	cmp    %rbx,%rcx
 111eb9d:	jb     111ebc7 <sort.block.block__anon_39113+0x10a7>
 111eb9f:	mov    %r11d,%ecx
 111eba2:	shr    $0x8,%ecx
 111eba5:	mov    %edi,%esi
 111eba7:	shr    $0x8,%esi
 111ebaa:	mov    %dil,0x6(%r8)
 111ebae:	mov    %r11b,0xc(%r8)
 111ebb2:	mov    %sil,0x7(%r8)
 111ebb6:	mov    %cl,0xd(%r8)
 111ebba:	mov    -0x30(%rbp),%rcx
 111ebbe:	mov    (%rcx),%r10
 111ebc1:	mov    %r15d,%ecx
 111ebc4:	mov    %ecx,-0x48(%rbp)
 111ebc7:	movzwl 0x8(%r8),%edi
 111ebcc:	movzwl 0x4(%r8),%r11d
 111ebd1:	mov    %edi,%esi
 111ebd3:	shl    $0x4,%esi
 111ebd6:	mov    (%r10,%rsi,1),%rbx
 111ebda:	mov    %r11d,%r15d
 111ebdd:	shl    $0x4,%r15d
 111ebe1:	mov    (%r10,%r15,1),%rcx
 111ebe5:	cmp    %rcx,%rbx
 111ebe8:	jne    111ec0b <sort.block.block__anon_39113+0x10eb>
 111ebea:	add    %r10,%rsi
 111ebed:	add    %r10,%r15
 111ebf0:	movzwl 0xe(%r15),%ecx
 111ebf5:	movzwl 0xe(%rsi),%esi
 111ebf9:	cmp    %cx,%si
 111ebfc:	jb     111ec18 <sort.block.block__anon_39113+0x10f8>
 111ebfe:	cmp    -0x50(%rbp),%r9b
 111ec02:	jbe    111ec3e <sort.block.block__anon_39113+0x111e>
 111ec04:	cmp    %si,%cx
 111ec07:	jae    111ec18 <sort.block.block__anon_39113+0x10f8>
 111ec09:	jmp    111ec3e <sort.block.block__anon_39113+0x111e>
 111ec0b:	jb     111ec18 <sort.block.block__anon_39113+0x10f8>
 111ec0d:	cmp    -0x50(%rbp),%r9b
 111ec11:	jbe    111ec3e <sort.block.block__anon_39113+0x111e>
 111ec13:	cmp    %rbx,%rcx
 111ec16:	jb     111ec3e <sort.block.block__anon_39113+0x111e>
 111ec18:	mov    %r11d,%ecx
 111ec1b:	shr    $0x8,%ecx
 111ec1e:	mov    %edi,%esi
 111ec20:	shr    $0x8,%esi
 111ec23:	mov    %dil,0x4(%r8)
 111ec27:	mov    %r11b,0x8(%r8)
 111ec2b:	mov    %sil,0x5(%r8)
 111ec2f:	mov    %cl,0x9(%r8)
 111ec33:	mov    -0x30(%rbp),%rcx
 111ec37:	mov    (%rcx),%r10
 111ec3a:	mov    %r9b,-0x50(%rbp)
 111ec3e:	movzwl 0xa(%r8),%r11d
 111ec43:	movzwl 0x6(%r8),%r9d
 111ec48:	mov    %r11d,%r12d
 111ec4b:	shl    $0x4,%r12d
 111ec4f:	mov    (%r10,%r12,1),%rbx
 111ec53:	mov    %r9d,%esi
 111ec56:	shl    $0x4,%esi
 111ec59:	mov    (%r10,%rsi,1),%rdi
 111ec5d:	mov    %r9d,%r15d
 111ec60:	shr    $0x8,%r15d
 111ec64:	cmp    %rdi,%rbx
 111ec67:	jne    111ec8e <sort.block.block__anon_39113+0x116e>
 111ec69:	add    %r10,%r12
 111ec6c:	add    %r10,%rsi
 111ec6f:	movzwl 0xe(%rsi),%ecx
 111ec73:	movzwl 0xe(%r12),%esi
 111ec79:	cmp    %cx,%si
 111ec7c:	jb     111ec9b <sort.block.block__anon_39113+0x117b>
 111ec7e:	cmp    %r14b,-0x48(%rbp)
 111ec82:	jbe    111ec89 <sort.block.block__anon_39113+0x1169>
 111ec84:	cmp    %si,%cx
 111ec87:	jae    111ec9b <sort.block.block__anon_39113+0x117b>
 111ec89:	mov    %rbx,%rdi
 111ec8c:	jmp    111ecd0 <sort.block.block__anon_39113+0x11b0>
 111ec8e:	jb     111ec9b <sort.block.block__anon_39113+0x117b>
 111ec90:	cmp    %r14b,-0x48(%rbp)
 111ec94:	jbe    111ecd0 <sort.block.block__anon_39113+0x11b0>
 111ec96:	cmp    %rbx,%rdi
 111ec99:	jb     111ecd0 <sort.block.block__anon_39113+0x11b0>
 111ec9b:	mov    %r11d,%ecx
 111ec9e:	shr    $0x8,%ecx
 111eca1:	mov    %r11b,0x6(%r8)
 111eca5:	mov    %r9b,0xa(%r8)
 111eca9:	mov    %cl,0x7(%r8)
 111ecad:	mov    %r15b,0xb(%r8)
 111ecb1:	mov    -0x30(%rbp),%rcx
 111ecb5:	mov    (%rcx),%r10
 111ecb8:	movzwl 0x6(%r8),%r9d
 111ecbd:	mov    %r9d,%ecx
 111ecc0:	shl    $0x4,%ecx
 111ecc3:	mov    (%r10,%rcx,1),%rdi
 111ecc7:	mov    %r9d,%r15d
 111ecca:	shr    $0x8,%r15d
 111ecce:	jmp    111ecd6 <sort.block.block__anon_39113+0x11b6>
 111ecd0:	mov    -0x48(%rbp),%ecx
 111ecd3:	mov    %ecx,%r14d
 111ecd6:	movzwl 0x8(%r8),%r11d
 111ecdb:	mov    %r11d,%esi
 111ecde:	shl    $0x4,%esi
 111ece1:	mov    (%r10,%rsi,1),%rbx
 111ece5:	cmp    %rdi,%rbx
 111ece8:	jne    111ed16 <sort.block.block__anon_39113+0x11f6>
 111ecea:	add    %r10,%rsi
 111eced:	mov    %r9d,%ecx
 111ecf0:	shl    $0x4,%ecx
 111ecf3:	movzwl 0xe(%r10,%rcx,1),%ecx
 111ecf9:	movzwl 0xe(%rsi),%esi
 111ecfd:	cmp    %cx,%si
 111ed00:	jb     111ed2b <sort.block.block__anon_39113+0x120b>
 111ed02:	cmp    -0x50(%rbp),%r14b
 111ed06:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111ed0c:	cmp    %si,%cx
 111ed0f:	jae    111ed2b <sort.block.block__anon_39113+0x120b>
 111ed11:	jmp    111dc11 <sort.block.block__anon_39113+0xf1>
 111ed16:	jb     111ed2b <sort.block.block__anon_39113+0x120b>
 111ed18:	cmp    -0x50(%rbp),%r14b
 111ed1c:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111ed22:	cmp    %rbx,%rdi
 111ed25:	jb     111dc11 <sort.block.block__anon_39113+0xf1>
 111ed2b:	mov    %r11d,%ecx
 111ed2e:	shr    $0x8,%ecx
 111ed31:	mov    %r11b,0x6(%r8)
 111ed35:	mov    %r9b,0x8(%r8)
 111ed39:	mov    $0x9,%edi
 111ed3e:	mov    $0x7,%r9d
 111ed44:	jmp    111dc09 <sort.block.block__anon_39113+0xe9>
 111ed49:	mov    %r11d,%r13d
 111ed4c:	mov    %r15d,%r11d
 111ed4f:	movzwl 0x8(%r8),%edi
 111ed54:	movzwl 0x6(%r8),%ebx
 111ed59:	mov    %edi,%esi
 111ed5b:	shl    $0x4,%esi
 111ed5e:	mov    (%r10,%rsi,1),%r15
 111ed62:	mov    %ebx,%r9d
 111ed65:	shl    $0x4,%r9d
 111ed69:	mov    (%r10,%r9,1),%rcx
 111ed6d:	cmp    %rcx,%r15
 111ed70:	jne    111ed92 <sort.block.block__anon_39113+0x1272>
 111ed72:	add    %r10,%rsi
 111ed75:	add    %r10,%r9
 111ed78:	movzwl 0xe(%r9),%ecx
 111ed7d:	movzwl 0xe(%rsi),%esi
 111ed81:	cmp    %cx,%si
 111ed84:	jb     111ed9e <sort.block.block__anon_39113+0x127e>
 111ed86:	cmp    %r12b,%r14b
 111ed89:	jbe    111edc5 <sort.block.block__anon_39113+0x12a5>
 111ed8b:	cmp    %si,%cx
 111ed8e:	jae    111ed9e <sort.block.block__anon_39113+0x127e>
 111ed90:	jmp    111edc5 <sort.block.block__anon_39113+0x12a5>
 111ed92:	jb     111ed9e <sort.block.block__anon_39113+0x127e>
 111ed94:	cmp    %r12b,%r14b
 111ed97:	jbe    111edc5 <sort.block.block__anon_39113+0x12a5>
 111ed99:	cmp    %r15,%rcx
 111ed9c:	jb     111edc5 <sort.block.block__anon_39113+0x12a5>
 111ed9e:	mov    %ebx,%ecx
 111eda0:	shr    $0x8,%ecx
 111eda3:	mov    %edi,%esi
 111eda5:	shr    $0x8,%esi
 111eda8:	mov    %dil,0x6(%r8)
 111edac:	mov    %bl,0x8(%r8)
 111edb0:	mov    %sil,0x7(%r8)
 111edb4:	mov    %cl,0x9(%r8)
 111edb8:	mov    -0x30(%rbp),%rcx
 111edbc:	mov    (%rcx),%r10
 111edbf:	mov    %r12b,-0x58(%rbp)
 111edc3:	jmp    111edcc <sort.block.block__anon_39113+0x12ac>
 111edc5:	mov    %r14b,-0x58(%rbp)
 111edc9:	mov    %r12d,%r14d
 111edcc:	movzwl 0xa(%r8),%edi
 111edd1:	movzwl 0x4(%r8),%ebx
 111edd6:	mov    %edi,%esi
 111edd8:	shl    $0x4,%esi
 111eddb:	mov    (%r10,%rsi,1),%rcx
 111eddf:	mov    %ebx,%r12d
 111ede2:	shl    $0x4,%r12d
 111ede6:	mov    (%r10,%r12,1),%r9
 111edea:	cmp    %r9,%rcx
 111eded:	jne    111edff <sort.block.block__anon_39113+0x12df>
 111edef:	add    %r10,%rsi
 111edf2:	add    %r10,%r12
 111edf5:	movzwl 0xe(%rsi),%ecx
 111edf9:	cmp    0xe(%r12),%cx
 111edff:	jae    111ee29 <sort.block.block__anon_39113+0x1309>
 111ee01:	mov    %ebx,%ecx
 111ee03:	shr    $0x8,%ecx
 111ee06:	mov    %edi,%esi
 111ee08:	shr    $0x8,%esi
 111ee0b:	mov    %dil,0x4(%r8)
 111ee0f:	mov    %bl,0xa(%r8)
 111ee13:	mov    %sil,0x5(%r8)
 111ee17:	mov    %cl,0xb(%r8)
 111ee1b:	mov    -0x30(%rbp),%rcx
 111ee1f:	mov    (%rcx),%r10
 111ee22:	movzbl -0x50(%rbp),%ecx
 111ee26:	mov    %ecx,-0x48(%rbp)
 111ee29:	movzwl 0x6(%r8),%ecx
 111ee2e:	movzwl (%r8),%edi
 111ee32:	mov    %ecx,%esi
 111ee34:	shl    $0x4,%esi
 111ee37:	mov    (%r10,%rsi,1),%r9
 111ee3b:	mov    %edi,%ebx
 111ee3d:	shl    $0x4,%ebx
 111ee40:	mov    (%r10,%rbx,1),%r12
 111ee44:	cmp    %r12,%r9
 111ee47:	jne    111ee57 <sort.block.block__anon_39113+0x1337>
 111ee49:	add    %r10,%rsi
 111ee4c:	add    %r10,%rbx
 111ee4f:	movzwl 0xe(%rsi),%esi
 111ee53:	cmp    0xe(%rbx),%si
 111ee57:	jae    111ee7f <sort.block.block__anon_39113+0x135f>
 111ee59:	mov    %edi,%esi
 111ee5b:	shr    $0x8,%esi
 111ee5e:	mov    %ecx,%r9d
 111ee61:	shr    $0x8,%r9d
 111ee65:	mov    %cl,(%r8)
 111ee68:	mov    %dil,0x6(%r8)
 111ee6c:	mov    %r9b,0x1(%r8)
 111ee70:	mov    %sil,0x7(%r8)
 111ee74:	mov    -0x30(%rbp),%rcx
 111ee78:	mov    (%rcx),%r10
 111ee7b:	mov    %r13b,-0x58(%rbp)
 111ee7f:	movzwl 0x8(%r8),%ecx
 111ee84:	movzwl 0x2(%r8),%ebx
 111ee89:	mov    %ecx,%r12d
 111ee8c:	shl    $0x4,%r12d
 111ee90:	mov    (%r10,%r12,1),%rdi
 111ee94:	mov    %ebx,%esi
 111ee96:	shl    $0x4,%esi
 111ee99:	mov    (%r10,%rsi,1),%r9
 111ee9d:	mov    %ecx,%r13d
 111eea0:	shr    $0x8,%r13d
 111eea4:	cmp    %r9,%rdi
 111eea7:	jne    111eec4 <sort.block.block__anon_39113+0x13a4>
 111eea9:	add    %r10,%r12
 111eeac:	add    %r10,%rsi
 111eeaf:	movzwl 0xe(%r12),%r9d
 111eeb5:	cmp    0xe(%rsi),%r9w
 111eeba:	jb     111eec6 <sort.block.block__anon_39113+0x13a6>
 111eebc:	mov    %r11d,%r12d
 111eebf:	mov    %r14d,%r11d
 111eec2:	jmp    111eefa <sort.block.block__anon_39113+0x13da>
 111eec4:	jae    111eebc <sort.block.block__anon_39113+0x139c>
 111eec6:	mov    %ebx,%esi
 111eec8:	shr    $0x8,%esi
 111eecb:	mov    %cl,0x2(%r8)
 111eecf:	mov    %bl,0x8(%r8)
 111eed3:	mov    %r13b,0x3(%r8)
 111eed7:	mov    %sil,0x9(%r8)
 111eedb:	mov    -0x30(%rbp),%rcx
 111eedf:	mov    (%rcx),%r10
 111eee2:	movzwl 0x8(%r8),%ecx
 111eee7:	mov    %ecx,%esi
 111eee9:	shl    $0x4,%esi
 111eeec:	mov    (%r10,%rsi,1),%rdi
 111eef0:	mov    %ecx,%r13d
 111eef3:	shr    $0x8,%r13d
 111eef7:	mov    %r14d,%r12d
 111eefa:	movzwl 0x4(%r8),%ebx
 111eeff:	mov    %ebx,%r9d
 111ef02:	shl    $0x4,%r9d
 111ef06:	mov    (%r10,%r9,1),%rsi
 111ef0a:	cmp    %rsi,%rdi
 111ef0d:	mov    -0x48(%rbp),%r15d
 111ef11:	jne    111ef37 <sort.block.block__anon_39113+0x1417>
 111ef13:	add    %r10,%r9
 111ef16:	movzwl 0xe(%r9),%esi
 111ef1b:	mov    %ecx,%edi
 111ef1d:	shl    $0x4,%edi
 111ef20:	movzwl 0xe(%r10,%rdi,1),%edi
 111ef26:	cmp    %si,%di
 111ef29:	jb     111ef43 <sort.block.block__anon_39113+0x1423>
 111ef2b:	cmp    %r11b,%r15b
 111ef2e:	jbe    111ef62 <sort.block.block__anon_39113+0x1442>
 111ef30:	cmp    %di,%si
 111ef33:	jae    111ef43 <sort.block.block__anon_39113+0x1423>
 111ef35:	jmp    111ef62 <sort.block.block__anon_39113+0x1442>
 111ef37:	jb     111ef43 <sort.block.block__anon_39113+0x1423>
 111ef39:	cmp    %r11b,%r15b
 111ef3c:	jbe    111ef62 <sort.block.block__anon_39113+0x1442>
 111ef3e:	cmp    %rdi,%rsi
 111ef41:	jb     111ef62 <sort.block.block__anon_39113+0x1442>
 111ef43:	mov    %ebx,%esi
 111ef45:	shr    $0x8,%esi
 111ef48:	mov    %cl,0x4(%r8)
 111ef4c:	mov    %bl,0x8(%r8)
 111ef50:	mov    %r13b,0x5(%r8)
 111ef54:	mov    %sil,0x9(%r8)
 111ef58:	mov    -0x30(%rbp),%rcx
 111ef5c:	mov    (%rcx),%r10
 111ef5f:	mov    %r11d,%r15d
 111ef62:	movzwl 0x6(%r8),%r11d
 111ef67:	movzwl 0x2(%r8),%edi
 111ef6c:	mov    %r11d,%ebx
 111ef6f:	shl    $0x4,%ebx
 111ef72:	mov    (%r10,%rbx,1),%r14
 111ef76:	mov    %edi,%esi
 111ef78:	shl    $0x4,%esi
 111ef7b:	mov    (%r10,%rsi,1),%r13
 111ef7f:	mov    %r11d,%ecx
 111ef82:	shr    $0x8,%ecx
 111ef85:	cmp    %r13,%r14
 111ef88:	jne    111efad <sort.block.block__anon_39113+0x148d>
 111ef8a:	add    %r10,%rbx
 111ef8d:	add    %r10,%rsi
 111ef90:	movzwl 0xe(%rsi),%esi
 111ef94:	movzwl 0xe(%rbx),%r9d
 111ef99:	cmp    %si,%r9w
 111ef9d:	jb     111efba <sort.block.block__anon_39113+0x149a>
 111ef9f:	cmp    -0x58(%rbp),%r12b
 111efa3:	jbe    111efed <sort.block.block__anon_39113+0x14cd>
 111efa5:	cmp    %r9w,%si
 111efa9:	jae    111efba <sort.block.block__anon_39113+0x149a>
 111efab:	jmp    111efed <sort.block.block__anon_39113+0x14cd>
 111efad:	jb     111efba <sort.block.block__anon_39113+0x149a>
 111efaf:	cmp    -0x58(%rbp),%r12b
 111efb3:	jbe    111efed <sort.block.block__anon_39113+0x14cd>
 111efb5:	cmp    %r14,%r13
 111efb8:	jb     111efed <sort.block.block__anon_39113+0x14cd>
 111efba:	mov    %edi,%esi
 111efbc:	shr    $0x8,%esi
 111efbf:	mov    %r11b,0x2(%r8)
 111efc3:	mov    %dil,0x6(%r8)
 111efc7:	mov    %cl,0x3(%r8)
 111efcb:	mov    %sil,0x7(%r8)
 111efcf:	mov    -0x30(%rbp),%rcx
 111efd3:	mov    (%rcx),%r10
 111efd6:	movzwl 0x6(%r8),%r11d
 111efdb:	mov    %r11d,%ecx
 111efde:	shl    $0x4,%ecx
 111efe1:	mov    (%r10,%rcx,1),%r14
 111efe5:	mov    %r11d,%ecx
 111efe8:	shr    $0x8,%ecx
 111efeb:	jmp    111eff2 <sort.block.block__anon_39113+0x14d2>
 111efed:	movzbl -0x58(%rbp),%r12d
 111eff2:	movzwl 0x4(%r8),%edi
 111eff7:	mov    %edi,%r9d
 111effa:	shl    $0x4,%r9d
 111effe:	mov    (%r10,%r9,1),%rsi
 111f002:	cmp    %rsi,%r14
 111f005:	mov    -0x40(%rbp),%r13
 111f009:	jne    111f03a <sort.block.block__anon_39113+0x151a>
 111f00b:	add    %r10,%r9
 111f00e:	movzwl 0xe(%r9),%esi
 111f013:	mov    %r11d,%r9d
 111f016:	shl    $0x4,%r9d
 111f01a:	movzwl 0xe(%r10,%r9,1),%r9d
 111f020:	cmp    %si,%r9w
 111f024:	jb     111f04e <sort.block.block__anon_39113+0x152e>
 111f026:	cmp    %r12b,%r15b
 111f029:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f02f:	cmp    %r9w,%si
 111f033:	jae    111f04e <sort.block.block__anon_39113+0x152e>
 111f035:	jmp    111dc11 <sort.block.block__anon_39113+0xf1>
 111f03a:	jb     111f04e <sort.block.block__anon_39113+0x152e>
 111f03c:	cmp    %r12b,%r15b
 111f03f:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f045:	cmp    %r14,%rsi
 111f048:	jb     111dc11 <sort.block.block__anon_39113+0xf1>
 111f04e:	mov    %edi,%r15d
 111f051:	shr    $0x8,%r15d
 111f055:	mov    %r11b,0x4(%r8)
 111f059:	mov    %dil,0x6(%r8)
 111f05d:	jmp    111f471 <sort.block.block__anon_39113+0x1951>
 111f062:	mov    %r15d,%r14d
 111f065:	mov    %r13d,%r15d
 111f068:	movzwl 0xa(%r8),%edi
 111f06d:	movzwl 0x8(%r8),%ebx
 111f072:	mov    %edi,%esi
 111f074:	shl    $0x4,%esi
 111f077:	mov    (%r10,%rsi,1),%r13
 111f07b:	mov    %ebx,%r9d
 111f07e:	shl    $0x4,%r9d
 111f082:	mov    (%r10,%r9,1),%r11
 111f086:	cmp    %r11,%r13
 111f089:	jne    111f0ad <sort.block.block__anon_39113+0x158d>
 111f08b:	add    %r10,%rsi
 111f08e:	add    %r10,%r9
 111f091:	movzwl 0xe(%r9),%r9d
 111f096:	movzwl 0xe(%rsi),%esi
 111f09a:	cmp    %r9w,%si
 111f09e:	jb     111f0b9 <sort.block.block__anon_39113+0x1599>
 111f0a0:	cmp    %cl,%r12b
 111f0a3:	jbe    111f0e1 <sort.block.block__anon_39113+0x15c1>
 111f0a5:	cmp    %si,%r9w
 111f0a9:	jae    111f0b9 <sort.block.block__anon_39113+0x1599>
 111f0ab:	jmp    111f0e1 <sort.block.block__anon_39113+0x15c1>
 111f0ad:	jb     111f0b9 <sort.block.block__anon_39113+0x1599>
 111f0af:	cmp    %cl,%r12b
 111f0b2:	jbe    111f0e1 <sort.block.block__anon_39113+0x15c1>
 111f0b4:	cmp    %r13,%r11
 111f0b7:	jb     111f0e1 <sort.block.block__anon_39113+0x15c1>
 111f0b9:	mov    %ebx,%esi
 111f0bb:	shr    $0x8,%esi
 111f0be:	mov    %edi,%r9d
 111f0c1:	shr    $0x8,%r9d
 111f0c5:	mov    %dil,0x8(%r8)
 111f0c9:	mov    %bl,0xa(%r8)
 111f0cd:	mov    %r9b,0x9(%r8)
 111f0d1:	mov    %sil,0xb(%r8)
 111f0d5:	mov    -0x30(%rbp),%rsi
 111f0d9:	mov    (%rsi),%r10
 111f0dc:	mov    %ecx,%r13d
 111f0df:	jmp    111f0e7 <sort.block.block__anon_39113+0x15c7>
 111f0e1:	mov    %r12d,%r13d
 111f0e4:	mov    %ecx,%r12d
 111f0e7:	movzwl 0xc(%r8),%ecx
 111f0ec:	movzwl 0x4(%r8),%edi
 111f0f1:	mov    %ecx,%esi
 111f0f3:	shl    $0x4,%esi
 111f0f6:	mov    (%r10,%rsi,1),%r9
 111f0fa:	mov    %edi,%ebx
 111f0fc:	shl    $0x4,%ebx
 111f0ff:	mov    (%r10,%rbx,1),%r11
 111f103:	cmp    %r11,%r9
 111f106:	jne    111f116 <sort.block.block__anon_39113+0x15f6>
 111f108:	add    %r10,%rsi
 111f10b:	add    %r10,%rbx
 111f10e:	movzwl 0xe(%rsi),%esi
 111f112:	cmp    0xe(%rbx),%si
 111f116:	jae    111f142 <sort.block.block__anon_39113+0x1622>
 111f118:	mov    %edi,%esi
 111f11a:	shr    $0x8,%esi
 111f11d:	mov    %ecx,%r9d
 111f120:	shr    $0x8,%r9d
 111f124:	mov    %cl,0x4(%r8)
 111f128:	mov    %dil,0xc(%r8)
 111f12c:	mov    %r9b,0x5(%r8)
 111f130:	mov    %sil,0xd(%r8)
 111f134:	mov    -0x30(%rbp),%rcx
 111f138:	mov    (%rcx),%r10
 111f13b:	movzbl -0x58(%rbp),%ecx
 111f13f:	mov    %ecx,-0x48(%rbp)
 111f142:	movzwl 0x8(%r8),%ecx
 111f147:	movzwl (%r8),%edi
 111f14b:	mov    %ecx,%esi
 111f14d:	shl    $0x4,%esi
 111f150:	mov    (%r10,%rsi,1),%r11
 111f154:	mov    %edi,%r9d
 111f157:	shl    $0x4,%r9d
 111f15b:	mov    (%r10,%r9,1),%rbx
 111f15f:	cmp    %rbx,%r11
 111f162:	jne    111f17d <sort.block.block__anon_39113+0x165d>
 111f164:	add    %r10,%rsi
 111f167:	add    %r10,%r9
 111f16a:	movzwl 0xe(%rsi),%esi
 111f16e:	cmp    0xe(%r9),%si
 111f173:	jb     111f17f <sort.block.block__anon_39113+0x165f>
 111f175:	mov    %r14d,%r9d
 111f178:	mov    %r13d,%r14d
 111f17b:	jmp    111f1a4 <sort.block.block__anon_39113+0x1684>
 111f17d:	jae    111f175 <sort.block.block__anon_39113+0x1655>
 111f17f:	mov    %edi,%esi
 111f181:	shr    $0x8,%esi
 111f184:	mov    %ecx,%r9d
 111f187:	shr    $0x8,%r9d
 111f18b:	mov    %cl,(%r8)
 111f18e:	mov    %dil,0x8(%r8)
 111f192:	mov    %r9b,0x1(%r8)
 111f196:	mov    %sil,0x9(%r8)
 111f19a:	mov    -0x30(%rbp),%rcx
 111f19e:	mov    (%rcx),%r10
 111f1a1:	mov    %r13d,%r9d
 111f1a4:	movzwl 0xa(%r8),%ecx
 111f1a9:	movzwl 0x2(%r8),%edi
 111f1ae:	mov    %ecx,%esi
 111f1b0:	shl    $0x4,%esi
 111f1b3:	mov    (%r10,%rsi,1),%r11
 111f1b7:	mov    %edi,%ebx
 111f1b9:	shl    $0x4,%ebx
 111f1bc:	mov    (%r10,%rbx,1),%r13
 111f1c0:	cmp    %r13,%r11
 111f1c3:	jne    111f1dd <sort.block.block__anon_39113+0x16bd>
 111f1c5:	add    %r10,%rsi
 111f1c8:	add    %r10,%rbx
 111f1cb:	movzwl 0xe(%rsi),%esi
 111f1cf:	cmp    0xe(%rbx),%si
 111f1d3:	jb     111f1df <sort.block.block__anon_39113+0x16bf>
 111f1d5:	mov    %r15d,%ecx
 111f1d8:	mov    %r12d,%r15d
 111f1db:	jmp    111f205 <sort.block.block__anon_39113+0x16e5>
 111f1dd:	jae    111f1d5 <sort.block.block__anon_39113+0x16b5>
 111f1df:	mov    %edi,%esi
 111f1e1:	shr    $0x8,%esi
 111f1e4:	mov    %ecx,%r10d
 111f1e7:	shr    $0x8,%r10d
 111f1eb:	mov    %cl,0x2(%r8)
 111f1ef:	mov    %dil,0xa(%r8)
 111f1f3:	mov    %r10b,0x3(%r8)
 111f1f7:	mov    %sil,0xb(%r8)
 111f1fb:	mov    -0x30(%rbp),%rcx
 111f1ff:	mov    (%rcx),%r10
 111f202:	mov    %r12d,%ecx
 111f205:	movzwl 0x6(%r8),%edi
 111f20a:	movzwl (%r8),%ebx
 111f20e:	mov    %edi,%esi
 111f210:	shl    $0x4,%esi
 111f213:	mov    (%r10,%rsi,1),%r12
 111f217:	mov    %ebx,%r13d
 111f21a:	shl    $0x4,%r13d
 111f21e:	mov    (%r10,%r13,1),%r11
 111f222:	cmp    %r11,%r12
 111f225:	jne    111f24e <sort.block.block__anon_39113+0x172e>
 111f227:	add    %r10,%rsi
 111f22a:	add    %r10,%r13
 111f22d:	movzwl 0xe(%r13),%r11d
 111f232:	movzwl 0xe(%rsi),%esi
 111f236:	cmp    %r11w,%si
 111f23a:	mov    -0x40(%rbp),%r13
 111f23e:	jb     111f25f <sort.block.block__anon_39113+0x173f>
 111f240:	cmp    -0x50(%rbp),%r9b
 111f244:	jbe    111f285 <sort.block.block__anon_39113+0x1765>
 111f246:	cmp    %si,%r11w
 111f24a:	jae    111f25f <sort.block.block__anon_39113+0x173f>
 111f24c:	jmp    111f285 <sort.block.block__anon_39113+0x1765>
 111f24e:	mov    -0x40(%rbp),%r13
 111f252:	jb     111f25f <sort.block.block__anon_39113+0x173f>
 111f254:	cmp    -0x50(%rbp),%r9b
 111f258:	jbe    111f285 <sort.block.block__anon_39113+0x1765>
 111f25a:	cmp    %r12,%r11
 111f25d:	jb     111f285 <sort.block.block__anon_39113+0x1765>
 111f25f:	mov    %ebx,%esi
 111f261:	shr    $0x8,%esi
 111f264:	mov    %edi,%r10d
 111f267:	shr    $0x8,%r10d
 111f26b:	mov    %dil,(%r8)
 111f26e:	mov    %bl,0x6(%r8)
 111f272:	mov    %r10b,0x1(%r8)
 111f276:	mov    %sil,0x7(%r8)
 111f27a:	mov    -0x30(%rbp),%rsi
 111f27e:	mov    (%rsi),%r10
 111f281:	mov    %r9b,-0x50(%rbp)
 111f285:	movzwl 0xa(%r8),%edi
 111f28a:	movzwl 0x4(%r8),%r9d
 111f28f:	mov    %edi,%esi
 111f291:	shl    $0x4,%esi
 111f294:	mov    (%r10,%rsi,1),%rbx
 111f298:	mov    %r9d,%r12d
 111f29b:	shl    $0x4,%r12d
 111f29f:	mov    (%r10,%r12,1),%r11
 111f2a3:	cmp    %r11,%rbx
 111f2a6:	jne    111f2cc <sort.block.block__anon_39113+0x17ac>
 111f2a8:	add    %r10,%rsi
 111f2ab:	add    %r10,%r12
 111f2ae:	movzwl 0xe(%r12),%r11d
 111f2b4:	movzwl 0xe(%rsi),%esi
 111f2b8:	cmp    %r11w,%si
 111f2bc:	jb     111f2d9 <sort.block.block__anon_39113+0x17b9>
 111f2be:	cmp    %r15b,-0x48(%rbp)
 111f2c2:	jbe    111f301 <sort.block.block__anon_39113+0x17e1>
 111f2c4:	cmp    %si,%r11w
 111f2c8:	jae    111f2d9 <sort.block.block__anon_39113+0x17b9>
 111f2ca:	jmp    111f301 <sort.block.block__anon_39113+0x17e1>
 111f2cc:	jb     111f2d9 <sort.block.block__anon_39113+0x17b9>
 111f2ce:	cmp    %r15b,-0x48(%rbp)
 111f2d2:	jbe    111f301 <sort.block.block__anon_39113+0x17e1>
 111f2d4:	cmp    %rbx,%r11
 111f2d7:	jb     111f301 <sort.block.block__anon_39113+0x17e1>
 111f2d9:	mov    %r9d,%esi
 111f2dc:	shr    $0x8,%esi
 111f2df:	mov    %edi,%r10d
 111f2e2:	shr    $0x8,%r10d
 111f2e6:	mov    %dil,0x4(%r8)
 111f2ea:	mov    %r9b,0xa(%r8)
 111f2ee:	mov    %r10b,0x5(%r8)
 111f2f2:	mov    %sil,0xb(%r8)
 111f2f6:	mov    -0x30(%rbp),%rsi
 111f2fa:	mov    (%rsi),%r10
 111f2fd:	mov    %r15d,-0x48(%rbp)
 111f301:	movzwl 0x6(%r8),%edi
 111f306:	movzwl 0x2(%r8),%r9d
 111f30b:	mov    %edi,%esi
 111f30d:	shl    $0x4,%esi
 111f310:	mov    (%r10,%rsi,1),%rbx
 111f314:	mov    %r9d,%r15d
 111f317:	shl    $0x4,%r15d
 111f31b:	mov    (%r10,%r15,1),%r11
 111f31f:	cmp    %r11,%rbx
 111f322:	jne    111f346 <sort.block.block__anon_39113+0x1826>
 111f324:	add    %r10,%rsi
 111f327:	add    %r10,%r15
 111f32a:	movzwl 0xe(%r15),%r11d
 111f32f:	movzwl 0xe(%rsi),%esi
 111f333:	cmp    %r11w,%si
 111f337:	jb     111f352 <sort.block.block__anon_39113+0x1832>
 111f339:	cmp    -0x50(%rbp),%cl
 111f33c:	jbe    111f379 <sort.block.block__anon_39113+0x1859>
 111f33e:	cmp    %si,%r11w
 111f342:	jae    111f352 <sort.block.block__anon_39113+0x1832>
 111f344:	jmp    111f379 <sort.block.block__anon_39113+0x1859>
 111f346:	jb     111f352 <sort.block.block__anon_39113+0x1832>
 111f348:	cmp    -0x50(%rbp),%cl
 111f34b:	jbe    111f379 <sort.block.block__anon_39113+0x1859>
 111f34d:	cmp    %rbx,%r11
 111f350:	jb     111f379 <sort.block.block__anon_39113+0x1859>
 111f352:	mov    %r9d,%esi
 111f355:	shr    $0x8,%esi
 111f358:	mov    %edi,%r10d
 111f35b:	shr    $0x8,%r10d
 111f35f:	mov    %dil,0x2(%r8)
 111f363:	mov    %r9b,0x6(%r8)
 111f367:	mov    %r10b,0x3(%r8)
 111f36b:	mov    %sil,0x7(%r8)
 111f36f:	mov    -0x30(%rbp),%rsi
 111f373:	mov    (%rsi),%r10
 111f376:	mov    %cl,-0x50(%rbp)
 111f379:	movzwl 0x8(%r8),%edi
 111f37e:	movzwl 0x4(%r8),%r9d
 111f383:	mov    %edi,%r12d
 111f386:	shl    $0x4,%r12d
 111f38a:	mov    (%r10,%r12,1),%rbx
 111f38e:	mov    %r9d,%esi
 111f391:	shl    $0x4,%esi
 111f394:	mov    (%r10,%rsi,1),%rcx
 111f398:	mov    %r9d,%r15d
 111f39b:	shr    $0x8,%r15d
 111f39f:	cmp    %rcx,%rbx
 111f3a2:	jne    111f3c9 <sort.block.block__anon_39113+0x18a9>
 111f3a4:	add    %r10,%r12
 111f3a7:	add    %r10,%rsi
 111f3aa:	movzwl 0xe(%rsi),%ecx
 111f3ae:	movzwl 0xe(%r12),%esi
 111f3b4:	cmp    %cx,%si
 111f3b7:	jb     111f3d6 <sort.block.block__anon_39113+0x18b6>
 111f3b9:	cmp    %r14b,-0x48(%rbp)
 111f3bd:	jbe    111f3c4 <sort.block.block__anon_39113+0x18a4>
 111f3bf:	cmp    %si,%cx
 111f3c2:	jae    111f3d6 <sort.block.block__anon_39113+0x18b6>
 111f3c4:	mov    %rbx,%rcx
 111f3c7:	jmp    111f40a <sort.block.block__anon_39113+0x18ea>
 111f3c9:	jb     111f3d6 <sort.block.block__anon_39113+0x18b6>
 111f3cb:	cmp    %r14b,-0x48(%rbp)
 111f3cf:	jbe    111f40a <sort.block.block__anon_39113+0x18ea>
 111f3d1:	cmp    %rbx,%rcx
 111f3d4:	jb     111f40a <sort.block.block__anon_39113+0x18ea>
 111f3d6:	mov    %edi,%ecx
 111f3d8:	shr    $0x8,%ecx
 111f3db:	mov    %dil,0x4(%r8)
 111f3df:	mov    %r9b,0x8(%r8)
 111f3e3:	mov    %cl,0x5(%r8)
 111f3e7:	mov    %r15b,0x9(%r8)
 111f3eb:	mov    -0x30(%rbp),%rcx
 111f3ef:	mov    (%rcx),%r10
 111f3f2:	movzwl 0x4(%r8),%r9d
 111f3f7:	mov    %r9d,%ecx
 111f3fa:	shl    $0x4,%ecx
 111f3fd:	mov    (%r10,%rcx,1),%rcx
 111f401:	mov    %r9d,%r15d
 111f404:	shr    $0x8,%r15d
 111f408:	jmp    111f410 <sort.block.block__anon_39113+0x18f0>
 111f40a:	mov    -0x48(%rbp),%esi
 111f40d:	mov    %esi,%r14d
 111f410:	movzwl 0x6(%r8),%edi
 111f415:	mov    %edi,%esi
 111f417:	shl    $0x4,%esi
 111f41a:	mov    (%r10,%rsi,1),%rbx
 111f41e:	cmp    %rcx,%rbx
 111f421:	jne    111f44f <sort.block.block__anon_39113+0x192f>
 111f423:	add    %r10,%rsi
 111f426:	mov    %r9d,%ecx
 111f429:	shl    $0x4,%ecx
 111f42c:	movzwl 0xe(%r10,%rcx,1),%ecx
 111f432:	movzwl 0xe(%rsi),%esi
 111f436:	cmp    %cx,%si
 111f439:	jb     111f464 <sort.block.block__anon_39113+0x1944>
 111f43b:	cmp    -0x50(%rbp),%r14b
 111f43f:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f445:	cmp    %si,%cx
 111f448:	jae    111f464 <sort.block.block__anon_39113+0x1944>
 111f44a:	jmp    111dc11 <sort.block.block__anon_39113+0xf1>
 111f44f:	jb     111f464 <sort.block.block__anon_39113+0x1944>
 111f451:	cmp    -0x50(%rbp),%r14b
 111f455:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f45b:	cmp    %rbx,%rcx
 111f45e:	jb     111dc11 <sort.block.block__anon_39113+0xf1>
 111f464:	mov    %edi,%ecx
 111f466:	shr    $0x8,%ecx
 111f469:	mov    %dil,0x4(%r8)
 111f46d:	mov    %r9b,0x6(%r8)
 111f471:	mov    $0x7,%edi
 111f476:	mov    $0x5,%r9d
 111f47c:	jmp    111dc09 <sort.block.block__anon_39113+0xe9>
 111f481:	mov    %r15d,%ecx
 111f484:	mov    %r12d,%r15d
 111f487:	movzwl 0x8(%r8),%edi
 111f48c:	movzwl 0x2(%r8),%r9d
 111f491:	mov    %edi,%esi
 111f493:	shl    $0x4,%esi
 111f496:	mov    (%r10,%rsi,1),%rbx
 111f49a:	mov    %r9d,%r11d
 111f49d:	shl    $0x4,%r11d
 111f4a1:	mov    (%r10,%r11,1),%r12
 111f4a5:	cmp    %r12,%rbx
 111f4a8:	jne    111f4b9 <sort.block.block__anon_39113+0x1999>
 111f4aa:	add    %r10,%rsi
 111f4ad:	add    %r10,%r11
 111f4b0:	movzwl 0xe(%rsi),%esi
 111f4b4:	cmp    0xe(%r11),%si
 111f4b9:	jae    111f4e5 <sort.block.block__anon_39113+0x19c5>
 111f4bb:	mov    %r9d,%esi
 111f4be:	shr    $0x8,%esi
 111f4c1:	mov    %edi,%r10d
 111f4c4:	shr    $0x8,%r10d
 111f4c8:	mov    %dil,0x2(%r8)
 111f4cc:	mov    %r9b,0x8(%r8)
 111f4d0:	mov    %r10b,0x3(%r8)
 111f4d4:	mov    %sil,0x9(%r8)
 111f4d8:	mov    -0x30(%rbp),%rsi
 111f4dc:	mov    (%rsi),%r10
 111f4df:	mov    %r14d,%esi
 111f4e2:	mov    %esi,-0x50(%rbp)
 111f4e5:	movzwl 0x6(%r8),%edi
 111f4ea:	movzwl (%r8),%r14d
 111f4ee:	mov    %edi,%ebx
 111f4f0:	shl    $0x4,%ebx
 111f4f3:	mov    (%r10,%rbx,1),%r11
 111f4f7:	mov    %r14d,%esi
 111f4fa:	shl    $0x4,%esi
 111f4fd:	mov    (%r10,%rsi,1),%r9
 111f501:	mov    %r14d,%r12d
 111f504:	shr    $0x8,%r12d
 111f508:	cmp    %r9,%r11
 111f50b:	jne    111f524 <sort.block.block__anon_39113+0x1a04>
 111f50d:	add    %r10,%rbx
 111f510:	add    %r10,%rsi
 111f513:	movzwl 0xe(%rbx),%r9d
 111f518:	cmp    0xe(%rsi),%r9w
 111f51d:	jb     111f526 <sort.block.block__anon_39113+0x1a06>
 111f51f:	mov    %r11,%r9
 111f522:	jmp    111f55b <sort.block.block__anon_39113+0x1a3b>
 111f524:	jae    111f55b <sort.block.block__anon_39113+0x1a3b>
 111f526:	mov    %edi,%esi
 111f528:	shr    $0x8,%esi
 111f52b:	mov    %dil,(%r8)
 111f52e:	mov    %r14b,0x6(%r8)
 111f532:	mov    %sil,0x1(%r8)
 111f536:	mov    %r12b,0x7(%r8)
 111f53a:	mov    -0x30(%rbp),%rsi
 111f53e:	mov    (%rsi),%r10
 111f541:	movzwl (%r8),%r14d
 111f545:	mov    %r14d,%esi
 111f548:	shl    $0x4,%esi
 111f54b:	mov    (%r10,%rsi,1),%r9
 111f54f:	mov    %r14d,%r12d
 111f552:	shr    $0x8,%r12d
 111f556:	mov    %r15d,%edi
 111f559:	jmp    111f566 <sort.block.block__anon_39113+0x1a46>
 111f55b:	mov    -0x48(%rbp),%esi
 111f55e:	mov    %esi,%edi
 111f560:	mov    %r15d,%esi
 111f563:	mov    %esi,-0x48(%rbp)
 111f566:	movzwl 0x4(%r8),%r11d
 111f56b:	mov    %r11d,%esi
 111f56e:	shl    $0x4,%esi
 111f571:	mov    (%r10,%rsi,1),%rbx
 111f575:	cmp    %r9,%rbx
 111f578:	jne    111f5a1 <sort.block.block__anon_39113+0x1a81>
 111f57a:	add    %r10,%rsi
 111f57d:	mov    %r14d,%r9d
 111f580:	shl    $0x4,%r9d
 111f584:	movzwl 0xe(%r10,%r9,1),%r9d
 111f58a:	movzwl 0xe(%rsi),%esi
 111f58e:	cmp    %r9w,%si
 111f592:	jb     111f5ad <sort.block.block__anon_39113+0x1a8d>
 111f594:	cmp    %cl,%dil
 111f597:	jbe    111f5cb <sort.block.block__anon_39113+0x1aab>
 111f599:	cmp    %si,%r9w
 111f59d:	jae    111f5ad <sort.block.block__anon_39113+0x1a8d>
 111f59f:	jmp    111f5cb <sort.block.block__anon_39113+0x1aab>
 111f5a1:	jb     111f5ad <sort.block.block__anon_39113+0x1a8d>
 111f5a3:	cmp    %cl,%dil
 111f5a6:	jbe    111f5cb <sort.block.block__anon_39113+0x1aab>
 111f5a8:	cmp    %rbx,%r9
 111f5ab:	jb     111f5cb <sort.block.block__anon_39113+0x1aab>
 111f5ad:	mov    %r11d,%ecx
 111f5b0:	shr    $0x8,%ecx
 111f5b3:	mov    %r11b,(%r8)
 111f5b6:	mov    %r14b,0x4(%r8)
 111f5ba:	mov    %cl,0x1(%r8)
 111f5be:	mov    %r12b,0x5(%r8)
 111f5c2:	mov    -0x30(%rbp),%rcx
 111f5c6:	mov    (%rcx),%r10
 111f5c9:	mov    %edi,%ecx
 111f5cb:	movzwl 0x6(%r8),%r9d
 111f5d0:	movzwl 0x2(%r8),%r14d
 111f5d5:	mov    %r9d,%ebx
 111f5d8:	shl    $0x4,%ebx
 111f5db:	mov    (%r10,%rbx,1),%r11
 111f5df:	mov    %r14d,%esi
 111f5e2:	shl    $0x4,%esi
 111f5e5:	mov    (%r10,%rsi,1),%rdi
 111f5e9:	mov    %r14d,%r15d
 111f5ec:	shr    $0x8,%r15d
 111f5f0:	cmp    %rdi,%r11
 111f5f3:	jne    111f61d <sort.block.block__anon_39113+0x1afd>
 111f5f5:	add    %r10,%rbx
 111f5f8:	add    %r10,%rsi
 111f5fb:	movzwl 0xe(%rsi),%esi
 111f5ff:	movzwl 0xe(%rbx),%edi
 111f603:	cmp    %si,%di
 111f606:	mov    -0x48(%rbp),%ebx
 111f609:	jb     111f634 <sort.block.block__anon_39113+0x1b14>
 111f60b:	cmp    %bl,-0x50(%rbp)
 111f60e:	jbe    111f615 <sort.block.block__anon_39113+0x1af5>
 111f610:	cmp    %di,%si
 111f613:	jae    111f634 <sort.block.block__anon_39113+0x1b14>
 111f615:	mov    %r11,%rdi
 111f618:	mov    -0x50(%rbp),%ebx
 111f61b:	jmp    111f667 <sort.block.block__anon_39113+0x1b47>
 111f61d:	mov    -0x48(%rbp),%ebx
 111f620:	jb     111f634 <sort.block.block__anon_39113+0x1b14>
 111f622:	cmp    %bl,-0x50(%rbp)
 111f625:	jbe    111f803 <sort.block.block__anon_39113+0x1ce3>
 111f62b:	cmp    %r11,%rdi
 111f62e:	jb     111f803 <sort.block.block__anon_39113+0x1ce3>
 111f634:	mov    %r9d,%esi
 111f637:	shr    $0x8,%esi
 111f63a:	mov    %r9b,0x2(%r8)
 111f63e:	mov    %r14b,0x6(%r8)
 111f642:	mov    %sil,0x3(%r8)
 111f646:	mov    %r15b,0x7(%r8)
 111f64a:	mov    -0x30(%rbp),%rsi
 111f64e:	mov    (%rsi),%r10
 111f651:	movzwl 0x2(%r8),%r14d
 111f656:	mov    %r14d,%esi
 111f659:	shl    $0x4,%esi
 111f65c:	mov    (%r10,%rsi,1),%rdi
 111f660:	mov    %r14d,%r15d
 111f663:	shr    $0x8,%r15d
 111f667:	movzwl 0x4(%r8),%r9d
 111f66c:	mov    %r9d,%esi
 111f66f:	shl    $0x4,%esi
 111f672:	mov    (%r10,%rsi,1),%r11
 111f676:	cmp    %rdi,%r11
 111f679:	jne    111f6ad <sort.block.block__anon_39113+0x1b8d>
 111f67b:	add    %r10,%rsi
 111f67e:	mov    %r14d,%edi
 111f681:	shl    $0x4,%edi
 111f684:	movzwl 0xe(%r10,%rdi,1),%edi
 111f68a:	movzwl 0xe(%rsi),%esi
 111f68e:	cmp    %di,%si
 111f691:	jb     111dbf0 <sort.block.block__anon_39113+0xd0>
 111f697:	cmp    %cl,%bl
 111f699:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f69f:	cmp    %si,%di
 111f6a2:	jae    111dbf0 <sort.block.block__anon_39113+0xd0>
 111f6a8:	jmp    111dc11 <sort.block.block__anon_39113+0xf1>
 111f6ad:	jb     111dbf0 <sort.block.block__anon_39113+0xd0>
 111f6b3:	cmp    %cl,%bl
 111f6b5:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f6bb:	cmp    %r11,%rdi
 111f6be:	jae    111dbf0 <sort.block.block__anon_39113+0xd0>
 111f6c4:	jmp    111dc11 <sort.block.block__anon_39113+0xf1>
 111f6c9:	mov    $0x3,%r10b
 111f6cc:	mov    $0x2,%r11b
 111f6cf:	mov    %rbx,%rdi
 111f6d2:	movzwl (%r8),%ebx
 111f6d6:	mov    %ebx,%esi
 111f6d8:	shl    $0x4,%esi
 111f6db:	cmp    (%rcx,%rsi,1),%rdi
 111f6df:	jne    111f6fa <sort.block.block__anon_39113+0x1bda>
 111f6e1:	mov    %r13,%r9
 111f6e4:	add    %rcx,%rsi
 111f6e7:	mov    %r15d,%edi
 111f6ea:	shl    $0x4,%edi
 111f6ed:	movzwl 0xe(%rcx,%rdi,1),%edi
 111f6f2:	cmp    0xe(%rsi),%di
 111f6f6:	jb     111f6ff <sort.block.block__anon_39113+0x1bdf>
 111f6f8:	jmp    111f71d <sort.block.block__anon_39113+0x1bfd>
 111f6fa:	mov    %r13,%r9
 111f6fd:	jae    111f71d <sort.block.block__anon_39113+0x1bfd>
 111f6ff:	mov    %ebx,%ecx
 111f701:	shr    $0x8,%ecx
 111f704:	mov    %r15b,(%r8)
 111f707:	mov    %bl,0x4(%r8)
 111f70b:	mov    %r12b,0x1(%r8)
 111f70f:	mov    %cl,0x5(%r8)
 111f713:	mov    -0x30(%rbp),%rcx
 111f717:	mov    (%rcx),%rcx
 111f71a:	mov    %r14d,%r11d
 111f71d:	movzwl 0x6(%r8),%ebx
 111f722:	movzwl 0x2(%r8),%r14d
 111f727:	mov    %ebx,%r13d
 111f72a:	shl    $0x4,%r13d
 111f72e:	mov    (%rcx,%r13,1),%r12
 111f732:	mov    %r14d,%esi
 111f735:	shl    $0x4,%esi
 111f738:	mov    (%rcx,%rsi,1),%rdi
 111f73c:	mov    %r14d,%r15d
 111f73f:	shr    $0x8,%r15d
 111f743:	cmp    %rdi,%r12
 111f746:	jne    111f761 <sort.block.block__anon_39113+0x1c41>
 111f748:	add    %rcx,%r13
 111f74b:	add    %rcx,%rsi
 111f74e:	movzwl 0xe(%r13),%edi
 111f753:	cmp    0xe(%rsi),%di
 111f757:	mov    %r9,%r13
 111f75a:	jb     111f766 <sort.block.block__anon_39113+0x1c46>
 111f75c:	mov    %r12,%rdi
 111f75f:	jmp    111f79a <sort.block.block__anon_39113+0x1c7a>
 111f761:	mov    %r9,%r13
 111f764:	jae    111f79a <sort.block.block__anon_39113+0x1c7a>
 111f766:	mov    %ebx,%ecx
 111f768:	shr    $0x8,%ecx
 111f76b:	mov    %bl,0x2(%r8)
 111f76f:	mov    %r14b,0x6(%r8)
 111f773:	mov    %cl,0x3(%r8)
 111f777:	mov    %r15b,0x7(%r8)
 111f77b:	mov    -0x30(%rbp),%rcx
 111f77f:	mov    (%rcx),%rcx
 111f782:	movzwl 0x2(%r8),%r14d
 111f787:	mov    %r14d,%esi
 111f78a:	shl    $0x4,%esi
 111f78d:	mov    (%rcx,%rsi,1),%rdi
 111f791:	mov    %r14d,%r15d
 111f794:	shr    $0x8,%r15d
 111f798:	jmp    111f7a0 <sort.block.block__anon_39113+0x1c80>
 111f79a:	mov    -0x48(%rbp),%esi
 111f79d:	mov    %esi,%r10d
 111f7a0:	movzwl 0x4(%r8),%r9d
 111f7a5:	mov    %r9d,%esi
 111f7a8:	shl    $0x4,%esi
 111f7ab:	mov    (%rcx,%rsi,1),%rbx
 111f7af:	cmp    %rdi,%rbx
 111f7b2:	jne    111f7e6 <sort.block.block__anon_39113+0x1cc6>
 111f7b4:	add    %rcx,%rsi
 111f7b7:	mov    %r14d,%edi
 111f7ba:	shl    $0x4,%edi
 111f7bd:	movzwl 0xe(%rcx,%rdi,1),%ecx
 111f7c2:	movzwl 0xe(%rsi),%esi
 111f7c6:	cmp    %cx,%si
 111f7c9:	jb     111dbf0 <sort.block.block__anon_39113+0xd0>
 111f7cf:	cmp    %r11b,%r10b
 111f7d2:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f7d8:	cmp    %si,%cx
 111f7db:	jae    111dbf0 <sort.block.block__anon_39113+0xd0>
 111f7e1:	jmp    111dc11 <sort.block.block__anon_39113+0xf1>
 111f7e6:	jb     111dbf0 <sort.block.block__anon_39113+0xd0>
 111f7ec:	cmp    %r11b,%r10b
 111f7ef:	jbe    111dc11 <sort.block.block__anon_39113+0xf1>
 111f7f5:	cmp    %rbx,%rdi
 111f7f8:	jae    111dbf0 <sort.block.block__anon_39113+0xd0>
 111f7fe:	jmp    111dc11 <sort.block.block__anon_39113+0xf1>
 111f803:	mov    -0x50(%rbp),%ebx
 111f806:	jmp    111f667 <sort.block.block__anon_39113+0x1b47>
 111f80b:	cmp    $0x8,%rsi
 111f80f:	mov    -0x38(%rbp),%r10
 111f813:	jb     112716d <sort.block.block__anon_39113+0x964d>
 111f819:	mov    %rdi,%rdx
 111f81c:	lea    -0x2(%r10),%r13
 111f820:	lea    0x60(%r10),%rax
 111f824:	mov    %rax,-0xc8(%rbp)
 111f82b:	lea    -0x3e(%r10),%rax
 111f82f:	mov    %rax,-0x228(%rbp)
 111f836:	lea    -0x1e(%r10),%rax
 111f83a:	mov    %rax,-0x1b8(%rbp)
 111f841:	lea    0x1(%r10),%rax
 111f845:	mov    %rax,-0x50(%rbp)
 111f849:	lea    0x7(%r10),%rax
 111f84d:	mov    %rax,-0x80(%rbp)
 111f851:	lea    -0x42(%r10),%rax
 111f855:	mov    %rax,-0x250(%rbp)
 111f85c:	lea    0x22(%r10),%rax
 111f860:	mov    %rax,-0x220(%rbp)
 111f867:	lea    0x2(%r10),%rax
 111f86b:	mov    %rax,-0x138(%rbp)
 111f872:	lea    -0x3(%r10),%rax
 111f876:	mov    %rax,-0x148(%rbp)
 111f87d:	lea    0x4(%r10),%rax
 111f881:	mov    %rax,-0x218(%rbp)
 111f888:	lea    -0x22(%r10),%rax
 111f88c:	mov    %rax,-0x1e0(%rbp)
 111f893:	vmovdqa -0x11d07b(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 111f89b:	lea    0x62(%r10),%rax
 111f89f:	mov    %rax,-0x1d8(%rbp)
 111f8a6:	lea    -0x20(%r10),%rax
 111f8aa:	mov    %rax,-0x58(%rbp)
 111f8ae:	lea    -0x1(%r10),%rax
 111f8b2:	mov    %rax,-0x48(%rbp)
 111f8b6:	lea    0x3(%r10),%rax
 111f8ba:	mov    %rax,-0x1c0(%rbp)
 111f8c1:	lea    0x9(%r10),%rax
 111f8c5:	mov    %rax,-0x1b0(%rbp)
 111f8cc:	lea    -0x3c(%r10),%rax
 111f8d0:	mov    %rax,-0x210(%rbp)
 111f8d7:	lea    -0x1c(%r10),%rax
 111f8db:	mov    %rax,-0x208(%rbp)
 111f8e2:	mov    %r13,-0x98(%rbp)
 111f8e9:	jmp    111f938 <sort.block.block__anon_39113+0x1e18>
 111f8eb:	nopl   0x0(%rax,%rax,1)
 111f8f0:	mov    -0xf8(%rbp),%rax
 111f8f7:	mov    -0x38(%rbp),%r10
 111f8fb:	add    %rax,%rax
 111f8fe:	xor    %ecx,%ecx
 111f900:	mov    -0x120(%rbp),%rsi
 111f907:	cmp    %rsi,%rax
 111f90a:	setae  %cl
 111f90d:	mov    $0x0,%edx
 111f912:	cmovae %rsi,%rdx
 111f916:	sub    %rdx,%rax
 111f919:	mov    -0xb8(%rbp),%rdx
 111f920:	lea    (%rcx,%rdx,2),%rdx
 111f924:	mov    %rax,-0xf8(%rbp)
 111f92b:	cmp    -0x118(%rbp),%rdx
 111f932:	jae    112716d <sort.block.block__anon_39113+0x964d>
 111f938:	cmp    $0x200,%rdx
 111f93f:	mov    %rdx,-0xb8(%rbp)
 111f946:	jae    111fbd0 <sort.block.block__anon_39113+0x20b0>
 111f94c:	lea    0x0(,%rdx,4),%rsi
 111f954:	cmp    $0x7f,%rdx
 111f958:	seta   %al
 111f95b:	cmp    -0x118(%rbp),%rsi
 111f962:	seta   %cl
 111f965:	or     %al,%cl
 111f967:	je     111fc60 <sort.block.block__anon_39113+0x2140>
 111f96d:	xor    %r8d,%r8d
 111f970:	xor    %edi,%edi
 111f972:	jmp    111f9f4 <sort.block.block__anon_39113+0x1ed4>
 111f977:	nopw   0x0(%rax,%rax,1)
 111f980:	mov    %r8,%r14
 111f983:	sub    %r12,%r14
 111f986:	mov    %r15,%r13
 111f989:	sub    %r12,%r13
 111f98c:	mov    %rdi,-0x40(%rbp)
 111f990:	mov    %r9,%rdi
 111f993:	mov    %rsi,-0x68(%rbp)
 111f997:	mov    %r13,%rsi
 111f99a:	mov    %r8,%r12
 111f99d:	mov    %r9,%rbx
 111f9a0:	vzeroupper 
 111f9a3:	call   10fd040 <mem.reverse__anon_36385>
 111f9a8:	mov    -0x38(%rbp),%rax
 111f9ac:	lea    (%rax,%r15,2),%rdi
 111f9b0:	mov    %r14,%rsi
 111f9b3:	sub    %r13,%rsi
 111f9b6:	call   10fd040 <mem.reverse__anon_36385>
 111f9bb:	mov    %rbx,%rdi
 111f9be:	mov    %r14,%rsi
 111f9c1:	call   10fd040 <mem.reverse__anon_36385>
 111f9c6:	mov    -0x68(%rbp),%rsi
 111f9ca:	mov    %r12,%r8
 111f9cd:	mov    -0x40(%rbp),%rdi
 111f9d1:	vmovdqa -0x11d1b9(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 111f9d9:	mov    -0x38(%rbp),%r10
 111f9dd:	sub    %rsi,%rdi
 111f9e0:	cmp    -0x118(%rbp),%r8
 111f9e7:	mov    -0xb8(%rbp),%rdx
 111f9ee:	jae    1120530 <sort.block.block__anon_39113+0x2a10>
 111f9f4:	mov    %r8,%r12
 111f9f7:	lea    (%r8,%rdx,1),%r15
 111f9fb:	mov    -0xf8(%rbp),%rsi
 111fa02:	add    %rsi,%rdi
 111fa05:	mov    -0x120(%rbp),%rcx
 111fa0c:	cmp    %rcx,%rdi
 111fa0f:	mov    $0x0,%eax
 111fa14:	cmovae %rcx,%rax
 111fa18:	sbb    $0xffffffffffffffff,%r15
 111fa1c:	sub    %rax,%rdi
 111fa1f:	lea    (%r15,%rdx,1),%r8
 111fa23:	add    %rsi,%rdi
 111fa26:	cmp    %rcx,%rdi
 111fa29:	mov    $0x0,%esi
 111fa2e:	cmovae %rcx,%rsi
 111fa32:	sbb    $0xffffffffffffffff,%r8
 111fa36:	movzwl -0x2(%r10,%r8,2),%eax
 111fa3c:	lea    (%r10,%r12,2),%r9
 111fa40:	movzwl (%r10,%r12,2),%ecx
 111fa45:	mov    -0x30(%rbp),%rdx
 111fa49:	mov    (%rdx),%r13
 111fa4c:	shl    $0x4,%eax
 111fa4f:	shl    $0x4,%ecx
 111fa52:	mov    0x0(%r13,%rcx,1),%rdx
 111fa57:	cmp    %rdx,0x0(%r13,%rax,1)
 111fa5c:	jne    111fa6c <sort.block.block__anon_39113+0x1f4c>
 111fa5e:	add    %r13,%rax
 111fa61:	add    %r13,%rcx
 111fa64:	movzwl 0xe(%rax),%eax
 111fa68:	cmp    0xe(%rcx),%ax
 111fa6c:	jb     111f980 <sort.block.block__anon_39113+0x1e60>
 111fa72:	movzwl (%r10,%r15,2),%r14d
 111fa77:	movzwl -0x2(%r10,%r15,2),%eax
 111fa7d:	mov    %r14d,%ecx
 111fa80:	shl    $0x4,%ecx
 111fa83:	mov    0x0(%r13,%rcx,1),%rbx
 111fa88:	shl    $0x4,%eax
 111fa8b:	cmp    0x0(%r13,%rax,1),%rbx
 111fa90:	jne    111fab0 <sort.block.block__anon_39113+0x1f90>
 111fa92:	add    %r13,%rcx
 111fa95:	add    %r13,%rax
 111fa98:	movzwl 0xe(%rcx),%ecx
 111fa9c:	cmp    0xe(%rax),%cx
 111faa0:	jae    111f9dd <sort.block.block__anon_39113+0x1ebd>
 111faa6:	jmp    111fab6 <sort.block.block__anon_39113+0x1f96>
 111faa8:	nopl   0x0(%rax,%rax,1)
 111fab0:	jae    111f9dd <sort.block.block__anon_39113+0x1ebd>
 111fab6:	mov    %rsi,-0x68(%rbp)
 111faba:	mov    %rdi,-0x40(%rbp)
 111fabe:	mov    %r15,%rax
 111fac1:	sub    %r12,%rax
 111fac4:	sete   -0x70(%rbp)
 111fac8:	mov    %rax,-0x78(%rbp)
 111facc:	lea    (%rax,%rax,1),%rdx
 111fad0:	lea    -0x650(%rbp),%rdi
 111fad7:	mov    %r9,%rsi
 111fada:	mov    %r8,-0x60(%rbp)
 111fade:	vzeroupper 
 111fae1:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111fae6:	mov    -0x60(%rbp),%r9
 111faea:	cmp    %r15,%r9
 111faed:	sete   %al
 111faf0:	or     -0x70(%rbp),%al
 111faf3:	je     111fb04 <sort.block.block__anon_39113+0x1fe4>
 111faf5:	xor    %eax,%eax
 111faf7:	mov    -0x38(%rbp),%r8
 111fafb:	mov    -0x78(%rbp),%r10
 111faff:	jmp    111fb8b <sort.block.block__anon_39113+0x206b>
 111fb04:	lea    0x1(%r12),%rcx
 111fb09:	xor    %eax,%eax
 111fb0b:	mov    -0x38(%rbp),%r8
 111fb0f:	mov    -0x78(%rbp),%r10
 111fb13:	jmp    111fb4b <sort.block.block__anon_39113+0x202b>
 111fb15:	data16 cs nopw 0x0(%rax,%rax,1)
 111fb20:	mov    %dx,-0x2(%r8,%rcx,2)
 111fb26:	inc    %rax
 111fb29:	cmp    %r10,%rax
 111fb2c:	je     111fb85 <sort.block.block__anon_39113+0x2065>
 111fb2e:	inc    %r12
 111fb31:	movzwl (%r8,%r15,2),%r14d
 111fb36:	mov    -0x30(%rbp),%rdx
 111fb3a:	mov    (%rdx),%r13
 111fb3d:	mov    %r14d,%edx
 111fb40:	shl    $0x4,%edx
 111fb43:	mov    0x0(%r13,%rdx,1),%rbx
 111fb48:	inc    %rcx
 111fb4b:	movzwl -0x650(%rbp,%rax,2),%edx
 111fb53:	mov    %edx,%esi
 111fb55:	shl    $0x4,%esi
 111fb58:	cmp    0x0(%r13,%rsi,1),%rbx
 111fb5d:	jne    111fb73 <sort.block.block__anon_39113+0x2053>
 111fb5f:	add    %r13,%rsi
 111fb62:	movzwl %r14w,%edi
 111fb66:	shl    $0x4,%edi
 111fb69:	movzwl 0xe(%r13,%rdi,1),%edi
 111fb6f:	cmp    0xe(%rsi),%di
 111fb73:	jae    111fb20 <sort.block.block__anon_39113+0x2000>
 111fb75:	mov    %r14w,-0x2(%r8,%rcx,2)
 111fb7b:	inc    %r15
 111fb7e:	cmp    %r9,%r15
 111fb81:	jne    111fb2e <sort.block.block__anon_39113+0x200e>
 111fb83:	jmp    111fb88 <sort.block.block__anon_39113+0x2068>
 111fb85:	mov    %r10,%rax
 111fb88:	mov    %rcx,%r12
 111fb8b:	lea    -0x650(,%rax,2),%rsi
 111fb93:	add    %rbp,%rsi
 111fb96:	sub    %rax,%r10
 111fb99:	lea    (%r8,%r12,2),%rdi
 111fb9d:	add    %r10,%r10
 111fba0:	mov    %r10,%rdx
 111fba3:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111fba8:	mov    -0x38(%rbp),%r10
 111fbac:	vmovdqa -0x11d394(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 111fbb4:	mov    -0x40(%rbp),%rdi
 111fbb8:	mov    -0x60(%rbp),%r8
 111fbbc:	mov    -0x68(%rbp),%rsi
 111fbc0:	jmp    111f9dd <sort.block.block__anon_39113+0x1ebd>
 111fbc5:	data16 cs nopw 0x0(%rax,%rax,1)
 111fbd0:	movabs $0x4000000000000000,%rcx
 111fbda:	nopw   0x0(%rax,%rax,1)
 111fbe0:	mov    %rcx,%rax
 111fbe3:	shr    $0x2,%rcx
 111fbe7:	cmp    %rdx,%rax
 111fbea:	ja     111fbe0 <sort.block.block__anon_39113+0x20c0>
 111fbec:	mov    %rdx,%rcx
 111fbef:	xor    %esi,%esi
 111fbf1:	mov    %rax,%rdx
 111fbf4:	xor    %r9d,%r9d
 111fbf7:	nopw   0x0(%rax,%rax,1)
 111fc00:	lea    (%rax,%rsi,1),%rdi
 111fc04:	mov    %rsi,%r8
 111fc07:	shr    %r8
 111fc0a:	cmp    %rdi,%rcx
 111fc0d:	mov    %rax,%rsi
 111fc10:	cmovb  %r9,%rsi
 111fc14:	cmovb  %r9,%rdi
 111fc18:	add    %r8,%rsi
 111fc1b:	sub    %rdi,%rcx
 111fc1e:	shr    $0x2,%rdx
 111fc22:	cmp    $0x3,%rax
 111fc26:	mov    %rdx,%rax
 111fc29:	ja     111fc00 <sort.block.block__anon_39113+0x20e0>
 111fc2b:	mov    -0xb8(%rbp),%rax
 111fc32:	mov    %rax,%rcx
 111fc35:	or     %rsi,%rcx
 111fc38:	shr    $0x20,%rcx
 111fc3c:	je     1120579 <sort.block.block__anon_39113+0x2a59>
 111fc42:	mov    %rax,%rcx
 111fc45:	xor    %edx,%edx
 111fc47:	div    %rsi
 111fc4a:	mov    %rax,%r8
 111fc4d:	jmp    1120583 <sort.block.block__anon_39113+0x2a63>
 111fc52:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111fc60:	lea    (%rdx,%rdx,1),%rax
 111fc64:	mov    $0x1,%ecx
 111fc69:	mov    %rax,-0xd8(%rbp)
 111fc70:	sub    %rax,%rcx
 111fc73:	mov    %rcx,-0x130(%rbp)
 111fc7a:	mov    $0x1,%eax
 111fc7f:	mov    %rsi,-0x108(%rbp)
 111fc86:	sub    %rsi,%rax
 111fc89:	mov    %rax,-0x128(%rbp)
 111fc90:	xor    %r15d,%r15d
 111fc93:	xor    %r11d,%r11d
 111fc96:	jmp    111fcb4 <sort.block.block__anon_39113+0x2194>
 111fc98:	nopl   0x0(%rax,%rax,1)
 111fca0:	sub    -0xe0(%rbp),%r11
 111fca7:	cmp    -0x118(%rbp),%r15
 111fcae:	jae    1120550 <sort.block.block__anon_39113+0x2a30>
 111fcb4:	mov    %r15,%rbx
 111fcb7:	lea    (%r15,%rdx,1),%r12
 111fcbb:	mov    -0xf8(%rbp),%rsi
 111fcc2:	add    %rsi,%r11
 111fcc5:	xor    %edi,%edi
 111fcc7:	mov    -0x120(%rbp),%rcx
 111fcce:	cmp    %rcx,%r11
 111fcd1:	setae  %dil
 111fcd5:	mov    $0x0,%eax
 111fcda:	cmovae %rcx,%rax
 111fcde:	sub    %rax,%r11
 111fce1:	mov    %rdi,-0xe8(%rbp)
 111fce8:	add    %rdi,%r12
 111fceb:	lea    (%r12,%rdx,1),%r14
 111fcef:	add    %rsi,%r11
 111fcf2:	xor    %r9d,%r9d
 111fcf5:	cmp    %rcx,%r11
 111fcf8:	setae  %r9b
 111fcfc:	mov    $0x0,%eax
 111fd01:	cmovae %rcx,%rax
 111fd05:	sub    %rax,%r11
 111fd08:	add    %r9,%r14
 111fd0b:	lea    (%r14,%rdx,1),%rdi
 111fd0f:	add    %rsi,%r11
 111fd12:	xor    %r8d,%r8d
 111fd15:	cmp    %rcx,%r11
 111fd18:	setae  %r8b
 111fd1c:	mov    $0x0,%eax
 111fd21:	cmovae %rcx,%rax
 111fd25:	sub    %rax,%r11
 111fd28:	mov    %r8,-0x100(%rbp)
 111fd2f:	add    %r8,%rdi
 111fd32:	mov    %rdi,-0x78(%rbp)
 111fd36:	lea    (%rdi,%rdx,1),%r15
 111fd3a:	add    %rsi,%r11
 111fd3d:	xor    %edx,%edx
 111fd3f:	cmp    %rcx,%r11
 111fd42:	setae  %dl
 111fd45:	mov    $0x0,%eax
 111fd4a:	cmovae %rcx,%rax
 111fd4e:	mov    %rax,-0xe0(%rbp)
 111fd55:	mov    %rdx,-0xb0(%rbp)
 111fd5c:	add    %rdx,%r15
 111fd5f:	movzwl -0x2(%r10,%r14,2),%eax
 111fd65:	mov    -0x30(%rbp),%rcx
 111fd69:	mov    (%rcx),%r13
 111fd6c:	shl    $0x4,%eax
 111fd6f:	lea    (%rax,%r13,1),%rdi
 111fd73:	mov    0x0(%r13,%rax,1),%r8
 111fd78:	movzwl (%r10,%rbx,2),%eax
 111fd7d:	mov    %eax,%edx
 111fd7f:	shl    $0x4,%edx
 111fd82:	lea    (%r10,%rbx,2),%rcx
 111fd86:	mov    %rcx,-0x90(%rbp)
 111fd8d:	mov    0x0(%r13,%rdx,1),%rcx
 111fd92:	cmp    %rcx,%r8
 111fd95:	mov    %rbx,-0x60(%rbp)
 111fd99:	mov    %r14,-0x68(%rbp)
 111fd9d:	mov    %r11,-0xc0(%rbp)
 111fda4:	mov    %r9,-0x88(%rbp)
 111fdab:	mov    %r15,-0x70(%rbp)
 111fdaf:	jne    111fdbc <sort.block.block__anon_39113+0x229c>
 111fdb1:	add    %r13,%rdx
 111fdb4:	movzwl 0xe(%rdi),%esi
 111fdb8:	cmp    0xe(%rdx),%si
 111fdbc:	jae    111fe10 <sort.block.block__anon_39113+0x22f0>
 111fdbe:	mov    %r12,%rdx
 111fdc1:	sub    %rbx,%rdx
 111fdc4:	mov    -0x68(%rbp),%r14
 111fdc8:	sub    %r12,%r14
 111fdcb:	lea    -0x650(,%r14,2),%rdi
 111fdd3:	add    %rbp,%rdi
 111fdd6:	add    %rdx,%rdx
 111fdd9:	mov    -0x90(%rbp),%rsi
 111fde0:	mov    %r10,%rbx
 111fde3:	vzeroupper 
 111fde6:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111fdeb:	lea    (%rbx,%r12,2),%rsi
 111fdef:	add    %r14,%r14
 111fdf2:	lea    -0x650(%rbp),%rdi
 111fdf9:	mov    %r14,%rdx
 111fdfc:	mov    -0x68(%rbp),%r14
 111fe00:	jmp    112001c <sort.block.block__anon_39113+0x24fc>
 111fe05:	data16 cs nopw 0x0(%rax,%rax,1)
 111fe10:	movzwl (%r10,%r12,2),%edx
 111fe15:	movzwl -0x2(%r10,%r12,2),%r9d
 111fe1b:	mov    %edx,%r10d
 111fe1e:	shl    $0x4,%r10d
 111fe22:	mov    0x0(%r13,%r10,1),%rsi
 111fe27:	shl    $0x4,%r9d
 111fe2b:	cmp    0x0(%r13,%r9,1),%rsi
 111fe30:	jne    111fe42 <sort.block.block__anon_39113+0x2322>
 111fe32:	add    %r13,%r10
 111fe35:	add    %r13,%r9
 111fe38:	movzwl 0xe(%r10),%r10d
 111fe3d:	cmp    0xe(%r9),%r10w
 111fe42:	jae    111ff40 <sort.block.block__anon_39113+0x2420>
 111fe48:	mov    -0x130(%rbp),%r11
 111fe4f:	sub    %rbx,%r11
 111fe52:	sub    -0xe8(%rbp),%r11
 111fe59:	sub    -0x88(%rbp),%r11
 111fe60:	mov    %rbx,%r9
 111fe63:	mov    %r12,%r15
 111fe66:	xor    %r8d,%r8d
 111fe69:	mov    -0x38(%rbp),%r10
 111fe6d:	mov    %r11,-0x110(%rbp)
 111fe74:	movzwl %ax,%edi
 111fe77:	shl    $0x4,%edi
 111fe7a:	lea    (%rdi,%r13,1),%rbx
 111fe7e:	add    $0xe,%rbx
 111fe82:	mov    -0x138(%rbp),%rdi
 111fe89:	lea    (%rdi,%r15,2),%r14
 111fe8d:	lea    (%r11,%r15,1),%rdi
 111fe91:	mov    %r8,-0x40(%rbp)
 111fe95:	lea    -0x650(,%r8,2),%r8
 111fe9d:	add    %rbp,%r8
 111fea0:	xor    %r11d,%r11d
 111fea3:	cmp    %rcx,%rsi
 111fea6:	jne    111fec6 <sort.block.block__anon_39113+0x23a6>
 111fea8:	nopl   0x0(%rax,%rax,1)
 111feb0:	movzwl %dx,%r10d
 111feb4:	shl    $0x4,%r10d
 111feb8:	movzwl 0xe(%r13,%r10,1),%r10d
 111febe:	cmp    (%rbx),%r10w
 111fec2:	mov    -0x38(%rbp),%r10
 111fec6:	jae    111ff00 <sort.block.block__anon_39113+0x23e0>
 111fec8:	mov    %dx,(%r8,%r11,2)
 111fecd:	mov    %rdi,%rdx
 111fed0:	add    %r11,%rdx
 111fed3:	je     111ffa0 <sort.block.block__anon_39113+0x2480>
 111fed9:	movzwl (%r14,%r11,2),%edx
 111fede:	mov    %edx,%esi
 111fee0:	shl    $0x4,%esi
 111fee3:	mov    0x0(%r13,%rsi,1),%rsi
 111fee8:	inc    %r11
 111feeb:	cmp    %rcx,%rsi
 111feee:	je     111feb0 <sort.block.block__anon_39113+0x2390>
 111fef0:	jmp    111fec6 <sort.block.block__anon_39113+0x23a6>
 111fef2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111ff00:	mov    %ax,(%r8,%r11,2)
 111ff05:	inc    %r9
 111ff08:	cmp    %r12,%r9
 111ff0b:	je     11204b0 <sort.block.block__anon_39113+0x2990>
 111ff11:	mov    -0x40(%rbp),%r8
 111ff15:	add    %r11,%r8
 111ff18:	inc    %r8
 111ff1b:	add    %r11,%r15
 111ff1e:	movzwl (%r10,%r9,2),%eax
 111ff23:	mov    %eax,%ecx
 111ff25:	shl    $0x4,%ecx
 111ff28:	mov    0x0(%r13,%rcx,1),%rcx
 111ff2d:	mov    -0x110(%rbp),%r11
 111ff34:	jmp    111fe74 <sort.block.block__anon_39113+0x2354>
 111ff39:	nopl   0x0(%rax)
 111ff40:	mov    -0x38(%rbp),%r10
 111ff44:	mov    -0x78(%rbp),%rcx
 111ff48:	movzwl (%r10,%rcx,2),%eax
 111ff4d:	movzwl -0x2(%r10,%rcx,2),%ecx
 111ff53:	shl    $0x4,%eax
 111ff56:	shl    $0x4,%ecx
 111ff59:	mov    0x0(%r13,%rcx,1),%rdx
 111ff5e:	cmp    %rdx,0x0(%r13,%rax,1)
 111ff63:	jne    111ff73 <sort.block.block__anon_39113+0x2453>
 111ff65:	add    %r13,%rax
 111ff68:	add    %r13,%rcx
 111ff6b:	movzwl 0xe(%rax),%eax
 111ff6f:	cmp    0xe(%rcx),%ax
 111ff73:	mov    -0xb8(%rbp),%rdx
 111ff7a:	jb     111ffd9 <sort.block.block__anon_39113+0x24b9>
 111ff7c:	movzwl (%r10,%r14,2),%eax
 111ff81:	shl    $0x4,%eax
 111ff84:	cmp    %r8,0x0(%r13,%rax,1)
 111ff89:	jne    111ffd3 <sort.block.block__anon_39113+0x24b3>
 111ff8b:	add    %r13,%rax
 111ff8e:	movzwl 0xe(%rax),%eax
 111ff92:	cmp    0xe(%rdi),%ax
 111ff96:	jae    111fca0 <sort.block.block__anon_39113+0x2180>
 111ff9c:	jmp    111ffd9 <sort.block.block__anon_39113+0x24b9>
 111ff9e:	xchg   %ax,%ax
 111ffa0:	sub    %r9,%r12
 111ffa3:	mov    -0x40(%rbp),%rax
 111ffa7:	add    %r11,%rax
 111ffaa:	inc    %rax
 111ffad:	lea    (%r10,%r9,2),%rsi
 111ffb1:	lea    -0x650(,%rax,2),%rdi
 111ffb9:	add    %rbp,%rdi
 111ffbc:	add    %r12,%r12
 111ffbf:	mov    %r12,%rdx
 111ffc2:	mov    %r10,%rbx
 111ffc5:	vzeroupper 
 111ffc8:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111ffcd:	mov    -0x68(%rbp),%r14
 111ffd1:	jmp    1120021 <sort.block.block__anon_39113+0x2501>
 111ffd3:	jae    111fca0 <sort.block.block__anon_39113+0x2180>
 111ffd9:	lea    (%r10,%r12,2),%r15
 111ffdd:	mov    %r12,%r14
 111ffe0:	sub    %rbx,%r14
 111ffe3:	lea    (%r14,%r14,1),%rdx
 111ffe7:	lea    -0x650(%rbp),%rdi
 111ffee:	mov    -0x90(%rbp),%rsi
 111fff5:	mov    %r10,%rbx
 111fff8:	vzeroupper 
 111fffb:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 1120000:	mov    -0x68(%rbp),%rdx
 1120004:	sub    %r12,%rdx
 1120007:	lea    -0x650(,%r14,2),%rdi
 112000f:	add    %rbp,%rdi
 1120012:	mov    -0x68(%rbp),%r14
 1120016:	add    %rdx,%rdx
 1120019:	mov    %r15,%rsi
 112001c:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 1120021:	mov    -0x70(%rbp),%rax
 1120025:	movzwl -0x2(%rbx,%rax,2),%ecx
 112002a:	lea    (%rbx,%r14,2),%rsi
 112002e:	movzwl (%rbx,%r14,2),%eax
 1120033:	shl    $0x4,%ecx
 1120036:	mov    %eax,%edi
 1120038:	shl    $0x4,%edi
 112003b:	mov    0x0(%r13,%rdi,1),%rdx
 1120040:	cmp    %rdx,0x0(%r13,%rcx,1)
 1120045:	mov    %rbx,%r9
 1120048:	mov    %rsi,-0x110(%rbp)
 112004f:	jne    112005f <sort.block.block__anon_39113+0x253f>
 1120051:	add    %r13,%rcx
 1120054:	add    %r13,%rdi
 1120057:	movzwl 0xe(%rcx),%ecx
 112005b:	cmp    0xe(%rdi),%cx
 112005f:	mov    -0x60(%rbp),%r11
 1120063:	jae    11200c0 <sort.block.block__anon_39113+0x25a0>
 1120065:	mov    -0x78(%rbp),%rbx
 1120069:	mov    %rbx,%rdx
 112006c:	sub    %r14,%rdx
 112006f:	mov    %r14,%rax
 1120072:	sub    %r11,%rax
 1120075:	mov    -0x70(%rbp),%r15
 1120079:	mov    %r15,%r14
 112007c:	sub    %rbx,%r14
 112007f:	mov    %rax,-0x40(%rbp)
 1120083:	lea    -0x650(,%rax,2),%r12
 112008b:	add    %rbp,%r12
 112008e:	lea    (%r12,%r14,2),%rdi
 1120092:	add    %rdx,%rdx
 1120095:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 112009a:	mov    -0x38(%rbp),%rax
 112009e:	lea    (%rax,%rbx,2),%rsi
 11200a2:	mov    -0x60(%rbp),%rbx
 11200a6:	add    %r14,%r14
 11200a9:	mov    %r12,%rdi
 11200ac:	mov    %r14,%rdx
 11200af:	jmp    1120265 <sort.block.block__anon_39113+0x2745>
 11200b4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 11200c0:	mov    -0x78(%rbp),%rcx
 11200c4:	movzwl (%r9,%rcx,2),%r10d
 11200c9:	movzwl -0x2(%r9,%rcx,2),%ecx
 11200cf:	mov    %r10d,%r8d
 11200d2:	shl    $0x4,%r8d
 11200d6:	mov    0x0(%r13,%r8,1),%rdi
 11200db:	shl    $0x4,%ecx
 11200de:	cmp    0x0(%r13,%rcx,1),%rdi
 11200e3:	jne    11200f5 <sort.block.block__anon_39113+0x25d5>
 11200e5:	add    %r13,%r8
 11200e8:	add    %r13,%rcx
 11200eb:	movzwl 0xe(%r8),%r8d
 11200f0:	cmp    0xe(%rcx),%r8w
 11200f5:	jae    1120210 <sort.block.block__anon_39113+0x26f0>
 11200fb:	mov    %r14,%rcx
 11200fe:	sub    %r11,%rcx
 1120101:	mov    %rcx,-0x40(%rbp)
 1120105:	lea    -0x650(,%rcx,2),%rsi
 112010d:	add    %rbp,%rsi
 1120110:	mov    -0x128(%rbp),%r15
 1120117:	sub    %r11,%r15
 112011a:	sub    -0xe8(%rbp),%r15
 1120121:	sub    -0x88(%rbp),%r15
 1120128:	sub    -0x100(%rbp),%r15
 112012f:	sub    -0xb0(%rbp),%r15
 1120136:	mov    %r14,%r11
 1120139:	mov    -0x78(%rbp),%r8
 112013d:	xor    %ebx,%ebx
 112013f:	mov    %rsi,-0x140(%rbp)
 1120146:	movzwl %ax,%ecx
 1120149:	shl    $0x4,%ecx
 112014c:	lea    (%rcx,%r13,1),%r14
 1120150:	add    $0xe,%r14
 1120154:	mov    -0x138(%rbp),%rcx
 112015b:	lea    (%rcx,%r8,2),%r12
 112015f:	mov    %r8,-0xa8(%rbp)
 1120166:	lea    (%r15,%r8,1),%r9
 112016a:	mov    %rbx,-0xa0(%rbp)
 1120171:	lea    (%rsi,%rbx,2),%rcx
 1120175:	xor    %ebx,%ebx
 1120177:	cmp    %rdx,%rdi
 112017a:	jne    1120192 <sort.block.block__anon_39113+0x2672>
 112017c:	nopl   0x0(%rax)
 1120180:	movzwl %r10w,%r8d
 1120184:	shl    $0x4,%r8d
 1120188:	movzwl 0xe(%r13,%r8,1),%r8d
 112018e:	cmp    (%r14),%r8w
 1120192:	jae    11201c0 <sort.block.block__anon_39113+0x26a0>
 1120194:	mov    %r10w,(%rcx,%rbx,2)
 1120199:	mov    %r9,%rsi
 112019c:	add    %rbx,%rsi
 112019f:	je     1120270 <sort.block.block__anon_39113+0x2750>
 11201a5:	movzwl (%r12,%rbx,2),%r10d
 11201aa:	mov    %r10d,%edi
 11201ad:	shl    $0x4,%edi
 11201b0:	mov    0x0(%r13,%rdi,1),%rdi
 11201b5:	inc    %rbx
 11201b8:	cmp    %rdx,%rdi
 11201bb:	je     1120180 <sort.block.block__anon_39113+0x2660>
 11201bd:	jmp    1120192 <sort.block.block__anon_39113+0x2672>
 11201bf:	nop
 11201c0:	mov    %ax,(%rcx,%rbx,2)
 11201c4:	inc    %r11
 11201c7:	cmp    -0x78(%rbp),%r11
 11201cb:	je     11204e8 <sort.block.block__anon_39113+0x29c8>
 11201d1:	mov    -0xa0(%rbp),%rax
 11201d8:	add    %rbx,%rax
 11201db:	inc    %rax
 11201de:	mov    -0xa8(%rbp),%r8
 11201e5:	add    %rbx,%r8
 11201e8:	mov    %rax,%rbx
 11201eb:	mov    -0x38(%rbp),%rax
 11201ef:	movzwl (%rax,%r11,2),%eax
 11201f4:	mov    %eax,%ecx
 11201f6:	shl    $0x4,%ecx
 11201f9:	mov    0x0(%r13,%rcx,1),%rdx
 11201fe:	mov    -0x140(%rbp),%rsi
 1120205:	jmp    1120146 <sort.block.block__anon_39113+0x2626>
 112020a:	nopw   0x0(%rax,%rax,1)
 1120210:	mov    -0x78(%rbp),%r14
 1120214:	lea    (%r9,%r14,2),%rax
 1120218:	mov    %rax,-0x88(%rbp)
 112021f:	mov    %r14,%rbx
 1120222:	sub    -0x68(%rbp),%rbx
 1120226:	mov    -0x68(%rbp),%rax
 112022a:	sub    -0x60(%rbp),%rax
 112022e:	mov    %rax,-0x40(%rbp)
 1120232:	lea    -0x650(,%rax,2),%r12
 112023a:	add    %rbp,%r12
 112023d:	lea    (%rbx,%rbx,1),%rdx
 1120241:	mov    %r12,%rdi
 1120244:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 1120249:	mov    -0x70(%rbp),%r15
 112024d:	mov    %r15,%rdx
 1120250:	sub    %r14,%rdx
 1120253:	lea    (%r12,%rbx,2),%rdi
 1120257:	mov    -0x60(%rbp),%rbx
 112025b:	add    %rdx,%rdx
 112025e:	mov    -0x88(%rbp),%rsi
 1120265:	mov    -0x68(%rbp),%r14
 1120269:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 112026e:	jmp    11202ab <sort.block.block__anon_39113+0x278b>
 1120270:	mov    -0x78(%rbp),%rdx
 1120274:	sub    %r11,%rdx
 1120277:	mov    -0xa0(%rbp),%rax
 112027e:	add    %rbx,%rax
 1120281:	inc    %rax
 1120284:	mov    -0x38(%rbp),%rcx
 1120288:	lea    (%rcx,%r11,2),%rsi
 112028c:	mov    -0x140(%rbp),%rcx
 1120293:	lea    (%rcx,%rax,2),%rdi
 1120297:	add    %rdx,%rdx
 112029a:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 112029f:	mov    -0x70(%rbp),%r15
 11202a3:	mov    -0x60(%rbp),%rbx
 11202a7:	mov    -0x68(%rbp),%r14
 11202ab:	mov    %r15,%r12
 11202ae:	sub    %r14,%r12
 11202b1:	mov    %r15,%rdx
 11202b4:	sub    %rbx,%rdx
 11202b7:	movzwl -0x652(%rbp,%rdx,2),%ecx
 11202bf:	movzwl -0x650(%rbp),%eax
 11202c6:	shl    $0x4,%ecx
 11202c9:	mov    %eax,%esi
 11202cb:	shl    $0x4,%esi
 11202ce:	mov    0x0(%r13,%rsi,1),%r10
 11202d3:	cmp    %r10,0x0(%r13,%rcx,1)
 11202d8:	jne    11202e8 <sort.block.block__anon_39113+0x27c8>
 11202da:	add    %r13,%rcx
 11202dd:	add    %r13,%rsi
 11202e0:	movzwl 0xe(%rcx),%ecx
 11202e4:	cmp    0xe(%rsi),%cx
 11202e8:	jae    1120320 <sort.block.block__anon_39113+0x2800>
 11202ea:	mov    -0x90(%rbp),%rbx
 11202f1:	lea    (%rbx,%r12,2),%rdi
 11202f5:	mov    -0x40(%rbp),%r14
 11202f9:	lea    (%r14,%r14,1),%rdx
 11202fd:	lea    -0x650(%rbp),%rsi
 1120304:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 1120309:	lea    -0x650(,%r14,2),%rsi
 1120311:	add    %rbp,%rsi
 1120314:	add    %r12,%r12
 1120317:	mov    %rbx,%rdi
 112031a:	jmp    1120452 <sort.block.block__anon_39113+0x2932>
 112031f:	nop
 1120320:	mov    -0x40(%rbp),%rsi
 1120324:	movzwl -0x650(%rbp,%rsi,2),%ecx
 112032c:	movzwl -0x652(%rbp,%rsi,2),%esi
 1120334:	mov    %ecx,%edi
 1120336:	shl    $0x4,%edi
 1120339:	mov    0x0(%r13,%rdi,1),%r14
 112033e:	shl    $0x4,%esi
 1120341:	cmp    0x0(%r13,%rsi,1),%r14
 1120346:	jne    1120356 <sort.block.block__anon_39113+0x2836>
 1120348:	add    %r13,%rdi
 112034b:	add    %r13,%rsi
 112034e:	movzwl 0xe(%rdi),%edi
 1120352:	cmp    0xe(%rsi),%di
 1120356:	jae    1120420 <sort.block.block__anon_39113+0x2900>
 112035c:	mov    $0x1,%edi
 1120361:	xor    %r9d,%r9d
 1120364:	mov    -0x40(%rbp),%rsi
 1120368:	xor    %r8d,%r8d
 112036b:	mov    -0x90(%rbp),%r12
 1120372:	jmp    112039b <sort.block.block__anon_39113+0x287b>
 1120374:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120380:	mov    -0x30(%rbp),%r10
 1120384:	mov    (%r10),%r13
 1120387:	shl    $0x4,%ebx
 112038a:	mov    0x0(%r13,%rbx,1),%r14
 112038f:	shl    $0x4,%r11d
 1120393:	mov    0x0(%r13,%r11,1),%r10
 1120398:	inc    %rdi
 112039b:	movzwl %cx,%ebx
 112039e:	movzwl %ax,%r11d
 11203a2:	cmp    %r10,%r14
 11203a5:	jne    11203c1 <sort.block.block__anon_39113+0x28a1>
 11203a7:	mov    %r11d,%r10d
 11203aa:	shl    $0x4,%r10d
 11203ae:	mov    %ebx,%r14d
 11203b1:	shl    $0x4,%r14d
 11203b5:	movzwl 0xe(%r13,%r14,1),%r14d
 11203bb:	cmp    0xe(%r13,%r10,1),%r14w
 11203c1:	jae    11203f0 <sort.block.block__anon_39113+0x28d0>
 11203c3:	mov    %cx,-0x2(%r12,%rdi,2)
 11203c9:	lea    0x1(%rsi),%r10
 11203cd:	cmp    %rdx,%r10
 11203d0:	je     1120457 <sort.block.block__anon_39113+0x2937>
 11203d6:	inc    %r8
 11203d9:	movzwl -0x64e(%rbp,%rsi,2),%ecx
 11203e1:	movzwl %cx,%ebx
 11203e4:	mov    %r10,%rsi
 11203e7:	jmp    1120380 <sort.block.block__anon_39113+0x2860>
 11203e9:	nopl   0x0(%rax)
 11203f0:	mov    %ax,-0x2(%r12,%rdi,2)
 11203f6:	lea    0x1(%r9),%r10
 11203fa:	cmp    -0x40(%rbp),%r10
 11203fe:	je     1120463 <sort.block.block__anon_39113+0x2943>
 1120400:	inc    %r8
 1120403:	movzwl -0x64e(%rbp,%r9,2),%eax
 112040c:	movzwl %ax,%r11d
 1120410:	mov    %r10,%r9
 1120413:	jmp    1120380 <sort.block.block__anon_39113+0x2860>
 1120418:	nopl   0x0(%rax,%rax,1)
 1120420:	mov    -0x40(%rbp),%rdx
 1120424:	lea    -0x650(,%rdx,2),%r14
 112042c:	add    %rbp,%r14
 112042f:	add    %rdx,%rdx
 1120432:	mov    -0x90(%rbp),%rdi
 1120439:	lea    -0x650(%rbp),%rsi
 1120440:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 1120445:	add    %r12,%r12
 1120448:	mov    -0x110(%rbp),%rdi
 112044f:	mov    %r14,%rsi
 1120452:	mov    %r12,%rdx
 1120455:	jmp    1120478 <sort.block.block__anon_39113+0x2958>
 1120457:	mov    -0x40(%rbp),%rdx
 112045b:	sub    %r9,%rdx
 112045e:	mov    %r9,%rsi
 1120461:	jmp    1120466 <sort.block.block__anon_39113+0x2946>
 1120463:	sub    %rsi,%rdx
 1120466:	lea    -0x650(,%rsi,2),%rsi
 112046e:	add    %rbp,%rsi
 1120471:	lea    (%r12,%rdi,2),%rdi
 1120475:	add    %rdx,%rdx
 1120478:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 112047d:	mov    -0x38(%rbp),%r10
 1120481:	mov    -0xb8(%rbp),%rdx
 1120488:	vmovdqa -0x11dc70(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1120490:	mov    -0xc0(%rbp),%r11
 1120497:	sub    -0xe0(%rbp),%r11
 112049e:	cmp    -0x118(%rbp),%r15
 11204a5:	jb     111fcb4 <sort.block.block__anon_39113+0x2194>
 11204ab:	jmp    1120550 <sort.block.block__anon_39113+0x2a30>
 11204b0:	mov    -0xd8(%rbp),%rax
 11204b7:	mov    -0x60(%rbp),%rcx
 11204bb:	lea    (%rax,%rcx,1),%r12
 11204bf:	add    -0x88(%rbp),%r12
 11204c6:	add    -0xe8(%rbp),%r12
 11204cd:	sub    %r15,%r12
 11204d0:	add    %r11,%r15
 11204d3:	sub    %r11,%r12
 11204d6:	mov    -0x40(%rbp),%rax
 11204da:	add    %r11,%rax
 11204dd:	inc    %rax
 11204e0:	mov    %r15,%r9
 11204e3:	jmp    111ffad <sort.block.block__anon_39113+0x248d>
 11204e8:	mov    -0x108(%rbp),%rax
 11204ef:	mov    -0x60(%rbp),%rcx
 11204f3:	add    %rcx,%rax
 11204f6:	mov    -0x88(%rbp),%rdx
 11204fd:	add    %rax,%rdx
 1120500:	add    -0x100(%rbp),%rdx
 1120507:	add    -0xb0(%rbp),%rdx
 112050e:	add    -0xe8(%rbp),%rdx
 1120515:	mov    -0xa8(%rbp),%r11
 112051c:	sub    %r11,%rdx
 112051f:	add    %rbx,%r11
 1120522:	sub    %rbx,%rdx
 1120525:	jmp    1120277 <sort.block.block__anon_39113+0x2757>
 112052a:	nopw   0x0(%rax,%rax,1)
 1120530:	mov    -0xf8(%rbp),%rax
 1120537:	mov    -0x98(%rbp),%r13
 112053e:	jmp    111f8fb <sort.block.block__anon_39113+0x1ddb>
 1120543:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120550:	mov    -0xf8(%rbp),%rcx
 1120557:	add    %rcx,%rcx
 112055a:	mov    %rcx,%rax
 112055d:	sub    -0x120(%rbp),%rax
 1120564:	jae    1120d12 <sort.block.block__anon_39113+0x31f2>
 112056a:	mov    %rcx,%rax
 112056d:	mov    -0xd8(%rbp),%rcx
 1120574:	jmp    1120d1d <sort.block.block__anon_39113+0x31fd>
 1120579:	mov    %rax,%rcx
 112057c:	xor    %edx,%edx
 112057e:	div    %esi
 1120580:	mov    %eax,%r8d
 1120583:	lea    0x2(,%r8,2),%rdx
 112058b:	cmp    %rcx,%rdx
 112058e:	seta   %al
 1120591:	lea    0x1(%r8),%rdi
 1120595:	mov    %rdx,-0xe0(%rbp)
 112059c:	cmova  %rdi,%rdx
 11205a0:	cmp    $0x201,%rsi
 11205a7:	setae  %r9b
 11205ab:	mov    %rdi,-0x88(%rbp)
 11205b2:	cmovb  %rdi,%rdx
 11205b6:	mov    %rdx,-0x40(%rbp)
 11205ba:	vpxor  %xmm0,%xmm0,%xmm0
 11205be:	vmovdqu %ymm0,-0x1a0(%rbp)
 11205c6:	vmovdqu %ymm0,-0x180(%rbp)
 11205ce:	vmovdqu %ymm0,-0x170(%rbp)
 11205d6:	and    %al,%r9b
 11205d9:	mov    %r9d,-0xc0(%rbp)
 11205e0:	movq   $0x0,-0xb0(%rbp)
 11205eb:	movq   $0x0,-0xd0(%rbp)
 11205f6:	xor    %r12d,%r12d
 11205f9:	xor    %edi,%edi
 11205fb:	xor    %r9d,%r9d
 11205fe:	mov    %rcx,%rdx
 1120601:	mov    %r8,-0x68(%rbp)
 1120605:	jmp    1120629 <sort.block.block__anon_39113+0x2b09>
 1120607:	xor    %r12d,%r12d
 112060a:	mov    -0xa0(%rbp),%rdi
 1120611:	mov    -0x78(%rbp),%rax
 1120615:	mov    -0x60(%rbp),%r9
 1120619:	sub    %rax,%r9
 112061c:	cmp    -0x118(%rbp),%rdi
 1120623:	jae    1120dc0 <sort.block.block__anon_39113+0x32a0>
 1120629:	mov    %rdi,%r11
 112062c:	lea    (%rdi,%rdx,1),%r15
 1120630:	mov    -0xf8(%rbp),%rdi
 1120637:	add    %rdi,%r9
 112063a:	mov    -0x120(%rbp),%rcx
 1120641:	cmp    %rcx,%r9
 1120644:	mov    $0x0,%eax
 1120649:	cmovae %rcx,%rax
 112064d:	sbb    $0xffffffffffffffff,%r15
 1120651:	sub    %rax,%r9
 1120654:	lea    (%r15,%rdx,1),%rax
 1120658:	add    %rdi,%r9
 112065b:	mov    %r9,-0x60(%rbp)
 112065f:	cmp    %rcx,%r9
 1120662:	mov    $0x0,%edi
 1120667:	cmovae %rcx,%rdi
 112066b:	mov    %rdi,-0x78(%rbp)
 112066f:	sbb    $0xffffffffffffffff,%rax
 1120673:	mov    %rax,-0xa0(%rbp)
 112067a:	mov    $0x1,%r9d
 1120680:	mov    %r11,-0xa8(%rbp)
 1120687:	cmpq   $0x2,-0x40(%rbp)
 112068c:	jb     112084a <sort.block.block__anon_39113+0x2d2a>
 1120692:	mov    -0xa8(%rbp),%r11
 1120699:	nopl   0x0(%rax)
 11206a0:	lea    0x1(%r11),%rbx
 11206a4:	mov    %r15,%rax
 11206a7:	sub    %rbx,%rax
 11206aa:	je     1120843 <sort.block.block__anon_39113+0x2d23>
 11206b0:	mov    -0x40(%rbp),%rcx
 11206b4:	sub    %r9,%rcx
 11206b7:	movzwl (%r10,%r11,2),%edi
 11206bc:	mov    %rax,%rdx
 11206bf:	or     %rcx,%rdx
 11206c2:	shr    $0x20,%rdx
 11206c6:	je     11206d0 <sort.block.block__anon_39113+0x2bb0>
 11206c8:	xor    %edx,%edx
 11206ca:	div    %rcx
 11206cd:	jmp    11206d4 <sort.block.block__anon_39113+0x2bb4>
 11206cf:	nop
 11206d0:	xor    %edx,%edx
 11206d2:	div    %ecx
 11206d4:	cmp    $0x1,%rax
 11206d8:	adc    $0x0,%rax
 11206dc:	mov    -0x30(%rbp),%rcx
 11206e0:	mov    (%rcx),%rcx
 11206e3:	shl    $0x4,%edi
 11206e6:	lea    (%rcx,%rdi,1),%r13
 11206ea:	mov    (%rcx,%rdi,1),%rdi
 11206ee:	mov    %r15,%r10
 11206f1:	sub    %rax,%r10
 11206f4:	jmp    112071b <sort.block.block__anon_39113+0x2bfb>
 11206f6:	cs nopw 0x0(%rax,%rax,1)
 1120700:	add    %rcx,%r8
 1120703:	movzwl 0xe(%r13),%r14d
 1120708:	cmp    0xe(%r8),%r14w
 112070d:	jb     1120737 <sort.block.block__anon_39113+0x2c17>
 112070f:	mov    %rdx,%rbx
 1120712:	cmp    %r10,%rdx
 1120715:	jae    11207a0 <sort.block.block__anon_39113+0x2c80>
 112071b:	lea    (%rbx,%rax,1),%rdx
 112071f:	mov    -0x98(%rbp),%r8
 1120726:	movzwl (%r8,%rdx,2),%r8d
 112072b:	shl    $0x4,%r8d
 112072f:	cmp    (%rcx,%r8,1),%rdi
 1120733:	je     1120700 <sort.block.block__anon_39113+0x2be0>
 1120735:	jae    112070f <sort.block.block__anon_39113+0x2bef>
 1120737:	mov    %rbx,%rdx
 112073a:	mov    -0x38(%rbp),%r10
 112073e:	jmp    112075e <sort.block.block__anon_39113+0x2c3e>
 1120740:	mov    %eax,%r8d
 1120743:	and    $0x1,%r8d
 1120747:	add    %r10,%r8
 112074a:	add    %r8,%rdx
 112074d:	cmp    $0x2,%rax
 1120751:	mov    %r10,%rax
 1120754:	mov    -0x38(%rbp),%r10
 1120758:	jb     1120820 <sort.block.block__anon_39113+0x2d00>
 112075e:	lea    (%r10,%rdx,2),%r8
 1120762:	mov    %rax,%r10
 1120765:	and    $0xfffffffffffffffe,%r10
 1120769:	movzwl (%r10,%r8,1),%r8d
 112076e:	shl    $0x4,%r8d
 1120772:	cmp    (%rcx,%r8,1),%rdi
 1120776:	jne    1120785 <sort.block.block__anon_39113+0x2c65>
 1120778:	add    %rcx,%r8
 112077b:	movzwl 0xe(%r13),%r10d
 1120780:	cmp    0xe(%r8),%r10w
 1120785:	setb   %r8b
 1120789:	mov    %rax,%r10
 112078c:	shr    %r10
 112078f:	test   %r8b,%r8b
 1120792:	je     1120740 <sort.block.block__anon_39113+0x2c20>
 1120794:	xor    %r8d,%r8d
 1120797:	jmp    112074a <sort.block.block__anon_39113+0x2c2a>
 1120799:	nopl   0x0(%rax)
 11207a0:	mov    %r15,%rax
 11207a3:	sub    %rdx,%rax
 11207a6:	mov    -0x38(%rbp),%r10
 11207aa:	ja     11207da <sort.block.block__anon_39113+0x2cba>
 11207ac:	jmp    1120933 <sort.block.block__anon_39113+0x2e13>
 11207b1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11207c0:	mov    %eax,%r8d
 11207c3:	and    $0x1,%r8d
 11207c7:	add    %r10,%r8
 11207ca:	add    %r8,%rdx
 11207cd:	cmp    $0x1,%rax
 11207d1:	mov    %r10,%rax
 11207d4:	mov    -0x38(%rbp),%r10
 11207d8:	jbe    1120820 <sort.block.block__anon_39113+0x2d00>
 11207da:	lea    (%r10,%rdx,2),%r8
 11207de:	mov    %rax,%r10
 11207e1:	and    $0xfffffffffffffffe,%r10
 11207e5:	movzwl (%r10,%r8,1),%r8d
 11207ea:	shl    $0x4,%r8d
 11207ee:	cmp    (%rcx,%r8,1),%rdi
 11207f2:	jne    1120801 <sort.block.block__anon_39113+0x2ce1>
 11207f4:	add    %rcx,%r8
 11207f7:	movzwl 0xe(%r13),%r10d
 11207fc:	cmp    0xe(%r8),%r10w
 1120801:	setb   %r8b
 1120805:	mov    %rax,%r10
 1120808:	shr    %r10
 112080b:	test   %r8b,%r8b
 112080e:	je     11207c0 <sort.block.block__anon_39113+0x2ca0>
 1120810:	xor    %r8d,%r8d
 1120813:	jmp    11207ca <sort.block.block__anon_39113+0x2caa>
 1120815:	data16 cs nopw 0x0(%rax,%rax,1)
 1120820:	cmp    %r15,%rdx
 1120823:	mov    -0x98(%rbp),%r13
 112082a:	je     1120843 <sort.block.block__anon_39113+0x2d23>
 112082c:	inc    %r9
 112082f:	mov    %rdx,%r11
 1120832:	cmp    -0x40(%rbp),%r9
 1120836:	jne    11206a0 <sort.block.block__anon_39113+0x2b80>
 112083c:	mov    %rdx,%r11
 112083f:	mov    -0x40(%rbp),%r9
 1120843:	mov    -0xb8(%rbp),%rdx
 112084a:	cmp    -0x68(%rbp),%r9
 112084e:	jbe    1120950 <sort.block.block__anon_39113+0x2e30>
 1120854:	lea    (%r12,%r12,4),%rax
 1120858:	mov    %r11,-0x1a0(%rbp,%rax,8)
 1120860:	mov    -0xa8(%rbp),%rdi
 1120867:	mov    %rdi,-0x198(%rbp,%rax,8)
 112086f:	mov    %r9,-0x190(%rbp,%rax,8)
 1120877:	mov    %rdi,-0x188(%rbp,%rax,8)
 112087f:	mov    -0xa0(%rbp),%rcx
 1120886:	mov    %rcx,-0x180(%rbp,%rax,8)
 112088e:	mov    -0xe0(%rbp),%rcx
 1120895:	cmp    %rcx,%r9
 1120898:	je     1120d30 <sort.block.block__anon_39113+0x3210>
 112089e:	add    %rdi,%r9
 11208a1:	cmp    %rcx,-0x40(%rbp)
 11208a5:	jne    11208e0 <sort.block.block__anon_39113+0x2dc0>
 11208a7:	movl   $0x0,-0x70(%rbp)
 11208ae:	mov    -0x88(%rbp),%rax
 11208b5:	mov    %rax,-0x40(%rbp)
 11208b9:	lea    -0x178(%rbp),%rax
 11208c0:	mov    %rax,-0x90(%rbp)
 11208c7:	mov    %rdi,-0xd0(%rbp)
 11208ce:	mov    %r9,-0xb0(%rbp)
 11208d5:	jmp    11209dd <sort.block.block__anon_39113+0x2ebd>
 11208da:	nopw   0x0(%rax,%rax,1)
 11208e0:	cmp    $0x201,%rsi
 11208e7:	jb     1120d89 <sort.block.block__anon_39113+0x3269>
 11208ed:	testb  $0x1,-0xc0(%rbp)
 11208f4:	je     1127012 <sort.block.block__anon_39113+0x94f2>
 11208fa:	movl   $0x0,-0x70(%rbp)
 1120901:	lea    -0x178(%rbp),%rax
 1120908:	mov    %rax,-0x90(%rbp)
 112090f:	mov    -0xa8(%rbp),%rax
 1120916:	mov    %rax,-0xd0(%rbp)
 112091d:	mov    %r9,-0xb0(%rbp)
 1120924:	movl   $0x0,-0xc0(%rbp)
 112092e:	jmp    11209dd <sort.block.block__anon_39113+0x2ebd>
 1120933:	mov    -0xb8(%rbp),%rdx
 112093a:	mov    -0x98(%rbp),%r13
 1120941:	cmp    -0x68(%rbp),%r9
 1120945:	ja     1120854 <sort.block.block__anon_39113+0x2d34>
 112094b:	nopl   0x0(%rax,%rax,1)
 1120950:	test   %r12,%r12
 1120953:	je     1120965 <sort.block.block__anon_39113+0x2e45>
 1120955:	movl   $0x0,-0x70(%rbp)
 112095c:	lea    -0x178(%rbp),%rax
 1120963:	jmp    11209d6 <sort.block.block__anon_39113+0x2eb6>
 1120965:	mov    -0xb0(%rbp),%rax
 112096c:	sub    -0xd0(%rbp),%rax
 1120973:	mov    $0x1,%cl
 1120975:	mov    %ecx,-0x70(%rbp)
 1120978:	cmp    %rax,%r9
 112097b:	jbe    11209cf <sort.block.block__anon_39113+0x2eaf>
 112097d:	mov    %r11,-0x1a0(%rbp)
 1120984:	mov    -0xa8(%rbp),%rcx
 112098b:	mov    %rcx,-0x198(%rbp)
 1120992:	mov    %r9,-0x190(%rbp)
 1120999:	add    %rcx,%r9
 112099c:	mov    %rcx,-0x188(%rbp)
 11209a3:	mov    -0xa0(%rbp),%rax
 11209aa:	mov    %rax,-0x180(%rbp)
 11209b1:	lea    -0x1a0(%rbp),%rax
 11209b8:	mov    %rax,-0x90(%rbp)
 11209bf:	mov    %rcx,-0xd0(%rbp)
 11209c6:	mov    %r9,-0xb0(%rbp)
 11209cd:	jmp    11209dd <sort.block.block__anon_39113+0x2ebd>
 11209cf:	lea    -0x1a0(%rbp),%rax
 11209d6:	mov    %rax,-0x90(%rbp)
 11209dd:	mov    -0xa0(%rbp),%rax
 11209e4:	lea    -0x1(%rax),%r11
 11209e8:	mov    $0x1,%r9d
 11209ee:	cmpq   $0x2,-0x40(%rbp)
 11209f3:	jb     1120bc6 <sort.block.block__anon_39113+0x30a6>
 11209f9:	nopl   0x0(%rax)
 1120a00:	mov    %r11,%rax
 1120a03:	sub    %r15,%rax
 1120a06:	je     1120bbf <sort.block.block__anon_39113+0x309f>
 1120a0c:	mov    -0x40(%rbp),%rcx
 1120a10:	sub    %r9,%rcx
 1120a13:	movzwl (%r10,%r11,2),%r13d
 1120a18:	mov    %rax,%rdx
 1120a1b:	or     %rcx,%rdx
 1120a1e:	shr    $0x20,%rdx
 1120a22:	je     1120a30 <sort.block.block__anon_39113+0x2f10>
 1120a24:	xor    %edx,%edx
 1120a26:	div    %rcx
 1120a29:	jmp    1120a34 <sort.block.block__anon_39113+0x2f14>
 1120a2b:	nopl   0x0(%rax,%rax,1)
 1120a30:	xor    %edx,%edx
 1120a32:	div    %ecx
 1120a34:	cmp    $0x1,%rax
 1120a38:	adc    $0x0,%rax
 1120a3c:	lea    (%rax,%r15,1),%r10
 1120a40:	mov    -0x30(%rbp),%rcx
 1120a44:	mov    (%rcx),%rcx
 1120a47:	mov    %r13d,%edi
 1120a4a:	shl    $0x4,%edi
 1120a4d:	add    %rcx,%rdi
 1120a50:	mov    %r11,%rdx
 1120a53:	jmp    1120a78 <sort.block.block__anon_39113+0x2f58>
 1120a55:	data16 cs nopw 0x0(%rax,%rax,1)
 1120a60:	add    %rcx,%r8
 1120a63:	movzwl 0xe(%r8),%r8d
 1120a68:	cmp    0xe(%rdi),%r8w
 1120a6d:	jb     1120ab3 <sort.block.block__anon_39113+0x2f93>
 1120a6f:	cmp    %r10,%rdx
 1120a72:	jb     1120b30 <sort.block.block__anon_39113+0x3010>
 1120a78:	sub    %rax,%rdx
 1120a7b:	mov    %rdx,%r14
 1120a7e:	sub    %r15,%r14
 1120a81:	jbe    1120ab0 <sort.block.block__anon_39113+0x2f90>
 1120a83:	mov    -0x98(%rbp),%r8
 1120a8a:	movzwl (%r8,%rdx,2),%r8d
 1120a8f:	shl    $0x4,%r8d
 1120a93:	mov    (%rcx,%r8,1),%r12
 1120a97:	mov    (%rdi),%rbx
 1120a9a:	cmp    %rbx,%r12
 1120a9d:	je     1120a60 <sort.block.block__anon_39113+0x2f40>
 1120a9f:	jae    1120a6f <sort.block.block__anon_39113+0x2f4f>
 1120aa1:	mov    %rbx,%r12
 1120aa4:	jmp    1120ab3 <sort.block.block__anon_39113+0x2f93>
 1120aa6:	cs nopw 0x0(%rax,%rax,1)
 1120ab0:	mov    (%rdi),%r12
 1120ab3:	shl    $0x4,%r13d
 1120ab7:	lea    (%rcx,%r13,1),%rdi
 1120abb:	add    $0xe,%rdi
 1120abf:	mov    -0x38(%rbp),%r10
 1120ac3:	mov    -0x98(%rbp),%r13
 1120aca:	jmp    1120ae7 <sort.block.block__anon_39113+0x2fc7>
 1120acc:	nopl   0x0(%rax)
 1120ad0:	xor    %r8d,%r8d
 1120ad3:	add    %r8,%rdx
 1120ad6:	cmp    $0x2,%rax
 1120ada:	mov    %r10,%rax
 1120add:	mov    -0x38(%rbp),%r10
 1120ae1:	jb     1120ba0 <sort.block.block__anon_39113+0x3080>
 1120ae7:	lea    (%r10,%rdx,2),%r8
 1120aeb:	mov    %rax,%r10
 1120aee:	and    $0xfffffffffffffffe,%r10
 1120af2:	movzwl (%r10,%r8,1),%r8d
 1120af7:	shl    $0x4,%r8d
 1120afb:	cmp    %r12,(%rcx,%r8,1)
 1120aff:	jne    1120b0d <sort.block.block__anon_39113+0x2fed>
 1120b01:	add    %rcx,%r8
 1120b04:	movzwl 0xe(%r8),%r8d
 1120b09:	cmp    (%rdi),%r8w
 1120b0d:	setb   %r8b
 1120b11:	mov    %rax,%r10
 1120b14:	shr    %r10
 1120b17:	test   %r8b,%r8b
 1120b1a:	je     1120ad0 <sort.block.block__anon_39113+0x2fb0>
 1120b1c:	mov    %eax,%r8d
 1120b1f:	and    $0x1,%r8d
 1120b23:	add    %r10,%r8
 1120b26:	jmp    1120ad3 <sort.block.block__anon_39113+0x2fb3>
 1120b28:	nopl   0x0(%rax,%rax,1)
 1120b30:	mov    %r15,%rdx
 1120b33:	mov    -0x38(%rbp),%r10
 1120b37:	mov    -0x98(%rbp),%r13
 1120b3e:	jmp    1120b4f <sort.block.block__anon_39113+0x302f>
 1120b40:	xor    %r8d,%r8d
 1120b43:	add    %r8,%rdx
 1120b46:	cmp    $0x1,%r14
 1120b4a:	mov    %rax,%r14
 1120b4d:	jbe    1120ba0 <sort.block.block__anon_39113+0x3080>
 1120b4f:	lea    (%r10,%rdx,2),%rax
 1120b53:	mov    %r14,%r8
 1120b56:	and    $0xfffffffffffffffe,%r8
 1120b5a:	movzwl (%r8,%rax,1),%eax
 1120b5f:	shl    $0x4,%eax
 1120b62:	cmp    %rbx,(%rcx,%rax,1)
 1120b66:	jne    1120b73 <sort.block.block__anon_39113+0x3053>
 1120b68:	add    %rcx,%rax
 1120b6b:	movzwl 0xe(%rax),%eax
 1120b6f:	cmp    0xe(%rdi),%ax
 1120b73:	setb   %r8b
 1120b77:	mov    %r14,%rax
 1120b7a:	shr    %rax
 1120b7d:	test   %r8b,%r8b
 1120b80:	je     1120b40 <sort.block.block__anon_39113+0x3020>
 1120b82:	mov    %r14d,%r8d
 1120b85:	and    $0x1,%r8d
 1120b89:	add    %rax,%r8
 1120b8c:	add    %r8,%rdx
 1120b8f:	cmp    $0x1,%r14
 1120b93:	mov    %rax,%r14
 1120b96:	ja     1120b4f <sort.block.block__anon_39113+0x302f>
 1120b98:	nopl   0x0(%rax,%rax,1)
 1120ba0:	cmp    %r15,%rdx
 1120ba3:	je     1120bbf <sort.block.block__anon_39113+0x309f>
 1120ba5:	inc    %r9
 1120ba8:	dec    %rdx
 1120bab:	mov    %rdx,%r11
 1120bae:	cmp    -0x40(%rbp),%r9
 1120bb2:	jne    1120a00 <sort.block.block__anon_39113+0x2ee0>
 1120bb8:	mov    -0x40(%rbp),%r9
 1120bbc:	mov    %rdx,%r11
 1120bbf:	mov    -0xb8(%rbp),%rdx
 1120bc6:	mov    -0x68(%rbp),%r8
 1120bca:	cmp    %r8,%r9
 1120bcd:	jbe    1120c40 <sort.block.block__anon_39113+0x3120>
 1120bcf:	mov    -0x90(%rbp),%rdi
 1120bd6:	mov    %r11,(%rdi)
 1120bd9:	mov    -0xa0(%rbp),%rax
 1120be0:	mov    %rax,0x8(%rdi)
 1120be4:	mov    %r9,0x10(%rdi)
 1120be8:	mov    -0xa8(%rbp),%rcx
 1120bef:	mov    %rcx,0x18(%rdi)
 1120bf3:	mov    %rax,0x20(%rdi)
 1120bf7:	mov    -0xe0(%rbp),%rax
 1120bfe:	cmp    %rax,%r9
 1120c01:	je     1120d5b <sort.block.block__anon_39113+0x323b>
 1120c07:	cmp    %rax,-0x40(%rbp)
 1120c0b:	jne    1120cb0 <sort.block.block__anon_39113+0x3190>
 1120c11:	mov    -0xa0(%rbp),%rdi
 1120c18:	mov    %rdi,%rax
 1120c1b:	sub    %r9,%rax
 1120c1e:	mov    %rax,-0xd0(%rbp)
 1120c25:	mov    $0x1,%r12d
 1120c2b:	mov    -0x88(%rbp),%rax
 1120c32:	mov    %rax,-0x40(%rbp)
 1120c36:	jmp    1120cee <sort.block.block__anon_39113+0x31ce>
 1120c3b:	nopl   0x0(%rax,%rax,1)
 1120c40:	mov    $0x1,%r12d
 1120c46:	cmpb   $0x0,-0x70(%rbp)
 1120c4a:	je     112060a <sort.block.block__anon_39113+0x2aea>
 1120c50:	mov    -0xb0(%rbp),%rax
 1120c57:	sub    -0xd0(%rbp),%rax
 1120c5e:	cmp    %rax,%r9
 1120c61:	jbe    1120607 <sort.block.block__anon_39113+0x2ae7>
 1120c67:	mov    -0xa0(%rbp),%rdi
 1120c6e:	mov    %rdi,%rax
 1120c71:	sub    %r9,%rax
 1120c74:	mov    %rax,-0xd0(%rbp)
 1120c7b:	mov    %r11,-0x1a0(%rbp)
 1120c82:	mov    %rdi,-0x198(%rbp)
 1120c89:	mov    %r9,-0x190(%rbp)
 1120c90:	mov    -0xa8(%rbp),%rax
 1120c97:	mov    %rax,-0x188(%rbp)
 1120c9e:	mov    %rdi,-0x180(%rbp)
 1120ca5:	xor    %r12d,%r12d
 1120ca8:	jmp    1120cee <sort.block.block__anon_39113+0x31ce>
 1120caa:	nopw   0x0(%rax,%rax,1)
 1120cb0:	cmp    $0x200,%rsi
 1120cb7:	jbe    1120da0 <sort.block.block__anon_39113+0x3280>
 1120cbd:	testb  $0x1,-0xc0(%rbp)
 1120cc4:	je     112701e <sort.block.block__anon_39113+0x94fe>
 1120cca:	mov    -0xa0(%rbp),%rdi
 1120cd1:	mov    %rdi,%rax
 1120cd4:	sub    %r9,%rax
 1120cd7:	mov    %rax,-0xd0(%rbp)
 1120cde:	mov    $0x1,%r12d
 1120ce4:	movl   $0x0,-0xc0(%rbp)
 1120cee:	mov    %rdi,-0xb0(%rbp)
 1120cf5:	mov    -0x78(%rbp),%rax
 1120cf9:	mov    -0x60(%rbp),%r9
 1120cfd:	sub    %rax,%r9
 1120d00:	cmp    -0x118(%rbp),%rdi
 1120d07:	jb     1120629 <sort.block.block__anon_39113+0x2b09>
 1120d0d:	jmp    1120dc0 <sort.block.block__anon_39113+0x32a0>
 1120d12:	mov    -0xd8(%rbp),%rcx
 1120d19:	or     $0x1,%rcx
 1120d1d:	mov    %rcx,-0xb8(%rbp)
 1120d24:	mov    -0x98(%rbp),%r13
 1120d2b:	jmp    111f8fb <sort.block.block__anon_39113+0x1ddb>
 1120d30:	mov    -0x88(%rbp),%rsi
 1120d37:	add    %rdi,%rsi
 1120d3a:	add    %rdi,%rcx
 1120d3d:	mov    %rdi,-0xd0(%rbp)
 1120d44:	mov    %rsi,-0xb0(%rbp)
 1120d4b:	mov    %rsi,-0xa8(%rbp)
 1120d52:	mov    %rcx,-0xa0(%rbp)
 1120d59:	jmp    1120dd6 <sort.block.block__anon_39113+0x32b6>
 1120d5b:	mov    %rax,%rsi
 1120d5e:	mov    -0xa0(%rbp),%rcx
 1120d65:	mov    %rcx,%rax
 1120d68:	sub    %rsi,%rax
 1120d6b:	mov    %rax,-0xd0(%rbp)
 1120d72:	sub    -0x88(%rbp),%rcx
 1120d79:	mov    %rcx,-0xb0(%rbp)
 1120d80:	mov    %rcx,-0xa8(%rbp)
 1120d87:	jmp    1120dd6 <sort.block.block__anon_39113+0x32b6>
 1120d89:	mov    -0xa8(%rbp),%rax
 1120d90:	mov    %rax,-0xd0(%rbp)
 1120d97:	mov    %r9,-0xb0(%rbp)
 1120d9e:	jmp    1120dc0 <sort.block.block__anon_39113+0x32a0>
 1120da0:	mov    -0xa0(%rbp),%rcx
 1120da7:	mov    %rcx,%rax
 1120daa:	sub    %r9,%rax
 1120dad:	mov    %rax,-0xd0(%rbp)
 1120db4:	mov    %rcx,-0xb0(%rbp)
 1120dbb:	nopl   0x0(%rax,%rax,1)
 1120dc0:	movq   $0x0,-0xa8(%rbp)
 1120dcb:	movq   $0x0,-0xa0(%rbp)
 1120dd6:	mov    $0x1,%sil
 1120dd9:	lea    -0x1a0(%rbp),%rdi
 1120de0:	jmp    1120e21 <sort.block.block__anon_39113+0x3301>
 1120de2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120df0:	mov    -0x100(%rbp),%rax
 1120df7:	mov    %r9,(%rax)
 1120dfa:	mov    -0x38(%rbp),%r10
 1120dfe:	mov    -0xb8(%rbp),%rdx
 1120e05:	mov    -0xe8(%rbp),%esi
 1120e0b:	lea    -0x178(%rbp),%rdi
 1120e12:	test   $0x1,%sil
 1120e16:	mov    $0x0,%esi
 1120e1b:	je     1122600 <sort.block.block__anon_39113+0x4ae0>
 1120e21:	mov    0x10(%rdi),%r11
 1120e25:	mov    (%rdi),%r9
 1120e28:	cmp    %r9,0x8(%rdi)
 1120e2c:	mov    %r11,-0x40(%rbp)
 1120e30:	jae    1121a10 <sort.block.block__anon_39113+0x3ef0>
 1120e36:	cmp    $0x2,%r11
 1120e3a:	jb     1120e0b <sort.block.block__anon_39113+0x32eb>
 1120e3c:	mov    %esi,-0xe8(%rbp)
 1120e42:	mov    %rdi,-0x100(%rbp)
 1120e49:	mov    0x8(%rdi),%r12
 1120e4d:	mov    $0x1,%r15d
 1120e53:	mov    $0xffffffffffffffff,%r14
 1120e5a:	mov    -0x80(%rbp),%rax
 1120e5e:	mov    %rax,-0x90(%rbp)
 1120e65:	mov    %r10,-0x60(%rbp)
 1120e69:	mov    -0x208(%rbp),%rax
 1120e70:	mov    %rax,-0x78(%rbp)
 1120e74:	mov    -0x210(%rbp),%rax
 1120e7b:	mov    %rax,-0xe0(%rbp)
 1120e82:	mov    %r13,-0xc0(%rbp)
 1120e89:	mov    -0x48(%rbp),%rax
 1120e8d:	mov    %rax,-0x70(%rbp)
 1120e91:	mov    -0x58(%rbp),%rax
 1120e95:	mov    %rax,-0x68(%rbp)
 1120e99:	mov    %r9,%r10
 1120e9c:	mov    %r12,-0x88(%rbp)
 1120ea3:	jmp    1120ef0 <sort.block.block__anon_39113+0x33d0>
 1120ea5:	data16 cs nopw 0x0(%rax,%rax,1)
 1120eb0:	lea    (%r10,%r15,1),%r9
 1120eb4:	inc    %r15
 1120eb7:	dec    %r14
 1120eba:	addq   $0xfffffffffffffffe,-0x68(%rbp)
 1120ebf:	addq   $0xfffffffffffffffe,-0x70(%rbp)
 1120ec4:	addq   $0xfffffffffffffffe,-0xc0(%rbp)
 1120ecc:	addq   $0x2,-0xe0(%rbp)
 1120ed4:	addq   $0x2,-0x78(%rbp)
 1120ed9:	addq   $0xfffffffffffffffe,-0x60(%rbp)
 1120ede:	addq   $0xfffffffffffffffe,-0x90(%rbp)
 1120ee6:	cmp    -0x40(%rbp),%r15
 1120eea:	je     1120df0 <sort.block.block__anon_39113+0x32d0>
 1120ef0:	mov    %r10,%rcx
 1120ef3:	mov    %r9,%rbx
 1120ef6:	sub    %r15,%rbx
 1120ef9:	inc    %rbx
 1120efc:	mov    %rbx,%rax
 1120eff:	mov    %r12,%r10
 1120f02:	sub    %r12,%rax
 1120f05:	je     1121090 <sort.block.block__anon_39113+0x3570>
 1120f0b:	mov    -0x40(%rbp),%rsi
 1120f0f:	sub    %r15,%rsi
 1120f12:	mov    -0x98(%rbp),%r8
 1120f19:	movzwl (%r8,%rcx,2),%ecx
 1120f1e:	mov    %rax,%rdx
 1120f21:	or     %rsi,%rdx
 1120f24:	shr    $0x20,%rdx
 1120f28:	je     1120f31 <sort.block.block__anon_39113+0x3411>
 1120f2a:	xor    %edx,%edx
 1120f2c:	div    %rsi
 1120f2f:	jmp    1120f35 <sort.block.block__anon_39113+0x3415>
 1120f31:	xor    %edx,%edx
 1120f33:	div    %esi
 1120f35:	cmp    $0x1,%rax
 1120f39:	adc    $0x0,%rax
 1120f3d:	lea    (%rax,%r12,1),%rdi
 1120f41:	mov    -0x30(%rbp),%rdx
 1120f45:	mov    (%rdx),%rsi
 1120f48:	mov    %ecx,%r11d
 1120f4b:	shl    $0x4,%r11d
 1120f4f:	add    %rsi,%r11
 1120f52:	mov    %rbx,%r10
 1120f55:	jmp    1120f7f <sort.block.block__anon_39113+0x345f>
 1120f57:	nopw   0x0(%rax,%rax,1)
 1120f60:	add    %rsi,%r8
 1120f63:	movzwl 0xe(%r8),%r8d
 1120f68:	cmp    0xe(%r11),%r8w
 1120f6d:	jb     1120fa9 <sort.block.block__anon_39113+0x3489>
 1120f6f:	cmp    %rdi,%r10
 1120f72:	mov    -0x98(%rbp),%r8
 1120f79:	jb     112101d <sort.block.block__anon_39113+0x34fd>
 1120f7f:	sub    %rax,%r10
 1120f82:	mov    %r10,%rdx
 1120f85:	sub    %r12,%rdx
 1120f88:	jbe    1120fa6 <sort.block.block__anon_39113+0x3486>
 1120f8a:	movzwl (%r8,%r10,2),%r8d
 1120f8f:	shl    $0x4,%r8d
 1120f93:	mov    (%rsi,%r8,1),%r13
 1120f97:	mov    (%r11),%rbx
 1120f9a:	cmp    %rbx,%r13
 1120f9d:	je     1120f60 <sort.block.block__anon_39113+0x3440>
 1120f9f:	jae    1120f6f <sort.block.block__anon_39113+0x344f>
 1120fa1:	mov    %rbx,%r13
 1120fa4:	jmp    1120fa9 <sort.block.block__anon_39113+0x3489>
 1120fa6:	mov    (%r11),%r13
 1120fa9:	shl    $0x4,%ecx
 1120fac:	add    %rsi,%rcx
 1120faf:	add    $0xe,%rcx
 1120fb3:	jmp    1120fd2 <sort.block.block__anon_39113+0x34b2>
 1120fb5:	data16 cs nopw 0x0(%rax,%rax,1)
 1120fc0:	xor    %edi,%edi
 1120fc2:	add    %rdi,%r10
 1120fc5:	cmp    $0x2,%rax
 1120fc9:	mov    %rdx,%rax
 1120fcc:	jb     1121090 <sort.block.block__anon_39113+0x3570>
 1120fd2:	mov    -0x38(%rbp),%rdx
 1120fd6:	lea    (%rdx,%r10,2),%rdx
 1120fda:	mov    %rax,%rdi
 1120fdd:	and    $0xfffffffffffffffe,%rdi
 1120fe1:	movzwl (%rdi,%rdx,1),%edx
 1120fe5:	shl    $0x4,%edx
 1120fe8:	cmp    %r13,(%rsi,%rdx,1)
 1120fec:	jne    1120ff8 <sort.block.block__anon_39113+0x34d8>
 1120fee:	add    %rsi,%rdx
 1120ff1:	movzwl 0xe(%rdx),%edx
 1120ff5:	cmp    (%rcx),%dx
 1120ff8:	setb   %dil
 1120ffc:	mov    %rax,%rdx
 1120fff:	shr    %rdx
 1121002:	test   %dil,%dil
 1121005:	je     1120fc0 <sort.block.block__anon_39113+0x34a0>
 1121007:	mov    %eax,%edi
 1121009:	and    $0x1,%edi
 112100c:	add    %rdx,%rdi
 112100f:	add    %rdi,%r10
 1121012:	cmp    $0x2,%rax
 1121016:	mov    %rdx,%rax
 1121019:	jae    1120fd2 <sort.block.block__anon_39113+0x34b2>
 112101b:	jmp    1121090 <sort.block.block__anon_39113+0x3570>
 112101d:	mov    %r12,%r10
 1121020:	jmp    112103e <sort.block.block__anon_39113+0x351e>
 1121022:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121030:	xor    %ecx,%ecx
 1121032:	add    %rcx,%r10
 1121035:	cmp    $0x1,%rdx
 1121039:	mov    %rax,%rdx
 112103c:	jbe    1121090 <sort.block.block__anon_39113+0x3570>
 112103e:	mov    -0x38(%rbp),%rax
 1121042:	lea    (%rax,%r10,2),%rax
 1121046:	mov    %rdx,%rcx
 1121049:	and    $0xfffffffffffffffe,%rcx
 112104d:	movzwl (%rcx,%rax,1),%eax
 1121051:	shl    $0x4,%eax
 1121054:	cmp    %rbx,(%rsi,%rax,1)
 1121058:	jne    1121066 <sort.block.block__anon_39113+0x3546>
 112105a:	add    %rsi,%rax
 112105d:	movzwl 0xe(%rax),%eax
 1121061:	cmp    0xe(%r11),%ax
 1121066:	setb   %cl
 1121069:	mov    %rdx,%rax
 112106c:	shr    %rax
 112106f:	test   %cl,%cl
 1121071:	je     1121030 <sort.block.block__anon_39113+0x3510>
 1121073:	mov    %edx,%ecx
 1121075:	and    $0x1,%ecx
 1121078:	add    %rax,%rcx
 112107b:	add    %rcx,%r10
 112107e:	cmp    $0x1,%rdx
 1121082:	mov    %rax,%rdx
 1121085:	ja     112103e <sort.block.block__anon_39113+0x351e>
 1121087:	nopw   0x0(%rax,%rax,1)
 1121090:	mov    %r9,%rax
 1121093:	sub    %r10,%rax
 1121096:	mov    %rax,%rcx
 1121099:	sub    %r15,%rcx
 112109c:	mov    %rcx,%rsi
 112109f:	shr    %rsi
 11210a2:	cmp    $0x20,%rcx
 11210a6:	setb   %cl
 11210a9:	cmp    $0xf,%rsi
 11210ad:	sete   %dl
 11210b0:	or     %cl,%dl
 11210b2:	je     11210d0 <sort.block.block__anon_39113+0x35b0>
 11210b4:	xor    %r11d,%r11d
 11210b7:	mov    -0x98(%rbp),%r13
 11210be:	jmp    112127f <sort.block.block__anon_39113+0x375f>
 11210c3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11210d0:	lea    -0x10(%rsi),%rcx
 11210d4:	cmp    $0x30,%rcx
 11210d8:	jae    11210f0 <sort.block.block__anon_39113+0x35d0>
 11210da:	xor    %r11d,%r11d
 11210dd:	jmp    11211e9 <sort.block.block__anon_39113+0x36c9>
 11210e2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11210f0:	mov    -0x1d8(%rbp),%rdx
 11210f7:	lea    (%rdx,%r10,2),%rdx
 11210fb:	lea    (%r9,%r14,1),%rbx
 11210ff:	sub    %r10,%rbx
 1121102:	shr    %rbx
 1121105:	add    $0xfffffffffffffff0,%rbx
 1121109:	shr    $0x4,%rbx
 112110d:	inc    %rbx
 1121110:	and    $0xfffffffffffffffc,%rbx
 1121114:	mov    -0x68(%rbp),%rdi
 1121118:	lea    (%rdi,%r9,2),%rdi
 112111c:	xor    %r11d,%r11d
 112111f:	nop
 1121120:	vmovdqu (%rdi,%r11,2),%ymm0
 1121126:	vmovdqu -0x60(%rdx),%ymm1
 112112b:	vpshufb %ymm2,%ymm1,%ymm1
 1121130:	vpermq $0x4e,%ymm1,%ymm1
 1121136:	vmovdqu %ymm1,(%rdi,%r11,2)
 112113c:	vpshufb %ymm2,%ymm0,%ymm0
 1121141:	vpermq $0x4e,%ymm0,%ymm0
 1121147:	vmovdqu %ymm0,-0x60(%rdx)
 112114c:	vmovdqu -0x20(%rdi,%r11,2),%ymm0
 1121153:	vmovdqu -0x40(%rdx),%ymm1
 1121158:	vpshufb %ymm2,%ymm1,%ymm1
 112115d:	vpermq $0x4e,%ymm1,%ymm1
 1121163:	vmovdqu %ymm1,-0x20(%rdi,%r11,2)
 112116a:	vpshufb %ymm2,%ymm0,%ymm0
 112116f:	vpermq $0x4e,%ymm0,%ymm0
 1121175:	vmovdqu %ymm0,-0x40(%rdx)
 112117a:	vmovdqu -0x40(%rdi,%r11,2),%ymm0
 1121181:	vmovdqu -0x20(%rdx),%ymm1
 1121186:	vpshufb %ymm2,%ymm1,%ymm1
 112118b:	vpermq $0x4e,%ymm1,%ymm1
 1121191:	vmovdqu %ymm1,-0x40(%rdi,%r11,2)
 1121198:	vpshufb %ymm2,%ymm0,%ymm0
 112119d:	vpermq $0x4e,%ymm0,%ymm0
 11211a3:	vmovdqu %ymm0,-0x20(%rdx)
 11211a8:	vmovdqu -0x60(%rdi,%r11,2),%ymm0
 11211af:	vmovdqu (%rdx),%ymm1
 11211b3:	vpshufb %ymm2,%ymm1,%ymm1
 11211b8:	vpermq $0x4e,%ymm1,%ymm1
 11211be:	vmovdqu %ymm1,-0x60(%rdi,%r11,2)
 11211c5:	vpshufb %ymm2,%ymm0,%ymm0
 11211ca:	vpermq $0x4e,%ymm0,%ymm0
 11211d0:	vmovdqu %ymm0,(%rdx)
 11211d4:	sub    $0xffffffffffffff80,%rdx
 11211d8:	add    $0xffffffffffffffc0,%r11
 11211dc:	add    $0xfffffffffffffffc,%rbx
 11211e0:	jne    1121120 <sort.block.block__anon_39113+0x3600>
 11211e6:	neg    %r11
 11211e9:	mov    -0x98(%rbp),%r13
 11211f0:	shr    $0x4,%rcx
 11211f4:	inc    %rcx
 11211f7:	test   $0x3,%cl
 11211fa:	je     112127f <sort.block.block__anon_39113+0x375f>
 1121200:	mov    -0x68(%rbp),%rcx
 1121204:	lea    (%rcx,%r9,2),%rdx
 1121208:	mov    %r11,%rcx
 112120b:	neg    %rcx
 112120e:	add    %r11,%r11
 1121211:	lea    (%r11,%r10,2),%rdi
 1121215:	add    -0x138(%rbp),%rdi
 112121c:	lea    (%r9,%r14,1),%r8d
 1121220:	sub    %r10d,%r8d
 1121223:	shr    %r8b
 1121226:	add    $0xf0,%r8b
 112122a:	shr    $0x4,%r8b
 112122e:	inc    %r8b
 1121231:	movzbl %r8b,%r8d
 1121235:	and    $0x3,%r8d
 1121239:	shl    $0x5,%r8d
 112123d:	xor    %r11d,%r11d
 1121240:	vmovdqu (%rdx,%rcx,2),%ymm0
 1121245:	vmovdqu (%rdi,%r11,1),%ymm1
 112124b:	vpshufb %ymm2,%ymm1,%ymm1
 1121250:	vpermq $0x4e,%ymm1,%ymm1
 1121256:	vmovdqu %ymm1,(%rdx,%rcx,2)
 112125b:	vpshufb %ymm2,%ymm0,%ymm0
 1121260:	vpermq $0x4e,%ymm0,%ymm0
 1121266:	vmovdqu %ymm0,(%rdi,%r11,1)
 112126c:	add    $0xfffffffffffffff0,%rcx
 1121270:	add    $0x20,%r11
 1121274:	cmp    %r11,%r8
 1121277:	jne    1121240 <sort.block.block__anon_39113+0x3720>
 1121279:	neg    %rcx
 112127c:	mov    %rcx,%r11
 112127f:	mov    %r11,%rcx
 1121282:	sub    %rsi,%rcx
 1121285:	jae    11213ed <sort.block.block__anon_39113+0x38cd>
 112128b:	sub    %r11d,%esi
 112128e:	test   $0x3,%sil
 1121292:	je     1121308 <sort.block.block__anon_39113+0x37e8>
 1121294:	lea    (%r11,%r11,1),%rsi
 1121298:	mov    -0x70(%rbp),%rdx
 112129c:	lea    (%rdx,%r9,2),%rdx
 11212a0:	sub    %rsi,%rdx
 11212a3:	lea    (%rsi,%r10,2),%rsi
 11212a7:	add    -0x1c0(%rbp),%rsi
 11212ae:	lea    (%r9,%r14,1),%edi
 11212b2:	sub    %r10d,%edi
 11212b5:	shr    %dil
 11212b8:	sub    %r11b,%dil
 11212bb:	movzbl %dil,%edi
 11212bf:	and    $0x3,%edi
 11212c2:	neg    %rdi
 11212c5:	xor    %r8d,%r8d
 11212c8:	nopl   0x0(%rax,%rax,1)
 11212d0:	movzbl -0x1(%rsi),%ebx
 11212d4:	movzbl -0x1(%rdx,%r8,2),%r13d
 11212da:	mov    %r13b,-0x1(%rsi)
 11212de:	mov    %bl,-0x1(%rdx,%r8,2)
 11212e3:	movzbl (%rsi),%ebx
 11212e6:	movzbl (%rdx,%r8,2),%r13d
 11212eb:	mov    %r13b,(%rsi)
 11212ee:	mov    %bl,(%rdx,%r8,2)
 11212f2:	dec    %r8
 11212f5:	add    $0x2,%rsi
 11212f9:	cmp    %r8,%rdi
 11212fc:	jne    11212d0 <sort.block.block__anon_39113+0x37b0>
 11212fe:	sub    %r8,%r11
 1121301:	mov    -0x98(%rbp),%r13
 1121308:	cmp    $0xfffffffffffffffc,%rcx
 112130c:	ja     11213ed <sort.block.block__anon_39113+0x38cd>
 1121312:	mov    -0x1b0(%rbp),%rcx
 1121319:	lea    (%rcx,%r10,2),%rcx
 112131d:	lea    (%r9,%r14,1),%rdx
 1121321:	mov    -0x38(%rbp),%rsi
 1121325:	lea    (%rsi,%rdx,2),%rsi
 1121329:	sub    %r11,%rsi
 112132c:	sub    %r11,%rsi
 112132f:	sub    %r10,%rdx
 1121332:	shr    %rdx
 1121335:	data16 cs nopw 0x0(%rax,%rax,1)
 1121340:	movzbl -0x7(%rcx,%r11,2),%edi
 1121346:	movzbl (%rsi),%r8d
 112134a:	mov    %r8b,-0x7(%rcx,%r11,2)
 112134f:	mov    %dil,(%rsi)
 1121352:	movzbl -0x6(%rcx,%r11,2),%edi
 1121358:	movzbl 0x1(%rsi),%r8d
 112135d:	mov    %r8b,-0x6(%rcx,%r11,2)
 1121362:	mov    %dil,0x1(%rsi)
 1121366:	movzbl -0x5(%rcx,%r11,2),%edi
 112136c:	movzbl -0x2(%rsi),%r8d
 1121371:	mov    %r8b,-0x5(%rcx,%r11,2)
 1121376:	mov    %dil,-0x2(%rsi)
 112137a:	movzbl -0x4(%rcx,%r11,2),%edi
 1121380:	movzbl -0x1(%rsi),%r8d
 1121385:	mov    %r8b,-0x4(%rcx,%r11,2)
 112138a:	mov    %dil,-0x1(%rsi)
 112138e:	movzbl -0x3(%rcx,%r11,2),%edi
 1121394:	movzbl -0x4(%rsi),%r8d
 1121399:	mov    %r8b,-0x3(%rcx,%r11,2)
 112139e:	mov    %dil,-0x4(%rsi)
 11213a2:	movzbl -0x2(%rcx,%r11,2),%edi
 11213a8:	movzbl -0x3(%rsi),%r8d
 11213ad:	mov    %r8b,-0x2(%rcx,%r11,2)
 11213b2:	mov    %dil,-0x3(%rsi)
 11213b6:	movzbl -0x1(%rcx,%r11,2),%edi
 11213bc:	movzbl -0x6(%rsi),%r8d
 11213c1:	mov    %r8b,-0x1(%rcx,%r11,2)
 11213c6:	mov    %dil,-0x6(%rsi)
 11213ca:	movzbl (%rcx,%r11,2),%edi
 11213cf:	movzbl -0x5(%rsi),%r8d
 11213d4:	mov    %r8b,(%rcx,%r11,2)
 11213d8:	mov    %dil,-0x5(%rsi)
 11213dc:	add    $0x4,%r11
 11213e0:	add    $0xfffffffffffffff8,%rsi
 11213e4:	cmp    %r11,%rdx
 11213e7:	jne    1121340 <sort.block.block__anon_39113+0x3820>
 11213ed:	mov    %r15,%r11
 11213f0:	shr    %r11
 11213f3:	cmp    $0x20,%r15
 11213f7:	setb   %cl
 11213fa:	cmp    $0xf,%r11
 11213fe:	sete   %dl
 1121401:	or     %cl,%dl
 1121403:	je     1121410 <sort.block.block__anon_39113+0x38f0>
 1121405:	xor    %r8d,%r8d
 1121408:	jmp    112159c <sort.block.block__anon_39113+0x3a7c>
 112140d:	nopl   (%rax)
 1121410:	lea    -0x10(%r11),%rsi
 1121414:	mov    %rsi,%rcx
 1121417:	shr    $0x4,%rcx
 112141b:	lea    0x1(%rcx),%rdx
 112141f:	cmp    $0x30,%rsi
 1121423:	jae    1121430 <sort.block.block__anon_39113+0x3910>
 1121425:	xor    %r8d,%r8d
 1121428:	jmp    112152b <sort.block.block__anon_39113+0x3a0b>
 112142d:	nopl   (%rax)
 1121430:	mov    %rdx,%rbx
 1121433:	and    $0xfffffffffffffffc,%rbx
 1121437:	mov    -0xc0(%rbp),%rsi
 112143e:	lea    (%rsi,%r9,2),%r13
 1121442:	lea    (%r9,%r14,1),%rsi
 1121446:	mov    -0xe0(%rbp),%rdi
 112144d:	lea    (%rdi,%rsi,2),%rdi
 1121451:	xor    %esi,%esi
 1121453:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121460:	vmovdqu 0x20(%rdi),%ymm0
 1121465:	vmovdqu 0x2(%r13,%rsi,2),%ymm1
 112146c:	vpshufb %ymm2,%ymm1,%ymm1
 1121471:	vpermq $0x4e,%ymm1,%ymm1
 1121477:	vmovdqu %ymm1,0x20(%rdi)
 112147c:	vpshufb %ymm2,%ymm0,%ymm0
 1121481:	vpermq $0x4e,%ymm0,%ymm0
 1121487:	vmovdqu %ymm0,0x2(%r13,%rsi,2)
 112148e:	vmovdqu (%rdi),%ymm0
 1121492:	vmovdqu 0x22(%r13,%rsi,2),%ymm1
 1121499:	vpshufb %ymm2,%ymm1,%ymm1
 112149e:	vpermq $0x4e,%ymm1,%ymm1
 11214a4:	vmovdqu %ymm1,(%rdi)
 11214a8:	vpshufb %ymm2,%ymm0,%ymm0
 11214ad:	vpermq $0x4e,%ymm0,%ymm0
 11214b3:	vmovdqu %ymm0,0x22(%r13,%rsi,2)
 11214ba:	vmovdqu -0x20(%rdi),%ymm0
 11214bf:	vmovdqu 0x42(%r13,%rsi,2),%ymm1
 11214c6:	vpshufb %ymm2,%ymm1,%ymm1
 11214cb:	vpermq $0x4e,%ymm1,%ymm1
 11214d1:	vmovdqu %ymm1,-0x20(%rdi)
 11214d6:	vpshufb %ymm2,%ymm0,%ymm0
 11214db:	vpermq $0x4e,%ymm0,%ymm0
 11214e1:	vmovdqu %ymm0,0x42(%r13,%rsi,2)
 11214e8:	lea    0x40(%rsi),%r8
 11214ec:	vmovdqu -0x40(%rdi),%ymm0
 11214f1:	vmovdqu 0x62(%r13,%rsi,2),%ymm1
 11214f8:	vpshufb %ymm2,%ymm1,%ymm1
 11214fd:	vpermq $0x4e,%ymm1,%ymm1
 1121503:	vmovdqu %ymm1,-0x40(%rdi)
 1121508:	vpshufb %ymm2,%ymm0,%ymm0
 112150d:	vpermq $0x4e,%ymm0,%ymm0
 1121513:	vmovdqu %ymm0,0x62(%r13,%rsi,2)
 112151a:	add    $0xffffffffffffff80,%rdi
 112151e:	mov    %r8,%rsi
 1121521:	add    $0xfffffffffffffffc,%rbx
 1121525:	jne    1121460 <sort.block.block__anon_39113+0x3940>
 112152b:	test   $0x3,%dl
 112152e:	mov    -0x98(%rbp),%r13
 1121535:	je     112159c <sort.block.block__anon_39113+0x3a7c>
 1121537:	inc    %cl
 1121539:	movzbl %cl,%ecx
 112153c:	and    $0x3,%ecx
 112153f:	shl    $0x5,%ecx
 1121542:	lea    (%r9,%r14,1),%rdx
 1121546:	mov    -0x78(%rbp),%rsi
 112154a:	lea    (%rsi,%rdx,2),%rdx
 112154e:	lea    (%r9,%r9,1),%rsi
 1121552:	lea    (%rsi,%r8,2),%rsi
 1121556:	neg    %r8
 1121559:	add    -0x60(%rbp),%rsi
 112155d:	xor    %edi,%edi
 112155f:	nop
 1121560:	vmovdqu (%rdx,%r8,2),%ymm0
 1121566:	vmovdqu (%rsi,%rdi,1),%ymm1
 112156b:	vpshufb %ymm2,%ymm1,%ymm1
 1121570:	vpermq $0x4e,%ymm1,%ymm1
 1121576:	vmovdqu %ymm1,(%rdx,%r8,2)
 112157c:	vpshufb %ymm2,%ymm0,%ymm0
 1121581:	vpermq $0x4e,%ymm0,%ymm0
 1121587:	vmovdqu %ymm0,(%rsi,%rdi,1)
 112158c:	add    $0xfffffffffffffff0,%r8
 1121590:	add    $0x20,%rdi
 1121594:	cmp    %rdi,%rcx
 1121597:	jne    1121560 <sort.block.block__anon_39113+0x3a40>
 1121599:	neg    %r8
 112159c:	mov    %r8,%rcx
 112159f:	sub    %r11,%rcx
 11215a2:	jae    1121705 <sort.block.block__anon_39113+0x3be5>
 11215a8:	mov    %r11d,%edx
 11215ab:	sub    %r8d,%edx
 11215ae:	test   $0x3,%dl
 11215b1:	je     1121634 <sort.block.block__anon_39113+0x3b14>
 11215b7:	mov    -0x50(%rbp),%rdx
 11215bb:	lea    (%rdx,%r9,2),%rdx
 11215bf:	sub    %r8,%rdx
 11215c2:	sub    %r8,%rdx
 11215c5:	mov    %r14,%r12
 11215c8:	lea    (%r9,%r14,1),%rsi
 11215cc:	add    %rsi,%rsi
 11215cf:	lea    (%rsi,%r8,2),%rsi
 11215d3:	add    -0x1c0(%rbp),%rsi
 11215da:	mov    %r11d,%edi
 11215dd:	sub    %r8b,%dil
 11215e0:	movzbl %dil,%edi
 11215e4:	and    $0x3,%edi
 11215e7:	neg    %rdi
 11215ea:	xor    %ebx,%ebx
 11215ec:	nopl   0x0(%rax)
 11215f0:	movzbl -0x1(%rsi),%r13d
 11215f5:	movzbl -0x1(%rdx,%rbx,2),%r14d
 11215fb:	mov    %r14b,-0x1(%rsi)
 11215ff:	mov    %r13b,-0x1(%rdx,%rbx,2)
 1121604:	movzbl (%rsi),%r14d
 1121608:	movzbl (%rdx,%rbx,2),%r13d
 112160d:	mov    %r13b,(%rsi)
 1121610:	mov    %r14b,(%rdx,%rbx,2)
 1121614:	dec    %rbx
 1121617:	add    $0x2,%rsi
 112161b:	cmp    %rbx,%rdi
 112161e:	jne    11215f0 <sort.block.block__anon_39113+0x3ad0>
 1121620:	sub    %rbx,%r8
 1121623:	mov    -0x98(%rbp),%r13
 112162a:	mov    %r12,%r14
 112162d:	mov    -0x88(%rbp),%r12
 1121634:	cmp    $0xfffffffffffffffc,%rcx
 1121638:	ja     1121705 <sort.block.block__anon_39113+0x3be5>
 112163e:	mov    -0x90(%rbp),%rcx
 1121645:	lea    (%rcx,%r9,2),%rcx
 1121649:	mov    -0x38(%rbp),%rdx
 112164d:	lea    (%rdx,%r9,2),%rdx
 1121651:	sub    %r8,%rdx
 1121654:	sub    %r8,%rdx
 1121657:	nopw   0x0(%rax,%rax,1)
 1121660:	movzbl -0x7(%rcx,%r8,2),%esi
 1121666:	movzbl (%rdx),%edi
 1121669:	mov    %dil,-0x7(%rcx,%r8,2)
 112166e:	mov    %sil,(%rdx)
 1121671:	movzbl -0x6(%rcx,%r8,2),%esi
 1121677:	movzbl 0x1(%rdx),%edi
 112167b:	mov    %dil,-0x6(%rcx,%r8,2)
 1121680:	mov    %sil,0x1(%rdx)
 1121684:	movzbl -0x5(%rcx,%r8,2),%esi
 112168a:	movzbl -0x2(%rdx),%edi
 112168e:	mov    %dil,-0x5(%rcx,%r8,2)
 1121693:	mov    %sil,-0x2(%rdx)
 1121697:	movzbl -0x4(%rcx,%r8,2),%esi
 112169d:	movzbl -0x1(%rdx),%edi
 11216a1:	mov    %dil,-0x4(%rcx,%r8,2)
 11216a6:	mov    %sil,-0x1(%rdx)
 11216aa:	movzbl -0x3(%rcx,%r8,2),%esi
 11216b0:	movzbl -0x4(%rdx),%edi
 11216b4:	mov    %dil,-0x3(%rcx,%r8,2)
 11216b9:	mov    %sil,-0x4(%rdx)
 11216bd:	movzbl -0x2(%rcx,%r8,2),%esi
 11216c3:	movzbl -0x3(%rdx),%edi
 11216c7:	mov    %dil,-0x2(%rcx,%r8,2)
 11216cc:	mov    %sil,-0x3(%rdx)
 11216d0:	movzbl -0x1(%rcx,%r8,2),%esi
 11216d6:	movzbl -0x6(%rdx),%edi
 11216da:	mov    %dil,-0x1(%rcx,%r8,2)
 11216df:	mov    %sil,-0x6(%rdx)
 11216e3:	movzbl (%rcx,%r8,2),%esi
 11216e8:	movzbl -0x5(%rdx),%edi
 11216ec:	mov    %dil,(%rcx,%r8,2)
 11216f0:	mov    %sil,-0x5(%rdx)
 11216f4:	add    $0x4,%r8
 11216f8:	add    $0xfffffffffffffff8,%rdx
 11216fc:	cmp    %r8,%r11
 11216ff:	jne    1121660 <sort.block.block__anon_39113+0x3b40>
 1121705:	mov    %rax,%r11
 1121708:	shr    %r11
 112170b:	cmp    $0x20,%rax
 112170f:	setb   %al
 1121712:	cmp    $0xf,%r11
 1121716:	sete   %cl
 1121719:	or     %al,%cl
 112171b:	je     1121730 <sort.block.block__anon_39113+0x3c10>
 112171d:	xor    %eax,%eax
 112171f:	jmp    11218bd <sort.block.block__anon_39113+0x3d9d>
 1121724:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121730:	lea    -0x10(%r11),%rax
 1121734:	mov    %rax,%rsi
 1121737:	shr    $0x4,%rsi
 112173b:	inc    %rsi
 112173e:	cmp    $0x30,%rax
 1121742:	jae    1121760 <sort.block.block__anon_39113+0x3c40>
 1121744:	xor    %eax,%eax
 1121746:	and    $0x3,%esi
 1121749:	jne    1121856 <sort.block.block__anon_39113+0x3d36>
 112174f:	jmp    11218bd <sort.block.block__anon_39113+0x3d9d>
 1121754:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121760:	mov    %rsi,%rcx
 1121763:	movabs $0x1ffffffffffffffc,%rax
 112176d:	and    %rax,%rcx
 1121770:	mov    -0x1d8(%rbp),%rax
 1121777:	lea    (%rax,%r10,2),%rdx
 112177b:	mov    -0x1b8(%rbp),%rax
 1121782:	lea    (%rax,%r9,2),%rdi
 1121786:	xor    %eax,%eax
 1121788:	nopl   0x0(%rax,%rax,1)
 1121790:	vmovdqu (%rdi,%rax,2),%ymm0
 1121795:	vmovdqu -0x60(%rdx),%ymm1
 112179a:	vpshufb %ymm2,%ymm1,%ymm1
 112179f:	vpermq $0x4e,%ymm1,%ymm1
 11217a5:	vmovdqu %ymm1,(%rdi,%rax,2)
 11217aa:	vpshufb %ymm2,%ymm0,%ymm0
 11217af:	vpermq $0x4e,%ymm0,%ymm0
 11217b5:	vmovdqu %ymm0,-0x60(%rdx)
 11217ba:	vmovdqu -0x20(%rdi,%rax,2),%ymm0
 11217c0:	vmovdqu -0x40(%rdx),%ymm1
 11217c5:	vpshufb %ymm2,%ymm1,%ymm1
 11217ca:	vpermq $0x4e,%ymm1,%ymm1
 11217d0:	vmovdqu %ymm1,-0x20(%rdi,%rax,2)
 11217d6:	vpshufb %ymm2,%ymm0,%ymm0
 11217db:	vpermq $0x4e,%ymm0,%ymm0
 11217e1:	vmovdqu %ymm0,-0x40(%rdx)
 11217e6:	vmovdqu -0x40(%rdi,%rax,2),%ymm0
 11217ec:	vmovdqu -0x20(%rdx),%ymm1
 11217f1:	vpshufb %ymm2,%ymm1,%ymm1
 11217f6:	vpermq $0x4e,%ymm1,%ymm1
 11217fc:	vmovdqu %ymm1,-0x40(%rdi,%rax,2)
 1121802:	vpshufb %ymm2,%ymm0,%ymm0
 1121807:	vpermq $0x4e,%ymm0,%ymm0
 112180d:	vmovdqu %ymm0,-0x20(%rdx)
 1121812:	vmovdqu -0x60(%rdi,%rax,2),%ymm0
 1121818:	vmovdqu (%rdx),%ymm1
 112181c:	vpshufb %ymm2,%ymm1,%ymm1
 1121821:	vpermq $0x4e,%ymm1,%ymm1
 1121827:	vmovdqu %ymm1,-0x60(%rdi,%rax,2)
 112182d:	vpshufb %ymm2,%ymm0,%ymm0
 1121832:	vpermq $0x4e,%ymm0,%ymm0
 1121838:	vmovdqu %ymm0,(%rdx)
 112183c:	sub    $0xffffffffffffff80,%rdx
 1121840:	add    $0xffffffffffffffc0,%rax
 1121844:	add    $0xfffffffffffffffc,%rcx
 1121848:	jne    1121790 <sort.block.block__anon_39113+0x3c70>
 112184e:	neg    %rax
 1121851:	and    $0x3,%esi
 1121854:	je     11218bd <sort.block.block__anon_39113+0x3d9d>
 1121856:	mov    -0x1b8(%rbp),%rcx
 112185d:	lea    (%rcx,%r9,2),%rdx
 1121861:	mov    %rax,%rcx
 1121864:	neg    %rcx
 1121867:	add    %rax,%rax
 112186a:	lea    (%rax,%r10,2),%rax
 112186e:	add    -0x138(%rbp),%rax
 1121875:	shl    $0x5,%esi
 1121878:	xor    %edi,%edi
 112187a:	nopw   0x0(%rax,%rax,1)
 1121880:	vmovdqu (%rdx,%rcx,2),%ymm0
 1121885:	vmovdqu (%rax,%rdi,1),%ymm1
 112188a:	vpshufb %ymm2,%ymm1,%ymm1
 112188f:	vpermq $0x4e,%ymm1,%ymm1
 1121895:	vmovdqu %ymm1,(%rdx,%rcx,2)
 112189a:	vpshufb %ymm2,%ymm0,%ymm0
 112189f:	vpermq $0x4e,%ymm0,%ymm0
 11218a5:	vmovdqu %ymm0,(%rax,%rdi,1)
 11218aa:	add    $0xfffffffffffffff0,%rcx
 11218ae:	add    $0x20,%rdi
 11218b2:	cmp    %rdi,%rsi
 11218b5:	jne    1121880 <sort.block.block__anon_39113+0x3d60>
 11218b7:	neg    %rcx
 11218ba:	mov    %rcx,%rax
 11218bd:	mov    %rax,%rcx
 11218c0:	sub    %r11,%rcx
 11218c3:	jae    1120eb0 <sort.block.block__anon_39113+0x3390>
 11218c9:	mov    %r11d,%edx
 11218cc:	sub    %eax,%edx
 11218ce:	and    $0x3,%edx
 11218d1:	je     112193b <sort.block.block__anon_39113+0x3e1b>
 11218d3:	mov    %r14,%r12
 11218d6:	lea    (%rax,%rax,1),%rdi
 11218da:	mov    -0x50(%rbp),%rsi
 11218de:	lea    (%rsi,%r9,2),%rsi
 11218e2:	sub    %rdi,%rsi
 11218e5:	lea    (%rdi,%r10,2),%rdi
 11218e9:	add    -0x1c0(%rbp),%rdi
 11218f0:	neg    %rdx
 11218f3:	xor    %r8d,%r8d
 11218f6:	cs nopw 0x0(%rax,%rax,1)
 1121900:	movzbl -0x1(%rdi),%ebx
 1121904:	movzbl -0x1(%rsi,%r8,2),%r14d
 112190a:	mov    %r14b,-0x1(%rdi)
 112190e:	mov    %bl,-0x1(%rsi,%r8,2)
 1121913:	movzbl (%rdi),%ebx
 1121916:	movzbl (%rsi,%r8,2),%r14d
 112191b:	mov    %r14b,(%rdi)
 112191e:	mov    %bl,(%rsi,%r8,2)
 1121922:	dec    %r8
 1121925:	add    $0x2,%rdi
 1121929:	cmp    %r8,%rdx
 112192c:	jne    1121900 <sort.block.block__anon_39113+0x3de0>
 112192e:	sub    %r8,%rax
 1121931:	mov    %r12,%r14
 1121934:	mov    -0x88(%rbp),%r12
 112193b:	cmp    $0xfffffffffffffffc,%rcx
 112193f:	ja     1120eb0 <sort.block.block__anon_39113+0x3390>
 1121945:	mov    -0x1b0(%rbp),%rcx
 112194c:	lea    (%rcx,%r10,2),%rcx
 1121950:	mov    -0x38(%rbp),%rdx
 1121954:	lea    (%rdx,%r9,2),%rdx
 1121958:	sub    %rax,%rdx
 112195b:	sub    %rax,%rdx
 112195e:	xchg   %ax,%ax
 1121960:	movzbl -0x7(%rcx,%rax,2),%esi
 1121965:	movzbl (%rdx),%edi
 1121968:	mov    %dil,-0x7(%rcx,%rax,2)
 112196d:	mov    %sil,(%rdx)
 1121970:	movzbl -0x6(%rcx,%rax,2),%esi
 1121975:	movzbl 0x1(%rdx),%edi
 1121979:	mov    %dil,-0x6(%rcx,%rax,2)
 112197e:	mov    %sil,0x1(%rdx)
 1121982:	movzbl -0x5(%rcx,%rax,2),%esi
 1121987:	movzbl -0x2(%rdx),%edi
 112198b:	mov    %dil,-0x5(%rcx,%rax,2)
 1121990:	mov    %sil,-0x2(%rdx)
 1121994:	movzbl -0x4(%rcx,%rax,2),%esi
 1121999:	movzbl -0x1(%rdx),%edi
 112199d:	mov    %dil,-0x4(%rcx,%rax,2)
 11219a2:	mov    %sil,-0x1(%rdx)
 11219a6:	movzbl -0x3(%rcx,%rax,2),%esi
 11219ab:	movzbl -0x4(%rdx),%edi
 11219af:	mov    %dil,-0x3(%rcx,%rax,2)
 11219b4:	mov    %sil,-0x4(%rdx)
 11219b8:	movzbl -0x2(%rcx,%rax,2),%esi
 11219bd:	movzbl -0x3(%rdx),%edi
 11219c1:	mov    %dil,-0x2(%rcx,%rax,2)
 11219c6:	mov    %sil,-0x3(%rdx)
 11219ca:	movzbl -0x1(%rcx,%rax,2),%esi
 11219cf:	movzbl -0x6(%rdx),%edi
 11219d3:	mov    %dil,-0x1(%rcx,%rax,2)
 11219d8:	mov    %sil,-0x6(%rdx)
 11219dc:	movzbl (%rcx,%rax,2),%esi
 11219e0:	movzbl -0x5(%rdx),%edi
 11219e4:	mov    %dil,(%rcx,%rax,2)
 11219e8:	mov    %sil,-0x5(%rdx)
 11219ec:	add    $0x4,%rax
 11219f0:	add    $0xfffffffffffffff8,%rdx
 11219f4:	cmp    %rax,%r11
 11219f7:	jne    1121960 <sort.block.block__anon_39113+0x3e40>
 11219fd:	jmp    1120eb0 <sort.block.block__anon_39113+0x3390>
 1121a02:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121a10:	seta   %al
 1121a13:	cmp    $0x2,%r11
 1121a17:	setae  %cl
 1121a1a:	test   %cl,%al
 1121a1c:	je     1120e0b <sort.block.block__anon_39113+0x32eb>
 1121a22:	mov    %esi,-0xe8(%rbp)
 1121a28:	lea    0x1(%r9),%r14
 1121a2c:	mov    %rdi,-0x100(%rbp)
 1121a33:	mov    0x8(%rdi),%rax
 1121a37:	mov    %rax,-0x68(%rbp)
 1121a3b:	mov    $0x1,%esi
 1121a40:	mov    $0xfffffffffffffffe,%rdi
 1121a47:	mov    -0x218(%rbp),%rax
 1121a4e:	mov    %rax,-0x90(%rbp)
 1121a55:	mov    -0x138(%rbp),%rax
 1121a5c:	mov    %rax,-0x60(%rbp)
 1121a60:	mov    -0x220(%rbp),%rax
 1121a67:	mov    %rax,-0xe0(%rbp)
 1121a6e:	mov    %r13,-0xc0(%rbp)
 1121a75:	mov    %r10,-0x70(%rbp)
 1121a79:	mov    -0x1b8(%rbp),%rax
 1121a80:	mov    %rax,-0x78(%rbp)
 1121a84:	mov    -0x228(%rbp),%rax
 1121a8b:	mov    %rax,-0x88(%rbp)
 1121a92:	mov    %r9,%r8
 1121a95:	jmp    1121ae8 <sort.block.block__anon_39113+0x3fc8>
 1121a97:	nopw   0x0(%rax,%rax,1)
 1121aa0:	sub    %rsi,%r9
 1121aa3:	inc    %rsi
 1121aa6:	addq   $0x2,-0x88(%rbp)
 1121aae:	addq   $0x2,-0x78(%rbp)
 1121ab3:	addq   $0x2,-0x70(%rbp)
 1121ab8:	addq   $0x2,-0xc0(%rbp)
 1121ac0:	dec    %rdi
 1121ac3:	addq   $0x2,-0xe0(%rbp)
 1121acb:	addq   $0x2,-0x60(%rbp)
 1121ad0:	addq   $0x2,-0x90(%rbp)
 1121ad8:	mov    %r9,%r8
 1121adb:	mov    -0x40(%rbp),%r11
 1121adf:	cmp    %r11,%rsi
 1121ae2:	je     1120df0 <sort.block.block__anon_39113+0x32d0>
 1121ae8:	mov    -0x68(%rbp),%rax
 1121aec:	sub    %r14,%rax
 1121aef:	jne    1121b00 <sort.block.block__anon_39113+0x3fe0>
 1121af1:	mov    -0x38(%rbp),%r10
 1121af5:	jmp    1121c70 <sort.block.block__anon_39113+0x4150>
 1121afa:	nopw   0x0(%rax,%rax,1)
 1121b00:	mov    %r11,%r9
 1121b03:	sub    %rsi,%r9
 1121b06:	mov    -0x38(%rbp),%r10
 1121b0a:	movzwl (%r10,%r14,2),%ecx
 1121b0f:	mov    %rax,%rdx
 1121b12:	or     %r9,%rdx
 1121b15:	shr    $0x20,%rdx
 1121b19:	je     1121b22 <sort.block.block__anon_39113+0x4002>
 1121b1b:	xor    %edx,%edx
 1121b1d:	div    %r9
 1121b20:	jmp    1121b27 <sort.block.block__anon_39113+0x4007>
 1121b22:	xor    %edx,%edx
 1121b24:	div    %r9d
 1121b27:	cmp    $0x1,%rax
 1121b2b:	adc    $0x0,%rax
 1121b2f:	mov    -0x30(%rbp),%rdx
 1121b33:	mov    (%rdx),%rdx
 1121b36:	shl    $0x4,%ecx
 1121b39:	lea    (%rdx,%rcx,1),%r9
 1121b3d:	mov    (%rdx,%rcx,1),%r11
 1121b41:	mov    -0x68(%rbp),%rbx
 1121b45:	sub    %rax,%rbx
 1121b48:	jmp    1121b5e <sort.block.block__anon_39113+0x403e>
 1121b4a:	nopw   0x0(%rax,%rax,1)
 1121b50:	jb     1121ba8 <sort.block.block__anon_39113+0x4088>
 1121b52:	mov    %rcx,%r14
 1121b55:	cmp    %rbx,%rcx
 1121b58:	jae    1121bf0 <sort.block.block__anon_39113+0x40d0>
 1121b5e:	lea    (%r14,%rax,1),%rcx
 1121b62:	movzwl 0x0(%r13,%rcx,2),%r15d
 1121b68:	shl    $0x4,%r15d
 1121b6c:	cmp    (%rdx,%r15,1),%r11
 1121b70:	jne    1121b50 <sort.block.block__anon_39113+0x4030>
 1121b72:	add    %rdx,%r15
 1121b75:	movzwl 0xe(%r9),%r12d
 1121b7a:	cmp    0xe(%r15),%r12w
 1121b7f:	jae    1121b52 <sort.block.block__anon_39113+0x4032>
 1121b81:	jmp    1121ba8 <sort.block.block__anon_39113+0x4088>
 1121b83:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121b90:	mov    %eax,%ebx
 1121b92:	and    $0x1,%ebx
 1121b95:	add    %rcx,%rbx
 1121b98:	add    %rbx,%r14
 1121b9b:	cmp    $0x2,%rax
 1121b9f:	mov    %rcx,%rax
 1121ba2:	jb     1121c70 <sort.block.block__anon_39113+0x4150>
 1121ba8:	lea    (%r10,%r14,2),%rcx
 1121bac:	mov    %rax,%rbx
 1121baf:	and    $0xfffffffffffffffe,%rbx
 1121bb3:	movzwl (%rbx,%rcx,1),%ecx
 1121bb7:	shl    $0x4,%ecx
 1121bba:	cmp    (%rdx,%rcx,1),%r11
 1121bbe:	jne    1121bcc <sort.block.block__anon_39113+0x40ac>
 1121bc0:	add    %rdx,%rcx
 1121bc3:	movzwl 0xe(%r9),%ebx
 1121bc8:	cmp    0xe(%rcx),%bx
 1121bcc:	setb   %bl
 1121bcf:	mov    %rax,%rcx
 1121bd2:	shr    %rcx
 1121bd5:	test   %bl,%bl
 1121bd7:	je     1121b90 <sort.block.block__anon_39113+0x4070>
 1121bd9:	xor    %ebx,%ebx
 1121bdb:	add    %rbx,%r14
 1121bde:	cmp    $0x2,%rax
 1121be2:	mov    %rcx,%rax
 1121be5:	jae    1121ba8 <sort.block.block__anon_39113+0x4088>
 1121be7:	jmp    1121c70 <sort.block.block__anon_39113+0x4150>
 1121bec:	nopl   0x0(%rax)
 1121bf0:	mov    -0x68(%rbp),%r14
 1121bf4:	mov    %r14,%rax
 1121bf7:	sub    %rcx,%rax
 1121bfa:	jbe    1121c70 <sort.block.block__anon_39113+0x4150>
 1121bfc:	mov    %rcx,%r14
 1121bff:	jmp    1121c24 <sort.block.block__anon_39113+0x4104>
 1121c01:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121c10:	mov    %eax,%ebx
 1121c12:	and    $0x1,%ebx
 1121c15:	add    %rcx,%rbx
 1121c18:	add    %rbx,%r14
 1121c1b:	cmp    $0x1,%rax
 1121c1f:	mov    %rcx,%rax
 1121c22:	jbe    1121c70 <sort.block.block__anon_39113+0x4150>
 1121c24:	lea    (%r10,%r14,2),%rcx
 1121c28:	mov    %rax,%rbx
 1121c2b:	and    $0xfffffffffffffffe,%rbx
 1121c2f:	movzwl (%rbx,%rcx,1),%ecx
 1121c33:	shl    $0x4,%ecx
 1121c36:	cmp    (%rdx,%rcx,1),%r11
 1121c3a:	jne    1121c48 <sort.block.block__anon_39113+0x4128>
 1121c3c:	add    %rdx,%rcx
 1121c3f:	movzwl 0xe(%r9),%ebx
 1121c44:	cmp    0xe(%rcx),%bx
 1121c48:	setb   %bl
 1121c4b:	mov    %rax,%rcx
 1121c4e:	shr    %rcx
 1121c51:	test   %bl,%bl
 1121c53:	je     1121c10 <sort.block.block__anon_39113+0x40f0>
 1121c55:	xor    %ebx,%ebx
 1121c57:	add    %rbx,%r14
 1121c5a:	cmp    $0x1,%rax
 1121c5e:	mov    %rcx,%rax
 1121c61:	ja     1121c24 <sort.block.block__anon_39113+0x4104>
 1121c63:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121c70:	mov    %rsi,%rax
 1121c73:	shr    %rax
 1121c76:	cmp    $0x20,%rsi
 1121c7a:	setb   %cl
 1121c7d:	cmp    $0xf,%rax
 1121c81:	sete   %dl
 1121c84:	or     %cl,%dl
 1121c86:	je     1121c90 <sort.block.block__anon_39113+0x4170>
 1121c88:	xor    %edx,%edx
 1121c8a:	jmp    1121e1f <sort.block.block__anon_39113+0x42ff>
 1121c8f:	nop
 1121c90:	lea    -0x10(%rax),%rcx
 1121c94:	mov    %rcx,%r9
 1121c97:	shr    $0x4,%r9
 1121c9b:	lea    0x1(%r9),%r11
 1121c9f:	cmp    $0x30,%rcx
 1121ca3:	jae    1121cc0 <sort.block.block__anon_39113+0x41a0>
 1121ca5:	xor    %edx,%edx
 1121ca7:	test   $0x3,%r11b
 1121cab:	jne    1121daf <sort.block.block__anon_39113+0x428f>
 1121cb1:	jmp    1121e1f <sort.block.block__anon_39113+0x42ff>
 1121cb6:	cs nopw 0x0(%rax,%rax,1)
 1121cc0:	mov    %r11,%rbx
 1121cc3:	and    $0xfffffffffffffffc,%rbx
 1121cc7:	mov    -0xc8(%rbp),%rcx
 1121cce:	lea    (%rcx,%r8,2),%rcx
 1121cd2:	mov    -0x88(%rbp),%rdx
 1121cd9:	lea    (%rdx,%r8,2),%r15
 1121cdd:	xor    %edx,%edx
 1121cdf:	nop
 1121ce0:	vmovdqu 0x20(%r15,%rdx,2),%ymm0
 1121ce7:	vmovdqu -0x60(%rcx),%ymm1
 1121cec:	vpshufb %ymm2,%ymm1,%ymm1
 1121cf1:	vpermq $0x4e,%ymm1,%ymm1
 1121cf7:	vmovdqu %ymm1,0x20(%r15,%rdx,2)
 1121cfe:	vpshufb %ymm2,%ymm0,%ymm0
 1121d03:	vpermq $0x4e,%ymm0,%ymm0
 1121d09:	vmovdqu %ymm0,-0x60(%rcx)
 1121d0e:	vmovdqu (%r15,%rdx,2),%ymm0
 1121d14:	vmovdqu -0x40(%rcx),%ymm1
 1121d19:	vpshufb %ymm2,%ymm1,%ymm1
 1121d1e:	vpermq $0x4e,%ymm1,%ymm1
 1121d24:	vmovdqu %ymm1,(%r15,%rdx,2)
 1121d2a:	vpshufb %ymm2,%ymm0,%ymm0
 1121d2f:	vpermq $0x4e,%ymm0,%ymm0
 1121d35:	vmovdqu %ymm0,-0x40(%rcx)
 1121d3a:	vmovdqu -0x20(%r15,%rdx,2),%ymm0
 1121d41:	vmovdqu -0x20(%rcx),%ymm1
 1121d46:	vpshufb %ymm2,%ymm1,%ymm1
 1121d4b:	vpermq $0x4e,%ymm1,%ymm1
 1121d51:	vmovdqu %ymm1,-0x20(%r15,%rdx,2)
 1121d58:	vpshufb %ymm2,%ymm0,%ymm0
 1121d5d:	vpermq $0x4e,%ymm0,%ymm0
 1121d63:	vmovdqu %ymm0,-0x20(%rcx)
 1121d68:	vmovdqu -0x40(%r15,%rdx,2),%ymm0
 1121d6f:	vmovdqu (%rcx),%ymm1
 1121d73:	vpshufb %ymm2,%ymm1,%ymm1
 1121d78:	vpermq $0x4e,%ymm1,%ymm1
 1121d7e:	vmovdqu %ymm1,-0x40(%r15,%rdx,2)
 1121d85:	vpshufb %ymm2,%ymm0,%ymm0
 1121d8a:	vpermq $0x4e,%ymm0,%ymm0
 1121d90:	vmovdqu %ymm0,(%rcx)
 1121d94:	sub    $0xffffffffffffff80,%rcx
 1121d98:	add    $0xffffffffffffffc0,%rdx
 1121d9c:	add    $0xfffffffffffffffc,%rbx
 1121da0:	jne    1121ce0 <sort.block.block__anon_39113+0x41c0>
 1121da6:	neg    %rdx
 1121da9:	test   $0x3,%r11b
 1121dad:	je     1121e1f <sort.block.block__anon_39113+0x42ff>
 1121daf:	inc    %r9b
 1121db2:	movzbl %r9b,%ecx
 1121db6:	and    $0x3,%ecx
 1121db9:	shl    $0x5,%ecx
 1121dbc:	mov    -0x78(%rbp),%r9
 1121dc0:	lea    (%r9,%r8,2),%r11
 1121dc4:	mov    %rdx,%r9
 1121dc7:	neg    %r9
 1121dca:	add    %rdx,%rdx
 1121dcd:	lea    (%rdx,%r8,2),%rdx
 1121dd1:	add    %r10,%rdx
 1121dd4:	xor    %ebx,%ebx
 1121dd6:	cs nopw 0x0(%rax,%rax,1)
 1121de0:	vmovdqu (%r11,%r9,2),%ymm0
 1121de6:	vmovdqu (%rdx,%rbx,1),%ymm1
 1121deb:	vpshufb %ymm2,%ymm1,%ymm1
 1121df0:	vpermq $0x4e,%ymm1,%ymm1
 1121df6:	vmovdqu %ymm1,(%r11,%r9,2)
 1121dfc:	vpshufb %ymm2,%ymm0,%ymm0
 1121e01:	vpermq $0x4e,%ymm0,%ymm0
 1121e07:	vmovdqu %ymm0,(%rdx,%rbx,1)
 1121e0c:	add    $0xfffffffffffffff0,%r9
 1121e10:	add    $0x20,%rbx
 1121e14:	cmp    %rbx,%rcx
 1121e17:	jne    1121de0 <sort.block.block__anon_39113+0x42c0>
 1121e19:	neg    %r9
 1121e1c:	mov    %r9,%rdx
 1121e1f:	mov    %rdx,%r9
 1121e22:	sub    %rax,%r9
 1121e25:	jae    1121f6d <sort.block.block__anon_39113+0x444d>
 1121e2b:	mov    %eax,%ecx
 1121e2d:	sub    %edx,%ecx
 1121e2f:	test   $0x3,%cl
 1121e32:	je     1121e93 <sort.block.block__anon_39113+0x4373>
 1121e34:	mov    %eax,%ecx
 1121e36:	sub    %dl,%cl
 1121e38:	movzbl %cl,%ecx
 1121e3b:	and    $0x3,%ecx
 1121e3e:	neg    %rcx
 1121e41:	lea    (%r8,%r8,1),%rbx
 1121e45:	mov    -0x70(%rbp),%r10
 1121e49:	lea    (%r10,%r8,2),%r11
 1121e4d:	sub    %rdx,%r11
 1121e50:	sub    %rdx,%r11
 1121e53:	lea    (%rbx,%rdx,2),%rbx
 1121e57:	add    -0x50(%rbp),%rbx
 1121e5b:	xor    %r15d,%r15d
 1121e5e:	xchg   %ax,%ax
 1121e60:	movzbl -0x1(%rbx),%r12d
 1121e65:	movzbl (%r11,%r15,2),%r10d
 1121e6a:	mov    %r10b,-0x1(%rbx)
 1121e6e:	mov    %r12b,(%r11,%r15,2)
 1121e72:	movzbl (%rbx),%r10d
 1121e76:	movzbl 0x1(%r11,%r15,2),%r12d
 1121e7c:	mov    %r12b,(%rbx)
 1121e7f:	mov    %r10b,0x1(%r11,%r15,2)
 1121e84:	dec    %r15
 1121e87:	add    $0x2,%rbx
 1121e8b:	cmp    %r15,%rcx
 1121e8e:	jne    1121e60 <sort.block.block__anon_39113+0x4340>
 1121e90:	sub    %r15,%rdx
 1121e93:	cmp    $0xfffffffffffffffc,%r9
 1121e97:	ja     1121f6d <sort.block.block__anon_39113+0x444d>
 1121e9d:	mov    -0x80(%rbp),%rcx
 1121ea1:	lea    (%rcx,%r8,2),%rcx
 1121ea5:	mov    -0xc0(%rbp),%r9
 1121eac:	lea    (%r9,%r8,2),%r9
 1121eb0:	sub    %rdx,%r9
 1121eb3:	sub    %rdx,%r9
 1121eb6:	cs nopw 0x0(%rax,%rax,1)
 1121ec0:	movzbl -0x7(%rcx,%rdx,2),%r10d
 1121ec6:	movzbl 0x2(%r9),%r11d
 1121ecb:	mov    %r11b,-0x7(%rcx,%rdx,2)
 1121ed0:	mov    %r10b,0x2(%r9)
 1121ed4:	movzbl -0x6(%rcx,%rdx,2),%r10d
 1121eda:	movzbl 0x3(%r9),%r11d
 1121edf:	mov    %r11b,-0x6(%rcx,%rdx,2)
 1121ee4:	mov    %r10b,0x3(%r9)
 1121ee8:	movzbl -0x5(%rcx,%rdx,2),%r10d
 1121eee:	movzbl (%r9),%r11d
 1121ef2:	mov    %r11b,-0x5(%rcx,%rdx,2)
 1121ef7:	mov    %r10b,(%r9)
 1121efa:	movzbl -0x4(%rcx,%rdx,2),%r10d
 1121f00:	movzbl 0x1(%r9),%r11d
 1121f05:	mov    %r11b,-0x4(%rcx,%rdx,2)
 1121f0a:	mov    %r10b,0x1(%r9)
 1121f0e:	movzbl -0x3(%rcx,%rdx,2),%r10d
 1121f14:	movzbl -0x2(%r9),%r11d
 1121f19:	mov    %r11b,-0x3(%rcx,%rdx,2)
 1121f1e:	mov    %r10b,-0x2(%r9)
 1121f22:	movzbl -0x2(%rcx,%rdx,2),%r10d
 1121f28:	movzbl -0x1(%r9),%r11d
 1121f2d:	mov    %r11b,-0x2(%rcx,%rdx,2)
 1121f32:	mov    %r10b,-0x1(%r9)
 1121f36:	movzbl -0x1(%rcx,%rdx,2),%r10d
 1121f3c:	movzbl -0x4(%r9),%r11d
 1121f41:	mov    %r11b,-0x1(%rcx,%rdx,2)
 1121f46:	mov    %r10b,-0x4(%r9)
 1121f4a:	movzbl (%rcx,%rdx,2),%r10d
 1121f4f:	movzbl -0x3(%r9),%r11d
 1121f54:	mov    %r11b,(%rcx,%rdx,2)
 1121f58:	mov    %r10b,-0x3(%r9)
 1121f5c:	add    $0x4,%rdx
 1121f60:	add    $0xfffffffffffffff8,%r9
 1121f64:	cmp    %rdx,%rax
 1121f67:	jne    1121ec0 <sort.block.block__anon_39113+0x43a0>
 1121f6d:	lea    -0x1(%r14),%r9
 1121f71:	mov    %r9,%rax
 1121f74:	sub    %r8,%rax
 1121f77:	mov    %rax,%rcx
 1121f7a:	sub    %rsi,%rcx
 1121f7d:	mov    %rcx,%r11
 1121f80:	shr    %r11
 1121f83:	cmp    $0x20,%rcx
 1121f87:	setb   %cl
 1121f8a:	cmp    $0xf,%r11
 1121f8e:	sete   %dl
 1121f91:	or     %cl,%dl
 1121f93:	je     1121fa0 <sort.block.block__anon_39113+0x4480>
 1121f95:	xor    %edx,%edx
 1121f97:	jmp    112216f <sort.block.block__anon_39113+0x464f>
 1121f9c:	nopl   0x0(%rax)
 1121fa0:	lea    -0x10(%r11),%r15
 1121fa4:	cmp    $0x30,%r15
 1121fa8:	jae    1121fd0 <sort.block.block__anon_39113+0x44b0>
 1121faa:	xor    %edx,%edx
 1121fac:	shr    $0x4,%r15
 1121fb0:	inc    %r15
 1121fb3:	test   $0x3,%r15b
 1121fb7:	jne    11220f2 <sort.block.block__anon_39113+0x45d2>
 1121fbd:	jmp    112216f <sort.block.block__anon_39113+0x464f>
 1121fc2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121fd0:	lea    (%r14,%rdi,1),%rbx
 1121fd4:	sub    %r8,%rbx
 1121fd7:	shr    %rbx
 1121fda:	add    $0xfffffffffffffff0,%rbx
 1121fde:	shr    $0x4,%rbx
 1121fe2:	inc    %rbx
 1121fe5:	and    $0xfffffffffffffffc,%rbx
 1121fe9:	mov    -0x250(%rbp),%rcx
 1121ff0:	lea    (%rcx,%r14,2),%rcx
 1121ff4:	mov    -0xe0(%rbp),%rdx
 1121ffb:	lea    (%rdx,%r8,2),%r12
 1121fff:	xor    %edx,%edx
 1122001:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122010:	vmovdqu 0x20(%rcx,%rdx,2),%ymm0
 1122016:	vmovdqu -0x20(%r12),%ymm1
 112201d:	vpshufb %ymm2,%ymm1,%ymm1
 1122022:	vpermq $0x4e,%ymm1,%ymm1
 1122028:	vmovdqu %ymm1,0x20(%rcx,%rdx,2)
 112202e:	vpshufb %ymm2,%ymm0,%ymm0
 1122033:	vpermq $0x4e,%ymm0,%ymm0
 1122039:	vmovdqu %ymm0,-0x20(%r12)
 1122040:	vmovdqu (%rcx,%rdx,2),%ymm0
 1122045:	vmovdqu (%r12),%ymm1
 112204b:	vpshufb %ymm2,%ymm1,%ymm1
 1122050:	vpermq $0x4e,%ymm1,%ymm1
 1122056:	vmovdqu %ymm1,(%rcx,%rdx,2)
 112205b:	vpshufb %ymm2,%ymm0,%ymm0
 1122060:	vpermq $0x4e,%ymm0,%ymm0
 1122066:	vmovdqu %ymm0,(%r12)
 112206c:	vmovdqu -0x20(%rcx,%rdx,2),%ymm0
 1122072:	vmovdqu 0x20(%r12),%ymm1
 1122079:	vpshufb %ymm2,%ymm1,%ymm1
 112207e:	vpermq $0x4e,%ymm1,%ymm1
 1122084:	vmovdqu %ymm1,-0x20(%rcx,%rdx,2)
 112208a:	vpshufb %ymm2,%ymm0,%ymm0
 112208f:	vpermq $0x4e,%ymm0,%ymm0
 1122095:	vmovdqu %ymm0,0x20(%r12)
 112209c:	vmovdqu -0x40(%rcx,%rdx,2),%ymm0
 11220a2:	vmovdqu 0x40(%r12),%ymm1
 11220a9:	vpshufb %ymm2,%ymm1,%ymm1
 11220ae:	vpermq $0x4e,%ymm1,%ymm1
 11220b4:	vmovdqu %ymm1,-0x40(%rcx,%rdx,2)
 11220ba:	vpshufb %ymm2,%ymm0,%ymm0
 11220bf:	vpermq $0x4e,%ymm0,%ymm0
 11220c5:	vmovdqu %ymm0,0x40(%r12)
 11220cc:	add    $0xffffffffffffffc0,%rdx
 11220d0:	sub    $0xffffffffffffff80,%r12
 11220d4:	add    $0xfffffffffffffffc,%rbx
 11220d8:	jne    1122010 <sort.block.block__anon_39113+0x44f0>
 11220de:	neg    %rdx
 11220e1:	shr    $0x4,%r15
 11220e5:	inc    %r15
 11220e8:	test   $0x3,%r15b
 11220ec:	je     112216f <sort.block.block__anon_39113+0x464f>
 11220f2:	lea    (%r14,%rdi,1),%r10
 11220f6:	mov    -0x78(%rbp),%rcx
 11220fa:	lea    (%rcx,%r10,2),%rbx
 11220fe:	mov    %rdx,%rcx
 1122101:	neg    %rcx
 1122104:	add    %rdx,%rdx
 1122107:	lea    (%rdx,%r8,2),%rdx
 112210b:	add    -0x60(%rbp),%rdx
 112210f:	sub    %r8d,%r10d
 1122112:	shr    %r10b
 1122115:	add    $0xf0,%r10b
 1122119:	shr    $0x4,%r10b
 112211d:	inc    %r10b
 1122120:	movzbl %r10b,%r15d
 1122124:	and    $0x3,%r15d
 1122128:	shl    $0x5,%r15d
 112212c:	xor    %r12d,%r12d
 112212f:	nop
 1122130:	vmovdqu (%rbx,%rcx,2),%ymm0
 1122135:	vmovdqu (%rdx,%r12,1),%ymm1
 112213b:	vpshufb %ymm2,%ymm1,%ymm1
 1122140:	vpermq $0x4e,%ymm1,%ymm1
 1122146:	vmovdqu %ymm1,(%rbx,%rcx,2)
 112214b:	vpshufb %ymm2,%ymm0,%ymm0
 1122150:	vpermq $0x4e,%ymm0,%ymm0
 1122156:	vmovdqu %ymm0,(%rdx,%r12,1)
 112215c:	add    $0xfffffffffffffff0,%rcx
 1122160:	add    $0x20,%r12
 1122164:	cmp    %r12,%r15
 1122167:	jne    1122130 <sort.block.block__anon_39113+0x4610>
 1122169:	neg    %rcx
 112216c:	mov    %rcx,%rdx
 112216f:	mov    %rdx,%rbx
 1122172:	sub    %r11,%rbx
 1122175:	jae    11222dd <sort.block.block__anon_39113+0x47bd>
 112217b:	sub    %edx,%r11d
 112217e:	test   $0x3,%r11b
 1122182:	je     11221fa <sort.block.block__anon_39113+0x46da>
 1122184:	mov    -0x148(%rbp),%rcx
 112218b:	lea    (%rcx,%r14,2),%rcx
 112218f:	sub    %rdx,%rcx
 1122192:	sub    %rdx,%rcx
 1122195:	lea    (%r14,%rdi,1),%r10d
 1122199:	sub    %r8d,%r10d
 112219c:	shr    %r10b
 112219f:	sub    %dl,%r10b
 11221a2:	movzbl %r10b,%r11d
 11221a6:	and    $0x3,%r11d
 11221aa:	neg    %r11
 11221ad:	lea    (%r8,%r8,1),%r10
 11221b1:	lea    (%r10,%rdx,2),%r15
 11221b5:	add    -0x60(%rbp),%r15
 11221b9:	xor    %r12d,%r12d
 11221bc:	nopl   0x0(%rax)
 11221c0:	movzbl (%r15),%r10d
 11221c4:	movzbl -0x1(%rcx,%r12,2),%r13d
 11221ca:	mov    %r13b,(%r15)
 11221cd:	mov    %r10b,-0x1(%rcx,%r12,2)
 11221d2:	movzbl 0x1(%r15),%r10d
 11221d7:	movzbl (%rcx,%r12,2),%r13d
 11221dc:	mov    %r13b,0x1(%r15)
 11221e0:	mov    %r10b,(%rcx,%r12,2)
 11221e4:	dec    %r12
 11221e7:	add    $0x2,%r15
 11221eb:	cmp    %r12,%r11
 11221ee:	jne    11221c0 <sort.block.block__anon_39113+0x46a0>
 11221f0:	sub    %r12,%rdx
 11221f3:	mov    -0x98(%rbp),%r13
 11221fa:	cmp    $0xfffffffffffffffc,%rbx
 11221fe:	ja     11222dd <sort.block.block__anon_39113+0x47bd>
 1122204:	lea    (%r14,%rdi,1),%r11
 1122208:	sub    %r8,%r11
 112220b:	shr    %r11
 112220e:	mov    -0x90(%rbp),%rcx
 1122215:	lea    (%rcx,%r8,2),%rcx
 1122219:	mov    -0x148(%rbp),%rbx
 1122220:	lea    (%rbx,%r14,2),%rbx
 1122224:	sub    %rdx,%rbx
 1122227:	sub    %rdx,%rbx
 112222a:	nopw   0x0(%rax,%rax,1)
 1122230:	movzbl -0x2(%rcx,%rdx,2),%r10d
 1122236:	movzbl -0x1(%rbx),%r15d
 112223b:	mov    %r15b,-0x2(%rcx,%rdx,2)
 1122240:	mov    %r10b,-0x1(%rbx)
 1122244:	movzbl -0x1(%rcx,%rdx,2),%r10d
 112224a:	movzbl (%rbx),%r15d
 112224e:	mov    %r15b,-0x1(%rcx,%rdx,2)
 1122253:	mov    %r10b,(%rbx)
 1122256:	movzbl (%rcx,%rdx,2),%r10d
 112225b:	movzbl -0x3(%rbx),%r15d
 1122260:	mov    %r15b,(%rcx,%rdx,2)
 1122264:	mov    %r10b,-0x3(%rbx)
 1122268:	movzbl 0x1(%rcx,%rdx,2),%r10d
 112226e:	movzbl -0x2(%rbx),%r15d
 1122273:	mov    %r15b,0x1(%rcx,%rdx,2)
 1122278:	mov    %r10b,-0x2(%rbx)
 112227c:	movzbl 0x2(%rcx,%rdx,2),%r10d
 1122282:	movzbl -0x5(%rbx),%r15d
 1122287:	mov    %r15b,0x2(%rcx,%rdx,2)
 112228c:	mov    %r10b,-0x5(%rbx)
 1122290:	movzbl 0x3(%rcx,%rdx,2),%r10d
 1122296:	movzbl -0x4(%rbx),%r15d
 112229b:	mov    %r15b,0x3(%rcx,%rdx,2)
 11222a0:	mov    %r10b,-0x4(%rbx)
 11222a4:	movzbl 0x4(%rcx,%rdx,2),%r10d
 11222aa:	movzbl -0x7(%rbx),%r15d
 11222af:	mov    %r15b,0x4(%rcx,%rdx,2)
 11222b4:	mov    %r10b,-0x7(%rbx)
 11222b8:	movzbl 0x5(%rcx,%rdx,2),%r10d
 11222be:	movzbl -0x6(%rbx),%r15d
 11222c3:	mov    %r15b,0x5(%rcx,%rdx,2)
 11222c8:	mov    %r10b,-0x6(%rbx)
 11222cc:	add    $0x4,%rdx
 11222d0:	add    $0xfffffffffffffff8,%rbx
 11222d4:	cmp    %rdx,%r11
 11222d7:	jne    1122230 <sort.block.block__anon_39113+0x4710>
 11222dd:	mov    %rax,%rdx
 11222e0:	shr    %rdx
 11222e3:	cmp    $0x20,%rax
 11222e7:	setb   %al
 11222ea:	cmp    $0xf,%rdx
 11222ee:	sete   %cl
 11222f1:	or     %al,%cl
 11222f3:	je     1122300 <sort.block.block__anon_39113+0x47e0>
 11222f5:	xor    %eax,%eax
 11222f7:	jmp    112249f <sort.block.block__anon_39113+0x497f>
 11222fc:	nopl   0x0(%rax)
 1122300:	lea    -0x10(%rdx),%rax
 1122304:	mov    %rax,%r11
 1122307:	shr    $0x4,%r11
 112230b:	inc    %r11
 112230e:	cmp    $0x30,%rax
 1122312:	mov    -0x38(%rbp),%r10
 1122316:	jae    1122330 <sort.block.block__anon_39113+0x4810>
 1122318:	xor    %eax,%eax
 112231a:	and    $0x3,%r11d
 112231e:	jne    112242f <sort.block.block__anon_39113+0x490f>
 1122324:	jmp    112249f <sort.block.block__anon_39113+0x497f>
 1122329:	nopl   0x0(%rax)
 1122330:	mov    %r11,%rbx
 1122333:	movabs $0x1ffffffffffffffc,%rax
 112233d:	and    %rax,%rbx
 1122340:	mov    -0xc8(%rbp),%rax
 1122347:	lea    (%rax,%r8,2),%rcx
 112234b:	mov    -0x1e0(%rbp),%rax
 1122352:	lea    (%rax,%r14,2),%r15
 1122356:	xor    %eax,%eax
 1122358:	nopl   0x0(%rax,%rax,1)
 1122360:	vmovdqu (%r15,%rax,2),%ymm0
 1122366:	vmovdqu -0x60(%rcx),%ymm1
 112236b:	vpshufb %ymm2,%ymm1,%ymm1
 1122370:	vpermq $0x4e,%ymm1,%ymm1
 1122376:	vmovdqu %ymm1,(%r15,%rax,2)
 112237c:	vpshufb %ymm2,%ymm0,%ymm0
 1122381:	vpermq $0x4e,%ymm0,%ymm0
 1122387:	vmovdqu %ymm0,-0x60(%rcx)
 112238c:	vmovdqu -0x20(%r15,%rax,2),%ymm0
 1122393:	vmovdqu -0x40(%rcx),%ymm1
 1122398:	vpshufb %ymm2,%ymm1,%ymm1
 112239d:	vpermq $0x4e,%ymm1,%ymm1
 11223a3:	vmovdqu %ymm1,-0x20(%r15,%rax,2)
 11223aa:	vpshufb %ymm2,%ymm0,%ymm0
 11223af:	vpermq $0x4e,%ymm0,%ymm0
 11223b5:	vmovdqu %ymm0,-0x40(%rcx)
 11223ba:	vmovdqu -0x40(%r15,%rax,2),%ymm0
 11223c1:	vmovdqu -0x20(%rcx),%ymm1
 11223c6:	vpshufb %ymm2,%ymm1,%ymm1
 11223cb:	vpermq $0x4e,%ymm1,%ymm1
 11223d1:	vmovdqu %ymm1,-0x40(%r15,%rax,2)
 11223d8:	vpshufb %ymm2,%ymm0,%ymm0
 11223dd:	vpermq $0x4e,%ymm0,%ymm0
 11223e3:	vmovdqu %ymm0,-0x20(%rcx)
 11223e8:	vmovdqu -0x60(%r15,%rax,2),%ymm0
 11223ef:	vmovdqu (%rcx),%ymm1
 11223f3:	vpshufb %ymm2,%ymm1,%ymm1
 11223f8:	vpermq $0x4e,%ymm1,%ymm1
 11223fe:	vmovdqu %ymm1,-0x60(%r15,%rax,2)
 1122405:	vpshufb %ymm2,%ymm0,%ymm0
 112240a:	vpermq $0x4e,%ymm0,%ymm0
 1122410:	vmovdqu %ymm0,(%rcx)
 1122414:	sub    $0xffffffffffffff80,%rcx
 1122418:	add    $0xffffffffffffffc0,%rax
 112241c:	add    $0xfffffffffffffffc,%rbx
 1122420:	jne    1122360 <sort.block.block__anon_39113+0x4840>
 1122426:	neg    %rax
 1122429:	and    $0x3,%r11d
 112242d:	je     112249f <sort.block.block__anon_39113+0x497f>
 112242f:	mov    -0x1e0(%rbp),%rcx
 1122436:	lea    (%rcx,%r14,2),%rbx
 112243a:	mov    %rax,%rcx
 112243d:	neg    %rcx
 1122440:	add    %rax,%rax
 1122443:	lea    (%rax,%r8,2),%rax
 1122447:	add    %r10,%rax
 112244a:	shl    $0x5,%r11d
 112244e:	xor    %r15d,%r15d
 1122451:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122460:	vmovdqu (%rbx,%rcx,2),%ymm0
 1122465:	vmovdqu (%rax,%r15,1),%ymm1
 112246b:	vpshufb %ymm2,%ymm1,%ymm1
 1122470:	vpermq $0x4e,%ymm1,%ymm1
 1122476:	vmovdqu %ymm1,(%rbx,%rcx,2)
 112247b:	vpshufb %ymm2,%ymm0,%ymm0
 1122480:	vpermq $0x4e,%ymm0,%ymm0
 1122486:	vmovdqu %ymm0,(%rax,%r15,1)
 112248c:	add    $0xfffffffffffffff0,%rcx
 1122490:	add    $0x20,%r15
 1122494:	cmp    %r15,%r11
 1122497:	jne    1122460 <sort.block.block__anon_39113+0x4940>
 1122499:	neg    %rcx
 112249c:	mov    %rcx,%rax
 112249f:	mov    %rax,%r11
 11224a2:	sub    %rdx,%r11
 11224a5:	jae    1121aa0 <sort.block.block__anon_39113+0x3f80>
 11224ab:	mov    %edx,%ecx
 11224ad:	sub    %eax,%ecx
 11224af:	and    $0x3,%ecx
 11224b2:	je     112251a <sort.block.block__anon_39113+0x49fa>
 11224b4:	mov    -0x148(%rbp),%rbx
 11224bb:	lea    (%rbx,%r14,2),%rbx
 11224bf:	sub    %rax,%rbx
 11224c2:	sub    %rax,%rbx
 11224c5:	lea    (%r8,%r8,1),%r10
 11224c9:	lea    (%r10,%rax,2),%r15
 11224cd:	add    -0x50(%rbp),%r15
 11224d1:	neg    %rcx
 11224d4:	xor    %r12d,%r12d
 11224d7:	nopw   0x0(%rax,%rax,1)
 11224e0:	movzbl -0x1(%r15),%r10d
 11224e5:	movzbl -0x1(%rbx,%r12,2),%r13d
 11224eb:	mov    %r13b,-0x1(%r15)
 11224ef:	mov    %r10b,-0x1(%rbx,%r12,2)
 11224f4:	movzbl (%r15),%r10d
 11224f8:	movzbl (%rbx,%r12,2),%r13d
 11224fd:	mov    %r13b,(%r15)
 1122500:	mov    %r10b,(%rbx,%r12,2)
 1122504:	dec    %r12
 1122507:	add    $0x2,%r15
 112250b:	cmp    %r12,%rcx
 112250e:	jne    11224e0 <sort.block.block__anon_39113+0x49c0>
 1122510:	sub    %r12,%rax
 1122513:	mov    -0x98(%rbp),%r13
 112251a:	cmp    $0xfffffffffffffffc,%r11
 112251e:	ja     1121aa0 <sort.block.block__anon_39113+0x3f80>
 1122524:	mov    -0x80(%rbp),%rcx
 1122528:	lea    (%rcx,%r8,2),%rcx
 112252c:	mov    -0x148(%rbp),%r8
 1122533:	lea    (%r8,%r14,2),%r8
 1122537:	sub    %rax,%r8
 112253a:	sub    %rax,%r8
 112253d:	nopl   (%rax)
 1122540:	movzbl -0x7(%rcx,%rax,2),%r10d
 1122546:	movzbl -0x1(%r8),%r11d
 112254b:	mov    %r11b,-0x7(%rcx,%rax,2)
 1122550:	mov    %r10b,-0x1(%r8)
 1122554:	movzbl -0x6(%rcx,%rax,2),%r10d
 112255a:	movzbl (%r8),%r11d
 112255e:	mov    %r11b,-0x6(%rcx,%rax,2)
 1122563:	mov    %r10b,(%r8)
 1122566:	movzbl -0x5(%rcx,%rax,2),%r10d
 112256c:	movzbl -0x3(%r8),%r11d
 1122571:	mov    %r11b,-0x5(%rcx,%rax,2)
 1122576:	mov    %r10b,-0x3(%r8)
 112257a:	movzbl -0x4(%rcx,%rax,2),%r10d
 1122580:	movzbl -0x2(%r8),%r11d
 1122585:	mov    %r11b,-0x4(%rcx,%rax,2)
 112258a:	mov    %r10b,-0x2(%r8)
 112258e:	movzbl -0x3(%rcx,%rax,2),%r10d
 1122594:	movzbl -0x5(%r8),%r11d
 1122599:	mov    %r11b,-0x3(%rcx,%rax,2)
 112259e:	mov    %r10b,-0x5(%r8)
 11225a2:	movzbl -0x2(%rcx,%rax,2),%r10d
 11225a8:	movzbl -0x4(%r8),%r11d
 11225ad:	mov    %r11b,-0x2(%rcx,%rax,2)
 11225b2:	mov    %r10b,-0x4(%r8)
 11225b6:	movzbl -0x1(%rcx,%rax,2),%r10d
 11225bc:	movzbl -0x7(%r8),%r11d
 11225c1:	mov    %r11b,-0x1(%rcx,%rax,2)
 11225c6:	mov    %r10b,-0x7(%r8)
 11225ca:	movzbl (%rcx,%rax,2),%r10d
 11225cf:	movzbl -0x6(%r8),%r11d
 11225d4:	mov    %r11b,(%rcx,%rax,2)
 11225d8:	mov    %r10b,-0x6(%r8)
 11225dc:	add    $0x4,%rax
 11225e0:	add    $0xfffffffffffffff8,%r8
 11225e4:	cmp    %rax,%rdx
 11225e7:	jne    1122540 <sort.block.block__anon_39113+0x4a20>
 11225ed:	jmp    1121aa0 <sort.block.block__anon_39113+0x3f80>
 11225f2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122600:	mov    -0xb0(%rbp),%rsi
 1122607:	sub    -0xd0(%rbp),%rsi
 112260e:	mov    %rdx,%rax
 1122611:	or     %rsi,%rax
 1122614:	shr    $0x20,%rax
 1122618:	je     112262a <sort.block.block__anon_39113+0x4b0a>
 112261a:	mov    %rdx,%rax
 112261d:	mov    %rdx,%rcx
 1122620:	xor    %edx,%edx
 1122622:	div    %rsi
 1122625:	mov    %rax,%rdi
 1122628:	jmp    1122635 <sort.block.block__anon_39113+0x4b15>
 112262a:	mov    %edx,%eax
 112262c:	mov    %rdx,%rcx
 112262f:	xor    %edx,%edx
 1122631:	div    %esi
 1122633:	mov    %eax,%edi
 1122635:	mov    -0xa0(%rbp),%rax
 112263c:	mov    -0xa8(%rbp),%rsi
 1122643:	lea    0x1(%rdi),%r8
 1122647:	lea    (%r10,%rsi,2),%rdx
 112264b:	mov    %rdx,-0x68(%rbp)
 112264f:	sub    %rsi,%rax
 1122652:	mov    %rax,-0x1e8(%rbp)
 1122659:	setne  %al
 112265c:	cmp    $0x200,%rdi
 1122663:	setb   %dl
 1122666:	or     %al,%dl
 1122668:	mov    %dl,-0x140(%rbp)
 112266e:	mov    %rdi,-0x100(%rbp)
 1122675:	lea    0x2(,%rdi,2),%rax
 112267d:	mov    %rax,-0x238(%rbp)
 1122684:	lea    -0x1(%rcx),%rax
 1122688:	mov    %rax,-0x1f0(%rbp)
 112268f:	mov    %r8d,%eax
 1122692:	and    $0x3,%eax
 1122695:	mov    %rax,-0xb0(%rbp)
 112269c:	mov    %r8,%r9
 112269f:	and    $0xfffffffffffffffc,%r9
 11226a3:	mov    -0x50(%rbp),%rax
 11226a7:	mov    -0xd0(%rbp),%rdx
 11226ae:	lea    (%rax,%rdx,2),%rdx
 11226b2:	mov    %rdx,-0x200(%rbp)
 11226b9:	mov    -0x80(%rbp),%rdx
 11226bd:	lea    (%rdx,%rsi,2),%rdx
 11226c1:	mov    %rdx,-0x1d0(%rbp)
 11226c8:	lea    (%rax,%rsi,2),%rax
 11226cc:	mov    %rax,-0x1a8(%rbp)
 11226d3:	mov    -0x1b0(%rbp),%rax
 11226da:	lea    (%rax,%rsi,2),%rax
 11226de:	mov    %rax,-0x230(%rbp)
 11226e5:	xor    %esi,%esi
 11226e7:	xor    %r11d,%r11d
 11226ea:	mov    %rcx,%rax
 11226ed:	mov    -0xf8(%rbp),%rdx
 11226f4:	mov    %r8,-0x88(%rbp)
 11226fb:	mov    %r9,-0x110(%rbp)
 1122702:	jmp    1122788 <sort.block.block__anon_39113+0x4c68>
 1122707:	nopw   0x0(%rax,%rax,1)
 1122710:	mov    -0xf0(%rbp),%rbx
 1122717:	sub    %r13,%rbx
 112271a:	mov    %r12,%r14
 112271d:	sub    %r13,%r14
 1122720:	mov    %r15,%rdi
 1122723:	mov    %r14,%rsi
 1122726:	vzeroupper 
 1122729:	call   10fd040 <mem.reverse__anon_36385>
 112272e:	mov    -0x38(%rbp),%rax
 1122732:	lea    (%rax,%r12,2),%rdi
 1122736:	mov    %rbx,%rsi
 1122739:	sub    %r14,%rsi
 112273c:	call   10fd040 <mem.reverse__anon_36385>
 1122741:	mov    %r15,%rdi
 1122744:	mov    %rbx,%rsi
 1122747:	call   10fd040 <mem.reverse__anon_36385>
 112274c:	mov    -0x38(%rbp),%r10
 1122750:	vmovdqa -0x11ff38(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1122758:	mov    -0x248(%rbp),%r11
 112275f:	sub    -0x240(%rbp),%r11
 1122766:	mov    -0x130(%rbp),%rsi
 112276d:	cmp    -0x118(%rbp),%rsi
 1122774:	mov    -0xb8(%rbp),%rax
 112277b:	mov    -0xf8(%rbp),%rdx
 1122782:	jae    1125930 <sort.block.block__anon_39113+0x7e10>
 1122788:	mov    %rsi,%rcx
 112278b:	lea    (%rsi,%rax,1),%rbx
 112278f:	add    %rdx,%r11
 1122792:	xor    %esi,%esi
 1122794:	mov    %rax,%rdi
 1122797:	mov    %rdx,%r8
 112279a:	mov    -0x120(%rbp),%rdx
 11227a1:	cmp    %rdx,%r11
 11227a4:	setae  %sil
 11227a8:	mov    $0x0,%eax
 11227ad:	cmovae %rdx,%rax
 11227b1:	sub    %rax,%r11
 11227b4:	add    %rsi,%rbx
 11227b7:	mov    %rbx,%r12
 11227ba:	lea    (%rbx,%rdi,1),%rax
 11227be:	add    %r8,%r11
 11227c1:	mov    %r11,-0x248(%rbp)
 11227c8:	cmp    %rdx,%r11
 11227cb:	mov    $0x0,%edi
 11227d0:	cmovae %rdx,%rdi
 11227d4:	mov    %rdi,-0x240(%rbp)
 11227db:	sbb    $0xffffffffffffffff,%rax
 11227df:	mov    %rcx,%r13
 11227e2:	mov    %rax,-0x130(%rbp)
 11227e9:	mov    %rax,%rdx
 11227ec:	cmp    -0x188(%rbp),%rcx
 11227f3:	jne    1122860 <sort.block.block__anon_39113+0x4d40>
 11227f5:	mov    -0x198(%rbp),%rax
 11227fc:	cmp    %rax,-0x1a0(%rbp)
 1122803:	jbe    1122830 <sort.block.block__anon_39113+0x4d10>
 1122805:	mov    -0x190(%rbp),%r13
 112280c:	add    %rcx,%r13
 112280f:	mov    -0x130(%rbp),%rdx
 1122816:	cmp    %r13,%r12
 1122819:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 112281f:	jmp    1122860 <sort.block.block__anon_39113+0x4d40>
 1122821:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122830:	mov    %rcx,%r13
 1122833:	mov    -0x130(%rbp),%rdx
 112283a:	jae    1122860 <sort.block.block__anon_39113+0x4d40>
 112283c:	mov    -0x130(%rbp),%rdx
 1122843:	sub    -0x190(%rbp),%rdx
 112284a:	mov    %rcx,%r13
 112284d:	cmp    %r12,%rdx
 1122850:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 1122856:	cs nopw 0x0(%rax,%rax,1)
 1122860:	cmp    -0x160(%rbp),%rcx
 1122867:	jne    11228b0 <sort.block.block__anon_39113+0x4d90>
 1122869:	mov    -0x170(%rbp),%rax
 1122870:	cmp    %rax,-0x178(%rbp)
 1122877:	jbe    1122890 <sort.block.block__anon_39113+0x4d70>
 1122879:	add    -0x168(%rbp),%r13
 1122880:	cmp    %r13,%r12
 1122883:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 1122889:	jmp    11228b0 <sort.block.block__anon_39113+0x4d90>
 112288b:	nopl   0x0(%rax,%rax,1)
 1122890:	jae    11228b0 <sort.block.block__anon_39113+0x4d90>
 1122892:	sub    -0x168(%rbp),%rdx
 1122899:	cmp    %r12,%rdx
 112289c:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 11228a2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11228b0:	mov    %rdx,-0xf0(%rbp)
 11228b7:	movzwl -0x2(%r10,%rdx,2),%edx
 11228bd:	lea    (%r10,%r13,2),%r15
 11228c1:	movzwl (%r10,%r13,2),%edi
 11228c6:	mov    -0x30(%rbp),%rax
 11228ca:	mov    (%rax),%rax
 11228cd:	shl    $0x4,%edx
 11228d0:	shl    $0x4,%edi
 11228d3:	mov    (%rax,%rdi,1),%r8
 11228d7:	cmp    %r8,(%rax,%rdx,1)
 11228db:	jne    11228eb <sort.block.block__anon_39113+0x4dcb>
 11228dd:	add    %rax,%rdx
 11228e0:	add    %rax,%rdi
 11228e3:	movzwl 0xe(%rdx),%edx
 11228e7:	cmp    0xe(%rdi),%dx
 11228eb:	jb     1122710 <sort.block.block__anon_39113+0x4bf0>
 11228f1:	movzwl (%r10,%r12,2),%edx
 11228f6:	movzwl -0x2(%r10,%r12,2),%edi
 11228fc:	shl    $0x4,%edx
 11228ff:	shl    $0x4,%edi
 1122902:	mov    (%rax,%rdi,1),%r8
 1122906:	cmp    %r8,(%rax,%rdx,1)
 112290a:	jne    112291a <sort.block.block__anon_39113+0x4dfa>
 112290c:	add    %rax,%rdx
 112290f:	add    %rax,%rdi
 1122912:	movzwl 0xe(%rdx),%eax
 1122916:	cmp    0xe(%rdi),%ax
 112291a:	vmovdqa -0x120102(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1122922:	jae    1122758 <sort.block.block__anon_39113+0x4c38>
 1122928:	mov    %r15,%rbx
 112292b:	mov    %r12,%rax
 112292e:	sub    %r13,%rax
 1122931:	mov    %rax,%rdi
 1122934:	mov    -0x88(%rbp),%r15
 112293b:	or     %r15,%rdi
 112293e:	shr    $0x20,%rdi
 1122942:	mov    %rax,-0x60(%rbp)
 1122946:	je     112294f <sort.block.block__anon_39113+0x4e2f>
 1122948:	xor    %edx,%edx
 112294a:	div    %r15
 112294d:	jmp    1122954 <sort.block.block__anon_39113+0x4e34>
 112294f:	xor    %edx,%edx
 1122951:	div    %r15d
 1122954:	lea    (%rdx,%r13,1),%rax
 1122958:	mov    %r12,%r11
 112295b:	mov    %rax,-0x78(%rbp)
 112295f:	cmp    %r12,%rax
 1122962:	jae    11229b0 <sort.block.block__anon_39113+0x4e90>
 1122964:	mov    -0x200(%rbp),%rax
 112296b:	mov    -0x78(%rbp),%r8
 112296f:	nop
 1122970:	movzbl -0x1(%rax),%r9d
 1122975:	mov    -0x38(%rbp),%r10
 1122979:	movzbl (%r10,%r8,2),%r10d
 112297e:	mov    %r10b,-0x1(%rax)
 1122982:	mov    -0x38(%rbp),%r10
 1122986:	mov    %r9b,(%r10,%r8,2)
 112298a:	movzbl (%rax),%r9d
 112298e:	mov    -0x38(%rbp),%r10
 1122992:	movzbl 0x1(%r10,%r8,2),%r10d
 1122998:	mov    %r10b,(%rax)
 112299b:	mov    -0x38(%rbp),%r10
 112299f:	mov    %r9b,0x1(%r10,%r8,2)
 11229a4:	add    %r15,%r8
 11229a7:	add    $0x2,%rax
 11229ab:	cmp    %r11,%r8
 11229ae:	jb     1122970 <sort.block.block__anon_39113+0x4e50>
 11229b0:	mov    -0xf0(%rbp),%r14
 11229b7:	sub    %r11,%r14
 11229ba:	cmp    %r14,%r15
 11229bd:	cmovb  %r15,%r14
 11229c1:	cmp    $0x201,%rdx
 11229c8:	jae    11229f0 <sort.block.block__anon_39113+0x4ed0>
 11229ca:	add    %rdx,%rdx
 11229cd:	lea    -0x650(%rbp),%rdi
 11229d4:	mov    %rbx,%rsi
 11229d7:	vzeroupper 
 11229da:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 11229df:	vmovdqa -0x1201c7(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 11229e7:	mov    -0x38(%rbp),%r10
 11229eb:	jmp    1122b5e <sort.block.block__anon_39113+0x503e>
 11229f0:	mov    -0xa8(%rbp),%rax
 11229f7:	cmp    %rax,-0xa0(%rbp)
 11229fe:	je     1122b5e <sort.block.block__anon_39113+0x503e>
 1122a04:	mov    %rdx,%r8
 1122a07:	test   %rdi,%rdi
 1122a0a:	je     1122a1a <sort.block.block__anon_39113+0x4efa>
 1122a0c:	mov    -0x60(%rbp),%rdi
 1122a10:	mov    %rdi,%rax
 1122a13:	xor    %edx,%edx
 1122a15:	div    %r15
 1122a18:	jmp    1122a25 <sort.block.block__anon_39113+0x4f05>
 1122a1a:	mov    -0x60(%rbp),%rdi
 1122a1e:	mov    %edi,%eax
 1122a20:	xor    %edx,%edx
 1122a22:	div    %r15d
 1122a25:	add    -0x1f0(%rbp),%rcx
 1122a2c:	add    %rsi,%rcx
 1122a2f:	add    %rdx,%rcx
 1122a32:	sub    %rdi,%rcx
 1122a35:	sub    %r13,%rcx
 1122a38:	cmp    $0x3,%rcx
 1122a3c:	mov    %r8,%rax
 1122a3f:	jae    1122a48 <sort.block.block__anon_39113+0x4f28>
 1122a41:	xor    %ecx,%ecx
 1122a43:	jmp    1122b11 <sort.block.block__anon_39113+0x4ff1>
 1122a48:	mov    %rax,%rdx
 1122a4b:	and    $0xfffffffffffffffc,%rdx
 1122a4f:	mov    -0x80(%rbp),%rcx
 1122a53:	lea    (%rcx,%r13,2),%rsi
 1122a57:	xor    %ecx,%ecx
 1122a59:	mov    -0x1d0(%rbp),%r11
 1122a60:	movzbl -0x7(%rsi,%rcx,2),%edi
 1122a65:	movzbl -0x7(%r11,%rcx,2),%r8d
 1122a6b:	mov    %r8b,-0x7(%rsi,%rcx,2)
 1122a70:	mov    %dil,-0x7(%r11,%rcx,2)
 1122a75:	movzbl -0x6(%rsi,%rcx,2),%edi
 1122a7a:	movzbl -0x6(%r11,%rcx,2),%r8d
 1122a80:	mov    %r8b,-0x6(%rsi,%rcx,2)
 1122a85:	mov    %dil,-0x6(%r11,%rcx,2)
 1122a8a:	movzbl -0x5(%rsi,%rcx,2),%edi
 1122a8f:	movzbl -0x5(%r11,%rcx,2),%r8d
 1122a95:	mov    %r8b,-0x5(%rsi,%rcx,2)
 1122a9a:	mov    %dil,-0x5(%r11,%rcx,2)
 1122a9f:	movzbl -0x4(%rsi,%rcx,2),%edi
 1122aa4:	movzbl -0x4(%r11,%rcx,2),%r8d
 1122aaa:	mov    %r8b,-0x4(%rsi,%rcx,2)
 1122aaf:	mov    %dil,-0x4(%r11,%rcx,2)
 1122ab4:	movzbl -0x3(%rsi,%rcx,2),%edi
 1122ab9:	movzbl -0x3(%r11,%rcx,2),%r8d
 1122abf:	mov    %r8b,-0x3(%rsi,%rcx,2)
 1122ac4:	mov    %dil,-0x3(%r11,%rcx,2)
 1122ac9:	movzbl -0x2(%rsi,%rcx,2),%edi
 1122ace:	movzbl -0x2(%r11,%rcx,2),%r8d
 1122ad4:	mov    %r8b,-0x2(%rsi,%rcx,2)
 1122ad9:	mov    %dil,-0x2(%r11,%rcx,2)
 1122ade:	movzbl -0x1(%rsi,%rcx,2),%edi
 1122ae3:	movzbl -0x1(%r11,%rcx,2),%r8d
 1122ae9:	mov    %r8b,-0x1(%rsi,%rcx,2)
 1122aee:	mov    %dil,-0x1(%r11,%rcx,2)
 1122af3:	movzbl (%rsi,%rcx,2),%edi
 1122af7:	movzbl (%r11,%rcx,2),%r8d
 1122afc:	mov    %r8b,(%rsi,%rcx,2)
 1122b00:	mov    %dil,(%r11,%rcx,2)
 1122b04:	add    $0x4,%rcx
 1122b08:	cmp    %rcx,%rdx
 1122b0b:	jne    1122a60 <sort.block.block__anon_39113+0x4f40>
 1122b11:	and    $0x3,%eax
 1122b14:	je     1122b5e <sort.block.block__anon_39113+0x503e>
 1122b16:	mov    -0x1a8(%rbp),%rdx
 1122b1d:	lea    (%rdx,%rcx,2),%rdx
 1122b21:	add    %rcx,%rcx
 1122b24:	lea    (%rcx,%r13,2),%rcx
 1122b28:	add    -0x50(%rbp),%rcx
 1122b2c:	xor    %esi,%esi
 1122b2e:	xchg   %ax,%ax
 1122b30:	movzbl -0x1(%rcx,%rsi,2),%edi
 1122b35:	movzbl -0x1(%rdx,%rsi,2),%r8d
 1122b3b:	mov    %r8b,-0x1(%rcx,%rsi,2)
 1122b40:	mov    %dil,-0x1(%rdx,%rsi,2)
 1122b45:	movzbl (%rcx,%rsi,2),%edi
 1122b49:	movzbl (%rdx,%rsi,2),%r8d
 1122b4e:	mov    %r8b,(%rcx,%rsi,2)
 1122b52:	mov    %dil,(%rdx,%rsi,2)
 1122b56:	inc    %rsi
 1122b59:	cmp    %rsi,%rax
 1122b5c:	jne    1122b30 <sort.block.block__anon_39113+0x5010>
 1122b5e:	mov    -0x78(%rbp),%rdx
 1122b62:	cmp    %rdx,%r12
 1122b65:	jne    1122d43 <sort.block.block__anon_39113+0x5223>
 1122b6b:	mov    %r13,%rbx
 1122b6e:	mov    %r12,%r11
 1122b71:	mov    -0xf0(%rbp),%r14
 1122b78:	mov    -0x60(%rbp),%r12
 1122b7c:	cmp    $0x201,%r12
 1122b83:	mov    -0xa0(%rbp),%rax
 1122b8a:	mov    -0xa8(%rbp),%rcx
 1122b91:	jb     11256b9 <sort.block.block__anon_39113+0x7b99>
 1122b97:	cmp    %rcx,%rax
 1122b9a:	jne    112579d <sort.block.block__anon_39113+0x7c7d>
 1122ba0:	cmp    %r11,%r14
 1122ba3:	jne    1122bc3 <sort.block.block__anon_39113+0x50a3>
 1122ba5:	jmp    1122758 <sort.block.block__anon_39113+0x4c38>
 1122baa:	nopw   0x0(%rax,%rax,1)
 1122bb0:	mov    %r14,%r11
 1122bb3:	cmp    %rbx,%r14
 1122bb6:	mov    -0xf0(%rbp),%r14
 1122bbd:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 1122bc3:	lea    (%r10,%rbx,2),%rdi
 1122bc7:	mov    %r14,%rax
 1122bca:	sub    %r11,%rax
 1122bcd:	jbe    1122c4b <sort.block.block__anon_39113+0x512b>
 1122bd3:	movzwl (%rdi),%esi
 1122bd6:	mov    -0x30(%rbp),%rcx
 1122bda:	mov    (%rcx),%rcx
 1122bdd:	shl    $0x4,%esi
 1122be0:	lea    (%rcx,%rsi,1),%rdx
 1122be4:	mov    (%rcx,%rsi,1),%rsi
 1122be8:	mov    %r11,%r14
 1122beb:	jmp    1122bff <sort.block.block__anon_39113+0x50df>
 1122bed:	nopl   (%rax)
 1122bf0:	xor    %r8d,%r8d
 1122bf3:	add    %r8,%r14
 1122bf6:	cmp    $0x1,%rax
 1122bfa:	mov    %r9,%rax
 1122bfd:	jbe    1122c4b <sort.block.block__anon_39113+0x512b>
 1122bff:	lea    (%r10,%r14,2),%r9
 1122c03:	mov    %rax,%r8
 1122c06:	and    $0xfffffffffffffffe,%r8
 1122c0a:	movzwl (%r8,%r9,1),%r8d
 1122c0f:	shl    $0x4,%r8d
 1122c13:	cmp    %rsi,(%rcx,%r8,1)
 1122c17:	jne    1122c26 <sort.block.block__anon_39113+0x5106>
 1122c19:	add    %rcx,%r8
 1122c1c:	movzwl 0xe(%r8),%r8d
 1122c21:	cmp    0xe(%rdx),%r8w
 1122c26:	setb   %r8b
 1122c2a:	mov    %rax,%r9
 1122c2d:	shr    %r9
 1122c30:	test   %r8b,%r8b
 1122c33:	je     1122bf0 <sort.block.block__anon_39113+0x50d0>
 1122c35:	mov    %eax,%r8d
 1122c38:	and    $0x1,%r8d
 1122c3c:	add    %r9,%r8
 1122c3f:	add    %r8,%r14
 1122c42:	cmp    $0x1,%rax
 1122c46:	mov    %r9,%rax
 1122c49:	ja     1122bff <sort.block.block__anon_39113+0x50df>
 1122c4b:	mov    %r14,%r12
 1122c4e:	sub    %rbx,%r12
 1122c51:	mov    %r11,%r13
 1122c54:	sub    %rbx,%r13
 1122c57:	mov    %r13,%rsi
 1122c5a:	mov    %r11,%r15
 1122c5d:	mov    %rdi,-0x40(%rbp)
 1122c61:	vzeroupper 
 1122c64:	call   10fd040 <mem.reverse__anon_36385>
 1122c69:	mov    -0x38(%rbp),%rax
 1122c6d:	lea    (%rax,%r15,2),%rdi
 1122c71:	mov    %r12,%rsi
 1122c74:	sub    %r13,%rsi
 1122c77:	call   10fd040 <mem.reverse__anon_36385>
 1122c7c:	mov    -0x40(%rbp),%rdi
 1122c80:	mov    %r12,%rsi
 1122c83:	call   10fd040 <mem.reverse__anon_36385>
 1122c88:	mov    -0x38(%rbp),%r10
 1122c8c:	cmp    %r14,-0xf0(%rbp)
 1122c93:	vmovdqa -0x12047b(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1122c9b:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 1122ca1:	mov    %r14,%rdi
 1122ca4:	sub    %r15,%rdi
 1122ca7:	add    %rbx,%rdi
 1122caa:	mov    %r14,%rax
 1122cad:	mov    %r14,%rbx
 1122cb0:	sub    %rdi,%rax
 1122cb3:	jbe    1122bb0 <sort.block.block__anon_39113+0x5090>
 1122cb9:	movzwl (%r10,%rdi,2),%esi
 1122cbe:	mov    -0x30(%rbp),%rcx
 1122cc2:	mov    (%rcx),%rcx
 1122cc5:	shl    $0x4,%esi
 1122cc8:	lea    (%rcx,%rsi,1),%rdx
 1122ccc:	mov    (%rcx,%rsi,1),%rsi
 1122cd0:	mov    %rdi,%rbx
 1122cd3:	jmp    1122cfa <sort.block.block__anon_39113+0x51da>
 1122cd5:	data16 cs nopw 0x0(%rax,%rax,1)
 1122ce0:	mov    %eax,%r8d
 1122ce3:	and    $0x1,%r8d
 1122ce7:	add    %rdi,%r8
 1122cea:	add    %r8,%rbx
 1122ced:	cmp    $0x1,%rax
 1122cf1:	mov    %rdi,%rax
 1122cf4:	jbe    1122bb0 <sort.block.block__anon_39113+0x5090>
 1122cfa:	lea    (%r10,%rbx,2),%rdi
 1122cfe:	mov    %rax,%r8
 1122d01:	and    $0xfffffffffffffffe,%r8
 1122d05:	movzwl (%r8,%rdi,1),%edi
 1122d0a:	shl    $0x4,%edi
 1122d0d:	cmp    (%rcx,%rdi,1),%rsi
 1122d11:	jne    1122d20 <sort.block.block__anon_39113+0x5200>
 1122d13:	add    %rcx,%rdi
 1122d16:	movzwl 0xe(%rdx),%r8d
 1122d1b:	cmp    0xe(%rdi),%r8w
 1122d20:	setb   %r8b
 1122d24:	mov    %rax,%rdi
 1122d27:	shr    %rdi
 1122d2a:	test   %r8b,%r8b
 1122d2d:	je     1122ce0 <sort.block.block__anon_39113+0x51c0>
 1122d2f:	xor    %r8d,%r8d
 1122d32:	add    %r8,%rbx
 1122d35:	cmp    $0x1,%rax
 1122d39:	mov    %rdi,%rax
 1122d3c:	ja     1122cfa <sort.block.block__anon_39113+0x51da>
 1122d3e:	jmp    1122bb0 <sort.block.block__anon_39113+0x5090>
 1122d43:	add    %r12,%r14
 1122d46:	mov    -0xf0(%rbp),%rax
 1122d4d:	sub    %r15,%rax
 1122d50:	mov    %rax,-0x1f8(%rbp)
 1122d57:	mov    -0xd0(%rbp),%rax
 1122d5e:	mov    %rax,-0xc0(%rbp)
 1122d65:	mov    %rdx,%r11
 1122d68:	xor    %ebx,%ebx
 1122d6a:	xor    %esi,%esi
 1122d6c:	mov    %r12,%rax
 1122d6f:	mov    %rbx,%rcx
 1122d72:	mov    %rax,-0x108(%rbp)
 1122d79:	lea    (%r10,%rax,2),%rax
 1122d7d:	mov    %rax,-0x70(%rbp)
 1122d81:	mov    %r14,-0xd8(%rbp)
 1122d88:	mov    %r13,%rbx
 1122d8b:	jmp    1122db1 <sort.block.block__anon_39113+0x5291>
 1122d8d:	nopl   (%rax)
 1122d90:	incq   -0xc0(%rbp)
 1122d97:	sub    %r13,%rbx
 1122d9a:	lea    (%rbx,%r15,1),%r11
 1122d9e:	mov    %r11,%rcx
 1122da1:	mov    -0x78(%rbp),%rdx
 1122da5:	mov    %rdx,%rsi
 1122da8:	cmp    %rdx,%r12
 1122dab:	je     1125694 <sort.block.block__anon_39113+0x7b74>
 1122db1:	mov    %rbx,%r13
 1122db4:	mov    %rdx,%rbx
 1122db7:	mov    %rsi,%rax
 1122dba:	sub    %rcx,%rax
 1122dbd:	mov    %rdx,-0x40(%rbp)
 1122dc1:	mov    %rsi,-0xe0(%rbp)
 1122dc8:	mov    %r12,-0xe8(%rbp)
 1122dcf:	je     1122e90 <sort.block.block__anon_39113+0x5370>
 1122dd5:	movzwl -0x2(%r10,%rsi,2),%edx
 1122ddb:	mov    -0xc0(%rbp),%rsi
 1122de2:	movzwl (%r10,%rsi,2),%esi
 1122de7:	mov    -0x30(%rbp),%rdi
 1122deb:	mov    (%rdi),%rdi
 1122dee:	shl    $0x4,%edx
 1122df1:	shl    $0x4,%esi
 1122df4:	mov    (%rdi,%rsi,1),%r8
 1122df8:	cmp    %r8,(%rdi,%rdx,1)
 1122dfc:	jne    1122e0c <sort.block.block__anon_39113+0x52ec>
 1122dfe:	add    %rdi,%rdx
 1122e01:	add    %rdi,%rsi
 1122e04:	movzwl 0xe(%rdx),%edx
 1122e08:	cmp    0xe(%rsi),%dx
 1122e0c:	mov    -0x110(%rbp),%r9
 1122e13:	mov    -0xe0(%rbp),%rsi
 1122e1a:	jae    1122ea7 <sort.block.block__anon_39113+0x5387>
 1122e20:	mov    -0xd8(%rbp),%rdx
 1122e27:	cmp    -0x108(%rbp),%rdx
 1122e2e:	je     1122ea7 <sort.block.block__anon_39113+0x5387>
 1122e30:	mov    -0xd8(%rbp),%rcx
 1122e37:	mov    -0x108(%rbp),%rsi
 1122e3e:	sub    %rsi,%rcx
 1122e41:	lea    (%r10,%rbx,2),%rax
 1122e45:	mov    -0x100(%rbp),%rdx
 1122e4c:	cmp    %rdx,%rcx
 1122e4f:	mov    %r11,-0x90(%rbp)
 1122e56:	ja     1125538 <sort.block.block__anon_39113+0x7a18>
 1122e5c:	mov    %rcx,-0x60(%rbp)
 1122e60:	sub    %rbx,%rsi
 1122e63:	mov    %rsi,%rdx
 1122e66:	shr    %rdx
 1122e69:	cmp    $0x20,%rsi
 1122e6d:	setb   %dil
 1122e71:	cmp    $0xf,%rdx
 1122e75:	sete   %r8b
 1122e79:	or     %dil,%r8b
 1122e7c:	mov    -0x70(%rbp),%r14
 1122e80:	je     1124b7c <sort.block.block__anon_39113+0x705c>
 1122e86:	xor    %edi,%edi
 1122e88:	jmp    1124d19 <sort.block.block__anon_39113+0x71f9>
 1122e8d:	nopl   (%rax)
 1122e90:	mov    -0xd8(%rbp),%rdx
 1122e97:	cmp    -0x108(%rbp),%rdx
 1122e9e:	mov    -0x110(%rbp),%r9
 1122ea5:	jne    1122e30 <sort.block.block__anon_39113+0x5310>
 1122ea7:	cmp    %rsi,%rcx
 1122eaa:	mov    %rsi,%r14
 1122ead:	cmovb  %rcx,%r14
 1122eb1:	jae    1122f38 <sort.block.block__anon_39113+0x5418>
 1122eb7:	mov    -0xc0(%rbp),%rdx
 1122ebe:	movzwl (%r10,%rdx,2),%edi
 1122ec3:	mov    -0x30(%rbp),%rdx
 1122ec7:	mov    (%rdx),%rdx
 1122eca:	shl    $0x4,%edi
 1122ecd:	lea    (%rdx,%rdi,1),%rsi
 1122ed1:	mov    (%rdx,%rdi,1),%rdi
 1122ed5:	mov    %rcx,%r14
 1122ed8:	jmp    1122eef <sort.block.block__anon_39113+0x53cf>
 1122eda:	nopw   0x0(%rax,%rax,1)
 1122ee0:	xor    %r8d,%r8d
 1122ee3:	add    %r8,%r14
 1122ee6:	cmp    $0x1,%rax
 1122eea:	mov    %rcx,%rax
 1122eed:	jbe    1122f38 <sort.block.block__anon_39113+0x5418>
 1122eef:	lea    (%r10,%r14,2),%rcx
 1122ef3:	mov    %rax,%r8
 1122ef6:	and    $0xfffffffffffffffe,%r8
 1122efa:	movzwl (%r8,%rcx,1),%ecx
 1122eff:	shl    $0x4,%ecx
 1122f02:	cmp    %rdi,(%rdx,%rcx,1)
 1122f06:	jne    1122f13 <sort.block.block__anon_39113+0x53f3>
 1122f08:	add    %rdx,%rcx
 1122f0b:	movzwl 0xe(%rcx),%ecx
 1122f0f:	cmp    0xe(%rsi),%cx
 1122f13:	setb   %r8b
 1122f17:	mov    %rax,%rcx
 1122f1a:	shr    %rcx
 1122f1d:	test   %r8b,%r8b
 1122f20:	je     1122ee0 <sort.block.block__anon_39113+0x53c0>
 1122f22:	mov    %eax,%r8d
 1122f25:	and    $0x1,%r8d
 1122f29:	add    %rcx,%r8
 1122f2c:	add    %r8,%r14
 1122f2f:	cmp    $0x1,%rax
 1122f33:	mov    %rcx,%rax
 1122f36:	ja     1122eef <sort.block.block__anon_39113+0x53cf>
 1122f38:	lea    (%rbx,%r15,1),%rdx
 1122f3c:	mov    %rbx,%rax
 1122f3f:	mov    %rdx,-0x78(%rbp)
 1122f43:	cmp    %r12,%rdx
 1122f46:	jae    1122fd0 <sort.block.block__anon_39113+0x54b0>
 1122f4c:	mov    -0x30(%rbp),%rax
 1122f50:	mov    (%rax),%rcx
 1122f53:	mov    %rbx,%rsi
 1122f56:	mov    -0x78(%rbp),%rdx
 1122f5a:	jmp    1122f6b <sort.block.block__anon_39113+0x544b>
 1122f5c:	nopl   0x0(%rax)
 1122f60:	add    %r15,%rdx
 1122f63:	mov    %rax,%rsi
 1122f66:	cmp    %r12,%rdx
 1122f69:	jae    1122fd0 <sort.block.block__anon_39113+0x54b0>
 1122f6b:	movzwl (%r10,%rdx,2),%eax
 1122f70:	movzwl (%r10,%rsi,2),%edi
 1122f75:	shl    $0x4,%eax
 1122f78:	shl    $0x4,%edi
 1122f7b:	mov    (%rcx,%rdi,1),%r8
 1122f7f:	cmp    %r8,(%rcx,%rax,1)
 1122f83:	jne    1122fb0 <sort.block.block__anon_39113+0x5490>
 1122f85:	add    %rcx,%rax
 1122f88:	add    %rcx,%rdi
 1122f8b:	movzwl 0xe(%rax),%eax
 1122f8f:	cmp    0xe(%rdi),%ax
 1122f93:	setb   %dil
 1122f97:	mov    %rdx,%rax
 1122f9a:	test   %dil,%dil
 1122f9d:	jne    1122f60 <sort.block.block__anon_39113+0x5440>
 1122f9f:	jmp    1122fbc <sort.block.block__anon_39113+0x549c>
 1122fa1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122fb0:	setb   %dil
 1122fb4:	mov    %rdx,%rax
 1122fb7:	test   %dil,%dil
 1122fba:	jne    1122f60 <sort.block.block__anon_39113+0x5440>
 1122fbc:	mov    %rsi,%rax
 1122fbf:	jmp    1122f60 <sort.block.block__anon_39113+0x5440>
 1122fc1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122fd0:	lea    (%r10,%rbx,2),%r12
 1122fd4:	cmpq   $0x3,-0x100(%rbp)
 1122fdc:	mov    -0xb0(%rbp),%r8
 1122fe3:	jae    1122ff0 <sort.block.block__anon_39113+0x54d0>
 1122fe5:	xor    %ecx,%ecx
 1122fe7:	jmp    11230b1 <sort.block.block__anon_39113+0x5591>
 1122fec:	nopl   0x0(%rax)
 1122ff0:	mov    -0x80(%rbp),%rcx
 1122ff4:	lea    (%rcx,%rax,2),%rdx
 1122ff8:	xor    %ecx,%ecx
 1122ffa:	nopw   0x0(%rax,%rax,1)
 1123000:	movzbl (%r12,%rcx,2),%esi
 1123005:	movzbl -0x7(%rdx,%rcx,2),%edi
 112300a:	mov    %dil,(%r12,%rcx,2)
 112300e:	mov    %sil,-0x7(%rdx,%rcx,2)
 1123013:	movzbl 0x1(%r12,%rcx,2),%esi
 1123019:	movzbl -0x6(%rdx,%rcx,2),%edi
 112301e:	mov    %dil,0x1(%r12,%rcx,2)
 1123023:	mov    %sil,-0x6(%rdx,%rcx,2)
 1123028:	movzbl 0x2(%r12,%rcx,2),%esi
 112302e:	movzbl -0x5(%rdx,%rcx,2),%edi
 1123033:	mov    %dil,0x2(%r12,%rcx,2)
 1123038:	mov    %sil,-0x5(%rdx,%rcx,2)
 112303d:	movzbl 0x3(%r12,%rcx,2),%esi
 1123043:	movzbl -0x4(%rdx,%rcx,2),%edi
 1123048:	mov    %dil,0x3(%r12,%rcx,2)
 112304d:	mov    %sil,-0x4(%rdx,%rcx,2)
 1123052:	movzbl 0x4(%r12,%rcx,2),%esi
 1123058:	movzbl -0x3(%rdx,%rcx,2),%edi
 112305d:	mov    %dil,0x4(%r12,%rcx,2)
 1123062:	mov    %sil,-0x3(%rdx,%rcx,2)
 1123067:	movzbl 0x5(%r12,%rcx,2),%esi
 112306d:	movzbl -0x2(%rdx,%rcx,2),%edi
 1123072:	mov    %dil,0x5(%r12,%rcx,2)
 1123077:	mov    %sil,-0x2(%rdx,%rcx,2)
 112307c:	movzbl 0x6(%r12,%rcx,2),%esi
 1123082:	movzbl -0x1(%rdx,%rcx,2),%edi
 1123087:	mov    %dil,0x6(%r12,%rcx,2)
 112308c:	mov    %sil,-0x1(%rdx,%rcx,2)
 1123091:	movzbl 0x7(%r12,%rcx,2),%esi
 1123097:	movzbl (%rdx,%rcx,2),%edi
 112309b:	mov    %dil,0x7(%r12,%rcx,2)
 11230a0:	mov    %sil,(%rdx,%rcx,2)
 11230a4:	add    $0x4,%rcx
 11230a8:	cmp    %rcx,%r9
 11230ab:	jne    1123000 <sort.block.block__anon_39113+0x54e0>
 11230b1:	test   %r8,%r8
 11230b4:	je     1123101 <sort.block.block__anon_39113+0x55e1>
 11230b6:	add    %rax,%rax
 11230b9:	lea    (%rax,%rcx,2),%rax
 11230bd:	add    -0x50(%rbp),%rax
 11230c1:	xor    %edx,%edx
 11230c3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11230d0:	movzbl (%r12,%rcx,2),%esi
 11230d5:	movzbl -0x1(%rax,%rdx,2),%edi
 11230da:	mov    %dil,(%r12,%rcx,2)
 11230de:	mov    %sil,-0x1(%rax,%rdx,2)
 11230e3:	movzbl 0x1(%r12,%rcx,2),%esi
 11230e9:	movzbl (%rax,%rdx,2),%edi
 11230ed:	mov    %dil,0x1(%r12,%rcx,2)
 11230f2:	mov    %sil,(%rax,%rdx,2)
 11230f6:	inc    %rcx
 11230f9:	inc    %rdx
 11230fc:	cmp    %rdx,%r8
 11230ff:	jne    11230d0 <sort.block.block__anon_39113+0x55b0>
 1123101:	movzbl (%r12),%eax
 1123106:	mov    -0xc0(%rbp),%rdx
 112310d:	movzbl (%r10,%rdx,2),%ecx
 1123112:	mov    %cl,(%r12)
 1123116:	mov    %al,(%r10,%rdx,2)
 112311a:	movzbl 0x1(%r12),%eax
 1123120:	movzbl 0x1(%r10,%rdx,2),%ecx
 1123126:	mov    %cl,0x1(%r12)
 112312b:	mov    %al,0x1(%r10,%rdx,2)
 1123130:	mov    %r11,%rdx
 1123133:	sub    %r13,%rdx
 1123136:	cmp    $0x201,%rdx
 112313d:	jae    1123240 <sort.block.block__anon_39113+0x5720>
 1123143:	cmp    %r11,%r14
 1123146:	je     1123d50 <sort.block.block__anon_39113+0x6230>
 112314c:	cmp    %r13,%r11
 112314f:	je     1123d50 <sort.block.block__anon_39113+0x6230>
 1123155:	mov    %r14,%rcx
 1123158:	neg    %rcx
 112315b:	xor    %eax,%eax
 112315d:	mov    %rdx,-0x128(%rbp)
 1123164:	mov    %rcx,-0x60(%rbp)
 1123168:	mov    %r13,%rsi
 112316b:	movzwl -0x650(%rbp,%rax,2),%r8d
 1123174:	movzwl %r8w,%r9d
 1123178:	lea    (%rcx,%r11,1),%r10
 112317c:	mov    -0x38(%rbp),%rcx
 1123180:	mov    %r11,-0x90(%rbp)
 1123187:	lea    (%rcx,%r11,2),%rbx
 112318b:	lea    (%rcx,%r13,2),%r11
 112318f:	shl    $0x4,%r9d
 1123193:	xor    %edi,%edi
 1123195:	data16 cs nopw 0x0(%rax,%rax,1)
 11231a0:	movzwl (%rbx,%rdi,2),%r13d
 11231a5:	mov    -0x30(%rbp),%rcx
 11231a9:	mov    (%rcx),%r15
 11231ac:	mov    %r13d,%edx
 11231af:	shl    $0x4,%edx
 11231b2:	mov    (%r15,%r9,1),%rcx
 11231b6:	cmp    %rcx,(%r15,%rdx,1)
 11231ba:	jne    11231cb <sort.block.block__anon_39113+0x56ab>
 11231bc:	add    %r15,%rdx
 11231bf:	add    %r9,%r15
 11231c2:	movzwl 0xe(%rdx),%ecx
 11231c6:	cmp    0xe(%r15),%cx
 11231cb:	jae    11231f0 <sort.block.block__anon_39113+0x56d0>
 11231cd:	mov    %r13w,(%r11,%rdi,2)
 11231d2:	inc    %rdi
 11231d5:	mov    %r10,%rcx
 11231d8:	add    %rdi,%rcx
 11231db:	jne    11231a0 <sort.block.block__anon_39113+0x5680>
 11231dd:	jmp    1123d90 <sort.block.block__anon_39113+0x6270>
 11231e2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11231f0:	mov    %r8w,(%r11,%rdi,2)
 11231f5:	inc    %rax
 11231f8:	lea    (%rsi,%rdi,1),%r13
 11231fc:	inc    %r13
 11231ff:	mov    -0x90(%rbp),%r11
 1123206:	add    %rdi,%r11
 1123209:	mov    -0x128(%rbp),%rdx
 1123210:	cmp    %rdx,%rax
 1123213:	mov    -0x60(%rbp),%rcx
 1123217:	jne    1123168 <sort.block.block__anon_39113+0x5648>
 112321d:	lea    (%rsi,%rdi,1),%r13
 1123221:	inc    %r13
 1123224:	mov    %rdx,%rax
 1123227:	mov    -0x38(%rbp),%r10
 112322b:	mov    -0x88(%rbp),%r15
 1123232:	mov    -0x40(%rbp),%rbx
 1123236:	jmp    1123dac <sort.block.block__anon_39113+0x628c>
 112323b:	nopl   0x0(%rax,%rax,1)
 1123240:	mov    -0xa8(%rbp),%rax
 1123247:	cmp    %rax,-0xa0(%rbp)
 112324e:	jne    1123d60 <sort.block.block__anon_39113+0x6240>
 1123254:	cmp    %r11,%r14
 1123257:	jne    112326c <sort.block.block__anon_39113+0x574c>
 1123259:	jmp    1123dd5 <sort.block.block__anon_39113+0x62b5>
 112325e:	xchg   %ax,%ax
 1123260:	mov    %rax,%r11
 1123263:	cmp    %r13,%rax
 1123266:	je     1123dd5 <sort.block.block__anon_39113+0x62b5>
 112326c:	mov    %r14,%rcx
 112326f:	mov    %r14,%rax
 1123272:	sub    %r11,%rcx
 1123275:	jbe    11232fb <sort.block.block__anon_39113+0x57db>
 112327b:	movzwl (%r10,%r13,2),%eax
 1123280:	mov    -0x30(%rbp),%rdx
 1123284:	mov    (%rdx),%rdx
 1123287:	shl    $0x4,%eax
 112328a:	lea    (%rdx,%rax,1),%rsi
 112328e:	mov    (%rdx,%rax,1),%rdi
 1123292:	mov    %r11,%rax
 1123295:	jmp    11232af <sort.block.block__anon_39113+0x578f>
 1123297:	nopw   0x0(%rax,%rax,1)
 11232a0:	xor    %r9d,%r9d
 11232a3:	add    %r9,%rax
 11232a6:	cmp    $0x1,%rcx
 11232aa:	mov    %r8,%rcx
 11232ad:	jbe    11232fb <sort.block.block__anon_39113+0x57db>
 11232af:	lea    (%r10,%rax,2),%r8
 11232b3:	mov    %rcx,%r9
 11232b6:	and    $0xfffffffffffffffe,%r9
 11232ba:	movzwl (%r9,%r8,1),%r8d
 11232bf:	shl    $0x4,%r8d
 11232c3:	cmp    %rdi,(%rdx,%r8,1)
 11232c7:	jne    11232d6 <sort.block.block__anon_39113+0x57b6>
 11232c9:	add    %rdx,%r8
 11232cc:	movzwl 0xe(%r8),%r8d
 11232d1:	cmp    0xe(%rsi),%r8w
 11232d6:	setb   %r9b
 11232da:	mov    %rcx,%r8
 11232dd:	shr    %r8
 11232e0:	test   %r9b,%r9b
 11232e3:	je     11232a0 <sort.block.block__anon_39113+0x5780>
 11232e5:	mov    %ecx,%r9d
 11232e8:	and    $0x1,%r9d
 11232ec:	add    %r8,%r9
 11232ef:	add    %r9,%rax
 11232f2:	cmp    $0x1,%rcx
 11232f6:	mov    %r8,%rcx
 11232f9:	ja     11232af <sort.block.block__anon_39113+0x578f>
 11232fb:	mov    %r11,%rdx
 11232fe:	sub    %r13,%rdx
 1123301:	mov    %rdx,%rcx
 1123304:	shr    %rcx
 1123307:	cmp    $0x20,%rdx
 112330b:	setb   %sil
 112330f:	cmp    $0xf,%rcx
 1123313:	sete   %dil
 1123317:	or     %sil,%dil
 112331a:	je     1123330 <sort.block.block__anon_39113+0x5810>
 112331c:	xor    %esi,%esi
 112331e:	jmp    11234d1 <sort.block.block__anon_39113+0x59b1>
 1123323:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123330:	lea    -0x10(%rcx),%rsi
 1123334:	mov    %rsi,%rdi
 1123337:	shr    $0x4,%rdi
 112333b:	inc    %rdi
 112333e:	cmp    $0x30,%rsi
 1123342:	jae    1123360 <sort.block.block__anon_39113+0x5840>
 1123344:	xor    %esi,%esi
 1123346:	and    $0x3,%edi
 1123349:	jne    1123466 <sort.block.block__anon_39113+0x5946>
 112334f:	jmp    11234d1 <sort.block.block__anon_39113+0x59b1>
 1123354:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123360:	mov    %rdi,%r8
 1123363:	movabs $0x1ffffffffffffffc,%rsi
 112336d:	and    %rsi,%r8
 1123370:	mov    -0xc8(%rbp),%rsi
 1123377:	lea    (%rsi,%r13,2),%r9
 112337b:	mov    -0x58(%rbp),%rsi
 112337f:	lea    (%rsi,%r11,2),%r10
 1123383:	xor    %esi,%esi
 1123385:	data16 cs nopw 0x0(%rax,%rax,1)
 1123390:	vmovdqu (%r10,%rsi,2),%ymm0
 1123396:	vmovdqu -0x60(%r9),%ymm1
 112339c:	vpshufb %ymm2,%ymm1,%ymm1
 11233a1:	vpermq $0x4e,%ymm1,%ymm1
 11233a7:	vmovdqu %ymm1,(%r10,%rsi,2)
 11233ad:	vpshufb %ymm2,%ymm0,%ymm0
 11233b2:	vpermq $0x4e,%ymm0,%ymm0
 11233b8:	vmovdqu %ymm0,-0x60(%r9)
 11233be:	vmovdqu -0x20(%r10,%rsi,2),%ymm0
 11233c5:	vmovdqu -0x40(%r9),%ymm1
 11233cb:	vpshufb %ymm2,%ymm1,%ymm1
 11233d0:	vpermq $0x4e,%ymm1,%ymm1
 11233d6:	vmovdqu %ymm1,-0x20(%r10,%rsi,2)
 11233dd:	vpshufb %ymm2,%ymm0,%ymm0
 11233e2:	vpermq $0x4e,%ymm0,%ymm0
 11233e8:	vmovdqu %ymm0,-0x40(%r9)
 11233ee:	vmovdqu -0x40(%r10,%rsi,2),%ymm0
 11233f5:	vmovdqu -0x20(%r9),%ymm1
 11233fb:	vpshufb %ymm2,%ymm1,%ymm1
 1123400:	vpermq $0x4e,%ymm1,%ymm1
 1123406:	vmovdqu %ymm1,-0x40(%r10,%rsi,2)
 112340d:	vpshufb %ymm2,%ymm0,%ymm0
 1123412:	vpermq $0x4e,%ymm0,%ymm0
 1123418:	vmovdqu %ymm0,-0x20(%r9)
 112341e:	vmovdqu -0x60(%r10,%rsi,2),%ymm0
 1123425:	vmovdqu (%r9),%ymm1
 112342a:	vpshufb %ymm2,%ymm1,%ymm1
 112342f:	vpermq $0x4e,%ymm1,%ymm1
 1123435:	vmovdqu %ymm1,-0x60(%r10,%rsi,2)
 112343c:	vpshufb %ymm2,%ymm0,%ymm0
 1123441:	vpermq $0x4e,%ymm0,%ymm0
 1123447:	vmovdqu %ymm0,(%r9)
 112344c:	sub    $0xffffffffffffff80,%r9
 1123450:	add    $0xffffffffffffffc0,%rsi
 1123454:	add    $0xfffffffffffffffc,%r8
 1123458:	jne    1123390 <sort.block.block__anon_39113+0x5870>
 112345e:	neg    %rsi
 1123461:	and    $0x3,%edi
 1123464:	je     11234d1 <sort.block.block__anon_39113+0x59b1>
 1123466:	mov    -0x58(%rbp),%r8
 112346a:	lea    (%r8,%r11,2),%r9
 112346e:	mov    %rsi,%r8
 1123471:	neg    %r8
 1123474:	add    %rsi,%rsi
 1123477:	lea    (%rsi,%r13,2),%rsi
 112347b:	add    -0x38(%rbp),%rsi
 112347f:	shl    $0x5,%edi
 1123482:	xor    %r10d,%r10d
 1123485:	data16 cs nopw 0x0(%rax,%rax,1)
 1123490:	vmovdqu (%r9,%r8,2),%ymm0
 1123496:	vmovdqu (%rsi,%r10,1),%ymm1
 112349c:	vpshufb %ymm2,%ymm1,%ymm1
 11234a1:	vpermq $0x4e,%ymm1,%ymm1
 11234a7:	vmovdqu %ymm1,(%r9,%r8,2)
 11234ad:	vpshufb %ymm2,%ymm0,%ymm0
 11234b2:	vpermq $0x4e,%ymm0,%ymm0
 11234b8:	vmovdqu %ymm0,(%rsi,%r10,1)
 11234be:	add    $0xfffffffffffffff0,%r8
 11234c2:	add    $0x20,%r10
 11234c6:	cmp    %r10,%rdi
 11234c9:	jne    1123490 <sort.block.block__anon_39113+0x5970>
 11234cb:	neg    %r8
 11234ce:	mov    %r8,%rsi
 11234d1:	mov    %rsi,%rdi
 11234d4:	sub    %rcx,%rdi
 11234d7:	jae    112363d <sort.block.block__anon_39113+0x5b1d>
 11234dd:	mov    %ecx,%r8d
 11234e0:	sub    %esi,%r8d
 11234e3:	and    $0x3,%r8d
 11234e7:	je     1123565 <sort.block.block__anon_39113+0x5a45>
 11234e9:	mov    -0x48(%rbp),%r9
 11234ed:	mov    %r11,-0x90(%rbp)
 11234f4:	lea    (%r9,%r11,2),%r9
 11234f8:	sub    %rsi,%r9
 11234fb:	sub    %rsi,%r9
 11234fe:	lea    0x0(,%r13,2),%r10
 1123506:	lea    (%r10,%rsi,2),%r10
 112350a:	add    -0x50(%rbp),%r10
 112350e:	neg    %r8
 1123511:	xor    %r11d,%r11d
 1123514:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123520:	movzbl -0x1(%r10),%ebx
 1123525:	movzbl -0x1(%r9,%r11,2),%r15d
 112352b:	mov    %r15b,-0x1(%r10)
 112352f:	mov    %bl,-0x1(%r9,%r11,2)
 1123534:	movzbl (%r10),%ebx
 1123538:	movzbl (%r9,%r11,2),%r15d
 112353d:	mov    %r15b,(%r10)
 1123540:	mov    %bl,(%r9,%r11,2)
 1123544:	dec    %r11
 1123547:	add    $0x2,%r10
 112354b:	cmp    %r11,%r8
 112354e:	jne    1123520 <sort.block.block__anon_39113+0x5a00>
 1123550:	sub    %r11,%rsi
 1123553:	mov    -0x88(%rbp),%r15
 112355a:	mov    -0x40(%rbp),%rbx
 112355e:	mov    -0x90(%rbp),%r11
 1123565:	cmp    $0xfffffffffffffffc,%rdi
 1123569:	ja     112363d <sort.block.block__anon_39113+0x5b1d>
 112356f:	mov    -0x80(%rbp),%rdi
 1123573:	lea    (%rdi,%r13,2),%rdi
 1123577:	mov    -0x48(%rbp),%r8
 112357b:	lea    (%r8,%r11,2),%r8
 112357f:	sub    %rsi,%r8
 1123582:	sub    %rsi,%r8
 1123585:	data16 cs nopw 0x0(%rax,%rax,1)
 1123590:	movzbl -0x7(%rdi,%rsi,2),%r9d
 1123596:	movzbl -0x1(%r8),%r10d
 112359b:	mov    %r10b,-0x7(%rdi,%rsi,2)
 11235a0:	mov    %r9b,-0x1(%r8)
 11235a4:	movzbl -0x6(%rdi,%rsi,2),%r9d
 11235aa:	movzbl (%r8),%r10d
 11235ae:	mov    %r10b,-0x6(%rdi,%rsi,2)
 11235b3:	mov    %r9b,(%r8)
 11235b6:	movzbl -0x5(%rdi,%rsi,2),%r9d
 11235bc:	movzbl -0x3(%r8),%r10d
 11235c1:	mov    %r10b,-0x5(%rdi,%rsi,2)
 11235c6:	mov    %r9b,-0x3(%r8)
 11235ca:	movzbl -0x4(%rdi,%rsi,2),%r9d
 11235d0:	movzbl -0x2(%r8),%r10d
 11235d5:	mov    %r10b,-0x4(%rdi,%rsi,2)
 11235da:	mov    %r9b,-0x2(%r8)
 11235de:	movzbl -0x3(%rdi,%rsi,2),%r9d
 11235e4:	movzbl -0x5(%r8),%r10d
 11235e9:	mov    %r10b,-0x3(%rdi,%rsi,2)
 11235ee:	mov    %r9b,-0x5(%r8)
 11235f2:	movzbl -0x2(%rdi,%rsi,2),%r9d
 11235f8:	movzbl -0x4(%r8),%r10d
 11235fd:	mov    %r10b,-0x2(%rdi,%rsi,2)
 1123602:	mov    %r9b,-0x4(%r8)
 1123606:	movzbl -0x1(%rdi,%rsi,2),%r9d
 112360c:	movzbl -0x7(%r8),%r10d
 1123611:	mov    %r10b,-0x1(%rdi,%rsi,2)
 1123616:	mov    %r9b,-0x7(%r8)
 112361a:	movzbl (%rdi,%rsi,2),%r9d
 112361f:	movzbl -0x6(%r8),%r10d
 1123624:	mov    %r10b,(%rdi,%rsi,2)
 1123628:	mov    %r9b,-0x6(%r8)
 112362c:	add    $0x4,%rsi
 1123630:	add    $0xfffffffffffffff8,%r8
 1123634:	cmp    %rsi,%rcx
 1123637:	jne    1123590 <sort.block.block__anon_39113+0x5a70>
 112363d:	mov    %rax,%rcx
 1123640:	sub    %r13,%rcx
 1123643:	mov    %rcx,%rsi
 1123646:	sub    %rdx,%rsi
 1123649:	mov    %rsi,%rdx
 112364c:	shr    %rdx
 112364f:	cmp    $0x20,%rsi
 1123653:	setb   %sil
 1123657:	cmp    $0xf,%rdx
 112365b:	sete   %dil
 112365f:	or     %sil,%dil
 1123662:	je     1123670 <sort.block.block__anon_39113+0x5b50>
 1123664:	xor    %esi,%esi
 1123666:	jmp    1123811 <sort.block.block__anon_39113+0x5cf1>
 112366b:	nopl   0x0(%rax,%rax,1)
 1123670:	lea    -0x10(%rdx),%rsi
 1123674:	mov    %rsi,%rdi
 1123677:	shr    $0x4,%rdi
 112367b:	inc    %rdi
 112367e:	cmp    $0x30,%rsi
 1123682:	jae    11236a0 <sort.block.block__anon_39113+0x5b80>
 1123684:	xor    %esi,%esi
 1123686:	and    $0x3,%edi
 1123689:	jne    11237a6 <sort.block.block__anon_39113+0x5c86>
 112368f:	jmp    1123811 <sort.block.block__anon_39113+0x5cf1>
 1123694:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 11236a0:	mov    %rdi,%r8
 11236a3:	movabs $0x1ffffffffffffffc,%rsi
 11236ad:	and    %rsi,%r8
 11236b0:	mov    -0xc8(%rbp),%rsi
 11236b7:	lea    (%rsi,%r11,2),%r9
 11236bb:	mov    -0x58(%rbp),%rsi
 11236bf:	lea    (%rsi,%rax,2),%r10
 11236c3:	xor    %esi,%esi
 11236c5:	data16 cs nopw 0x0(%rax,%rax,1)
 11236d0:	vmovdqu (%r10,%rsi,2),%ymm0
 11236d6:	vmovdqu -0x60(%r9),%ymm1
 11236dc:	vpshufb %ymm2,%ymm1,%ymm1
 11236e1:	vpermq $0x4e,%ymm1,%ymm1
 11236e7:	vmovdqu %ymm1,(%r10,%rsi,2)
 11236ed:	vpshufb %ymm2,%ymm0,%ymm0
 11236f2:	vpermq $0x4e,%ymm0,%ymm0
 11236f8:	vmovdqu %ymm0,-0x60(%r9)
 11236fe:	vmovdqu -0x20(%r10,%rsi,2),%ymm0
 1123705:	vmovdqu -0x40(%r9),%ymm1
 112370b:	vpshufb %ymm2,%ymm1,%ymm1
 1123710:	vpermq $0x4e,%ymm1,%ymm1
 1123716:	vmovdqu %ymm1,-0x20(%r10,%rsi,2)
 112371d:	vpshufb %ymm2,%ymm0,%ymm0
 1123722:	vpermq $0x4e,%ymm0,%ymm0
 1123728:	vmovdqu %ymm0,-0x40(%r9)
 112372e:	vmovdqu -0x40(%r10,%rsi,2),%ymm0
 1123735:	vmovdqu -0x20(%r9),%ymm1
 112373b:	vpshufb %ymm2,%ymm1,%ymm1
 1123740:	vpermq $0x4e,%ymm1,%ymm1
 1123746:	vmovdqu %ymm1,-0x40(%r10,%rsi,2)
 112374d:	vpshufb %ymm2,%ymm0,%ymm0
 1123752:	vpermq $0x4e,%ymm0,%ymm0
 1123758:	vmovdqu %ymm0,-0x20(%r9)
 112375e:	vmovdqu -0x60(%r10,%rsi,2),%ymm0
 1123765:	vmovdqu (%r9),%ymm1
 112376a:	vpshufb %ymm2,%ymm1,%ymm1
 112376f:	vpermq $0x4e,%ymm1,%ymm1
 1123775:	vmovdqu %ymm1,-0x60(%r10,%rsi,2)
 112377c:	vpshufb %ymm2,%ymm0,%ymm0
 1123781:	vpermq $0x4e,%ymm0,%ymm0
 1123787:	vmovdqu %ymm0,(%r9)
 112378c:	sub    $0xffffffffffffff80,%r9
 1123790:	add    $0xffffffffffffffc0,%rsi
 1123794:	add    $0xfffffffffffffffc,%r8
 1123798:	jne    11236d0 <sort.block.block__anon_39113+0x5bb0>
 112379e:	neg    %rsi
 11237a1:	and    $0x3,%edi
 11237a4:	je     1123811 <sort.block.block__anon_39113+0x5cf1>
 11237a6:	mov    -0x58(%rbp),%r8
 11237aa:	lea    (%r8,%rax,2),%r9
 11237ae:	mov    %rsi,%r8
 11237b1:	neg    %r8
 11237b4:	add    %rsi,%rsi
 11237b7:	lea    (%rsi,%r11,2),%rsi
 11237bb:	add    -0x38(%rbp),%rsi
 11237bf:	shl    $0x5,%edi
 11237c2:	xor    %r10d,%r10d
 11237c5:	data16 cs nopw 0x0(%rax,%rax,1)
 11237d0:	vmovdqu (%r9,%r8,2),%ymm0
 11237d6:	vmovdqu (%rsi,%r10,1),%ymm1
 11237dc:	vpshufb %ymm2,%ymm1,%ymm1
 11237e1:	vpermq $0x4e,%ymm1,%ymm1
 11237e7:	vmovdqu %ymm1,(%r9,%r8,2)
 11237ed:	vpshufb %ymm2,%ymm0,%ymm0
 11237f2:	vpermq $0x4e,%ymm0,%ymm0
 11237f8:	vmovdqu %ymm0,(%rsi,%r10,1)
 11237fe:	add    $0xfffffffffffffff0,%r8
 1123802:	add    $0x20,%r10
 1123806:	cmp    %r10,%rdi
 1123809:	jne    11237d0 <sort.block.block__anon_39113+0x5cb0>
 112380b:	neg    %r8
 112380e:	mov    %r8,%rsi
 1123811:	mov    %rsi,%rdi
 1123814:	sub    %rdx,%rdi
 1123817:	jae    112396d <sort.block.block__anon_39113+0x5e4d>
 112381d:	mov    %edx,%r8d
 1123820:	sub    %esi,%r8d
 1123823:	and    $0x3,%r8d
 1123827:	je     1123895 <sort.block.block__anon_39113+0x5d75>
 1123829:	mov    -0x48(%rbp),%r9
 112382d:	lea    (%r9,%rax,2),%r9
 1123831:	sub    %rsi,%r9
 1123834:	sub    %rsi,%r9
 1123837:	mov    %r11,-0x90(%rbp)
 112383e:	lea    (%r11,%r11,1),%r10
 1123842:	lea    (%r10,%rsi,2),%r10
 1123846:	add    -0x50(%rbp),%r10
 112384a:	neg    %r8
 112384d:	xor    %r11d,%r11d
 1123850:	movzbl -0x1(%r10),%ebx
 1123855:	movzbl -0x1(%r9,%r11,2),%r15d
 112385b:	mov    %r15b,-0x1(%r10)
 112385f:	mov    %bl,-0x1(%r9,%r11,2)
 1123864:	movzbl (%r10),%ebx
 1123868:	movzbl (%r9,%r11,2),%r15d
 112386d:	mov    %r15b,(%r10)
 1123870:	mov    %bl,(%r9,%r11,2)
 1123874:	dec    %r11
 1123877:	add    $0x2,%r10
 112387b:	cmp    %r11,%r8
 112387e:	jne    1123850 <sort.block.block__anon_39113+0x5d30>
 1123880:	sub    %r11,%rsi
 1123883:	mov    -0x88(%rbp),%r15
 112388a:	mov    -0x40(%rbp),%rbx
 112388e:	mov    -0x90(%rbp),%r11
 1123895:	cmp    $0xfffffffffffffffc,%rdi
 1123899:	ja     112396d <sort.block.block__anon_39113+0x5e4d>
 112389f:	mov    -0x80(%rbp),%rdi
 11238a3:	lea    (%rdi,%r11,2),%rdi
 11238a7:	mov    -0x48(%rbp),%r8
 11238ab:	lea    (%r8,%rax,2),%r8
 11238af:	sub    %rsi,%r8
 11238b2:	sub    %rsi,%r8
 11238b5:	data16 cs nopw 0x0(%rax,%rax,1)
 11238c0:	movzbl -0x7(%rdi,%rsi,2),%r9d
 11238c6:	movzbl -0x1(%r8),%r10d
 11238cb:	mov    %r10b,-0x7(%rdi,%rsi,2)
 11238d0:	mov    %r9b,-0x1(%r8)
 11238d4:	movzbl -0x6(%rdi,%rsi,2),%r9d
 11238da:	movzbl (%r8),%r10d
 11238de:	mov    %r10b,-0x6(%rdi,%rsi,2)
 11238e3:	mov    %r9b,(%r8)
 11238e6:	movzbl -0x5(%rdi,%rsi,2),%r9d
 11238ec:	movzbl -0x3(%r8),%r10d
 11238f1:	mov    %r10b,-0x5(%rdi,%rsi,2)
 11238f6:	mov    %r9b,-0x3(%r8)
 11238fa:	movzbl -0x4(%rdi,%rsi,2),%r9d
 1123900:	movzbl -0x2(%r8),%r10d
 1123905:	mov    %r10b,-0x4(%rdi,%rsi,2)
 112390a:	mov    %r9b,-0x2(%r8)
 112390e:	movzbl -0x3(%rdi,%rsi,2),%r9d
 1123914:	movzbl -0x5(%r8),%r10d
 1123919:	mov    %r10b,-0x3(%rdi,%rsi,2)
 112391e:	mov    %r9b,-0x5(%r8)
 1123922:	movzbl -0x2(%rdi,%rsi,2),%r9d
 1123928:	movzbl -0x4(%r8),%r10d
 112392d:	mov    %r10b,-0x2(%rdi,%rsi,2)
 1123932:	mov    %r9b,-0x4(%r8)
 1123936:	movzbl -0x1(%rdi,%rsi,2),%r9d
 112393c:	movzbl -0x7(%r8),%r10d
 1123941:	mov    %r10b,-0x1(%rdi,%rsi,2)
 1123946:	mov    %r9b,-0x7(%r8)
 112394a:	movzbl (%rdi,%rsi,2),%r9d
 112394f:	movzbl -0x6(%r8),%r10d
 1123954:	mov    %r10b,(%rdi,%rsi,2)
 1123958:	mov    %r9b,-0x6(%r8)
 112395c:	add    $0x4,%rsi
 1123960:	add    $0xfffffffffffffff8,%r8
 1123964:	cmp    %rsi,%rdx
 1123967:	jne    11238c0 <sort.block.block__anon_39113+0x5da0>
 112396d:	mov    %rcx,%rdx
 1123970:	shr    %rdx
 1123973:	cmp    $0x20,%rcx
 1123977:	setb   %cl
 112397a:	cmp    $0xf,%rdx
 112397e:	sete   %sil
 1123982:	or     %cl,%sil
 1123985:	je     11239a0 <sort.block.block__anon_39113+0x5e80>
 1123987:	xor    %ecx,%ecx
 1123989:	mov    -0x38(%rbp),%r10
 112398d:	jmp    1123b41 <sort.block.block__anon_39113+0x6021>
 1123992:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11239a0:	lea    -0x10(%rdx),%rcx
 11239a4:	mov    %rcx,%rsi
 11239a7:	shr    $0x4,%rsi
 11239ab:	inc    %rsi
 11239ae:	cmp    $0x30,%rcx
 11239b2:	jae    11239d0 <sort.block.block__anon_39113+0x5eb0>
 11239b4:	xor    %ecx,%ecx
 11239b6:	mov    -0x38(%rbp),%r10
 11239ba:	and    $0x3,%esi
 11239bd:	jne    1123ada <sort.block.block__anon_39113+0x5fba>
 11239c3:	jmp    1123b41 <sort.block.block__anon_39113+0x6021>
 11239c8:	nopl   0x0(%rax,%rax,1)
 11239d0:	mov    %rsi,%rdi
 11239d3:	movabs $0x1ffffffffffffffc,%rcx
 11239dd:	and    %rcx,%rdi
 11239e0:	mov    -0xc8(%rbp),%rcx
 11239e7:	lea    (%rcx,%r13,2),%r8
 11239eb:	mov    -0x58(%rbp),%rcx
 11239ef:	lea    (%rcx,%rax,2),%r9
 11239f3:	xor    %ecx,%ecx
 11239f5:	data16 cs nopw 0x0(%rax,%rax,1)
 1123a00:	vmovdqu (%r9,%rcx,2),%ymm0
 1123a06:	vmovdqu -0x60(%r8),%ymm1
 1123a0c:	vpshufb %ymm2,%ymm1,%ymm1
 1123a11:	vpermq $0x4e,%ymm1,%ymm1
 1123a17:	vmovdqu %ymm1,(%r9,%rcx,2)
 1123a1d:	vpshufb %ymm2,%ymm0,%ymm0
 1123a22:	vpermq $0x4e,%ymm0,%ymm0
 1123a28:	vmovdqu %ymm0,-0x60(%r8)
 1123a2e:	vmovdqu -0x20(%r9,%rcx,2),%ymm0
 1123a35:	vmovdqu -0x40(%r8),%ymm1
 1123a3b:	vpshufb %ymm2,%ymm1,%ymm1
 1123a40:	vpermq $0x4e,%ymm1,%ymm1
 1123a46:	vmovdqu %ymm1,-0x20(%r9,%rcx,2)
 1123a4d:	vpshufb %ymm2,%ymm0,%ymm0
 1123a52:	vpermq $0x4e,%ymm0,%ymm0
 1123a58:	vmovdqu %ymm0,-0x40(%r8)
 1123a5e:	vmovdqu -0x40(%r9,%rcx,2),%ymm0
 1123a65:	vmovdqu -0x20(%r8),%ymm1
 1123a6b:	vpshufb %ymm2,%ymm1,%ymm1
 1123a70:	vpermq $0x4e,%ymm1,%ymm1
 1123a76:	vmovdqu %ymm1,-0x40(%r9,%rcx,2)
 1123a7d:	vpshufb %ymm2,%ymm0,%ymm0
 1123a82:	vpermq $0x4e,%ymm0,%ymm0
 1123a88:	vmovdqu %ymm0,-0x20(%r8)
 1123a8e:	vmovdqu -0x60(%r9,%rcx,2),%ymm0
 1123a95:	vmovdqu (%r8),%ymm1
 1123a9a:	vpshufb %ymm2,%ymm1,%ymm1
 1123a9f:	vpermq $0x4e,%ymm1,%ymm1
 1123aa5:	vmovdqu %ymm1,-0x60(%r9,%rcx,2)
 1123aac:	vpshufb %ymm2,%ymm0,%ymm0
 1123ab1:	vpermq $0x4e,%ymm0,%ymm0
 1123ab7:	vmovdqu %ymm0,(%r8)
 1123abc:	sub    $0xffffffffffffff80,%r8
 1123ac0:	add    $0xffffffffffffffc0,%rcx
 1123ac4:	add    $0xfffffffffffffffc,%rdi
 1123ac8:	jne    1123a00 <sort.block.block__anon_39113+0x5ee0>
 1123ace:	neg    %rcx
 1123ad1:	mov    -0x38(%rbp),%r10
 1123ad5:	and    $0x3,%esi
 1123ad8:	je     1123b41 <sort.block.block__anon_39113+0x6021>
 1123ada:	mov    -0x58(%rbp),%rdi
 1123ade:	lea    (%rdi,%rax,2),%r8
 1123ae2:	mov    %rcx,%rdi
 1123ae5:	neg    %rdi
 1123ae8:	add    %rcx,%rcx
 1123aeb:	lea    (%rcx,%r13,2),%rcx
 1123aef:	add    %r10,%rcx
 1123af2:	shl    $0x5,%esi
 1123af5:	xor    %r9d,%r9d
 1123af8:	nopl   0x0(%rax,%rax,1)
 1123b00:	vmovdqu (%r8,%rdi,2),%ymm0
 1123b06:	vmovdqu (%rcx,%r9,1),%ymm1
 1123b0c:	vpshufb %ymm2,%ymm1,%ymm1
 1123b11:	vpermq $0x4e,%ymm1,%ymm1
 1123b17:	vmovdqu %ymm1,(%r8,%rdi,2)
 1123b1d:	vpshufb %ymm2,%ymm0,%ymm0
 1123b22:	vpermq $0x4e,%ymm0,%ymm0
 1123b28:	vmovdqu %ymm0,(%rcx,%r9,1)
 1123b2e:	add    $0xfffffffffffffff0,%rdi
 1123b32:	add    $0x20,%r9
 1123b36:	cmp    %r9,%rsi
 1123b39:	jne    1123b00 <sort.block.block__anon_39113+0x5fe0>
 1123b3b:	neg    %rdi
 1123b3e:	mov    %rdi,%rcx
 1123b41:	mov    %rcx,%rsi
 1123b44:	sub    %rdx,%rsi
 1123b47:	jae    1123c9d <sort.block.block__anon_39113+0x617d>
 1123b4d:	mov    %edx,%edi
 1123b4f:	sub    %ecx,%edi
 1123b51:	and    $0x3,%edi
 1123b54:	je     1123bc5 <sort.block.block__anon_39113+0x60a5>
 1123b56:	mov    %r11,%r15
 1123b59:	mov    -0x48(%rbp),%r8
 1123b5d:	lea    (%r8,%rax,2),%r8
 1123b61:	sub    %rcx,%r8
 1123b64:	sub    %rcx,%r8
 1123b67:	lea    0x0(,%r13,2),%r9
 1123b6f:	lea    (%r9,%rcx,2),%r9
 1123b73:	add    -0x50(%rbp),%r9
 1123b77:	neg    %rdi
 1123b7a:	xor    %r10d,%r10d
 1123b7d:	nopl   (%rax)
 1123b80:	movzbl -0x1(%r9),%r11d
 1123b85:	movzbl -0x1(%r8,%r10,2),%ebx
 1123b8b:	mov    %bl,-0x1(%r9)
 1123b8f:	mov    %r11b,-0x1(%r8,%r10,2)
 1123b94:	movzbl (%r9),%r11d
 1123b98:	movzbl (%r8,%r10,2),%ebx
 1123b9d:	mov    %bl,(%r9)
 1123ba0:	mov    %r11b,(%r8,%r10,2)
 1123ba4:	dec    %r10
 1123ba7:	add    $0x2,%r9
 1123bab:	cmp    %r10,%rdi
 1123bae:	jne    1123b80 <sort.block.block__anon_39113+0x6060>
 1123bb0:	sub    %r10,%rcx
 1123bb3:	mov    -0x38(%rbp),%r10
 1123bb7:	mov    -0x40(%rbp),%rbx
 1123bbb:	mov    %r15,%r11
 1123bbe:	mov    -0x88(%rbp),%r15
 1123bc5:	cmp    $0xfffffffffffffffc,%rsi
 1123bc9:	ja     1123c9d <sort.block.block__anon_39113+0x617d>
 1123bcf:	mov    -0x80(%rbp),%rsi
 1123bd3:	lea    (%rsi,%r13,2),%rsi
 1123bd7:	mov    -0x48(%rbp),%rdi
 1123bdb:	lea    (%rdi,%rax,2),%rdi
 1123bdf:	sub    %rcx,%rdi
 1123be2:	sub    %rcx,%rdi
 1123be5:	data16 cs nopw 0x0(%rax,%rax,1)
 1123bf0:	movzbl -0x7(%rsi,%rcx,2),%r8d
 1123bf6:	movzbl -0x1(%rdi),%r9d
 1123bfb:	mov    %r9b,-0x7(%rsi,%rcx,2)
 1123c00:	mov    %r8b,-0x1(%rdi)
 1123c04:	movzbl -0x6(%rsi,%rcx,2),%r8d
 1123c0a:	movzbl (%rdi),%r9d
 1123c0e:	mov    %r9b,-0x6(%rsi,%rcx,2)
 1123c13:	mov    %r8b,(%rdi)
 1123c16:	movzbl -0x5(%rsi,%rcx,2),%r8d
 1123c1c:	movzbl -0x3(%rdi),%r9d
 1123c21:	mov    %r9b,-0x5(%rsi,%rcx,2)
 1123c26:	mov    %r8b,-0x3(%rdi)
 1123c2a:	movzbl -0x4(%rsi,%rcx,2),%r8d
 1123c30:	movzbl -0x2(%rdi),%r9d
 1123c35:	mov    %r9b,-0x4(%rsi,%rcx,2)
 1123c3a:	mov    %r8b,-0x2(%rdi)
 1123c3e:	movzbl -0x3(%rsi,%rcx,2),%r8d
 1123c44:	movzbl -0x5(%rdi),%r9d
 1123c49:	mov    %r9b,-0x3(%rsi,%rcx,2)
 1123c4e:	mov    %r8b,-0x5(%rdi)
 1123c52:	movzbl -0x2(%rsi,%rcx,2),%r8d
 1123c58:	movzbl -0x4(%rdi),%r9d
 1123c5d:	mov    %r9b,-0x2(%rsi,%rcx,2)
 1123c62:	mov    %r8b,-0x4(%rdi)
 1123c66:	movzbl -0x1(%rsi,%rcx,2),%r8d
 1123c6c:	movzbl -0x7(%rdi),%r9d
 1123c71:	mov    %r9b,-0x1(%rsi,%rcx,2)
 1123c76:	mov    %r8b,-0x7(%rdi)
 1123c7a:	movzbl (%rsi,%rcx,2),%r8d
 1123c7f:	movzbl -0x6(%rdi),%r9d
 1123c84:	mov    %r9b,(%rsi,%rcx,2)
 1123c88:	mov    %r8b,-0x6(%rdi)
 1123c8c:	add    $0x4,%rcx
 1123c90:	add    $0xfffffffffffffff8,%rdi
 1123c94:	cmp    %rcx,%rdx
 1123c97:	jne    1123bf0 <sort.block.block__anon_39113+0x60d0>
 1123c9d:	cmp    %rax,%r14
 1123ca0:	je     1123dd5 <sort.block.block__anon_39113+0x62b5>
 1123ca6:	mov    %rax,%r8
 1123ca9:	sub    %r11,%r8
 1123cac:	add    %r13,%r8
 1123caf:	mov    %rax,%rcx
 1123cb2:	mov    %rax,%r13
 1123cb5:	sub    %r8,%rcx
 1123cb8:	jbe    1123260 <sort.block.block__anon_39113+0x5740>
 1123cbe:	movzwl (%r10,%r8,2),%edi
 1123cc3:	mov    -0x30(%rbp),%rdx
 1123cc7:	mov    (%rdx),%rdx
 1123cca:	shl    $0x4,%edi
 1123ccd:	lea    (%rdx,%rdi,1),%rsi
 1123cd1:	mov    (%rdx,%rdi,1),%rdi
 1123cd5:	mov    %r8,%r13
 1123cd8:	jmp    1123cfa <sort.block.block__anon_39113+0x61da>
 1123cda:	nopw   0x0(%rax,%rax,1)
 1123ce0:	mov    %ecx,%r9d
 1123ce3:	and    $0x1,%r9d
 1123ce7:	add    %r8,%r9
 1123cea:	add    %r9,%r13
 1123ced:	cmp    $0x1,%rcx
 1123cf1:	mov    %r8,%rcx
 1123cf4:	jbe    1123260 <sort.block.block__anon_39113+0x5740>
 1123cfa:	lea    (%r10,%r13,2),%r8
 1123cfe:	mov    %rcx,%r9
 1123d01:	and    $0xfffffffffffffffe,%r9
 1123d05:	movzwl (%r9,%r8,1),%r8d
 1123d0a:	shl    $0x4,%r8d
 1123d0e:	cmp    (%rdx,%r8,1),%rdi
 1123d12:	jne    1123d21 <sort.block.block__anon_39113+0x6201>
 1123d14:	add    %rdx,%r8
 1123d17:	movzwl 0xe(%rsi),%r9d
 1123d1c:	cmp    0xe(%r8),%r9w
 1123d21:	setb   %r9b
 1123d25:	mov    %rcx,%r8
 1123d28:	shr    %r8
 1123d2b:	test   %r9b,%r9b
 1123d2e:	je     1123ce0 <sort.block.block__anon_39113+0x61c0>
 1123d30:	xor    %r9d,%r9d
 1123d33:	add    %r9,%r13
 1123d36:	cmp    $0x1,%rcx
 1123d3a:	mov    %r8,%rcx
 1123d3d:	ja     1123cfa <sort.block.block__anon_39113+0x61da>
 1123d3f:	jmp    1123260 <sort.block.block__anon_39113+0x5740>
 1123d44:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123d50:	xor    %eax,%eax
 1123d52:	jmp    1123dac <sort.block.block__anon_39113+0x628c>
 1123d54:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123d60:	mov    %r14,%rax
 1123d63:	sub    %r11,%rax
 1123d66:	mov    %rax,-0x60(%rbp)
 1123d6a:	jne    1123fd0 <sort.block.block__anon_39113+0x64b0>
 1123d70:	xor    %esi,%esi
 1123d72:	xor    %ecx,%ecx
 1123d74:	lea    (%rsi,%r13,1),%rax
 1123d78:	sub    %rax,%r11
 1123d7b:	je     1123dd5 <sort.block.block__anon_39113+0x62b5>
 1123d7d:	jmp    11240dd <sort.block.block__anon_39113+0x65bd>
 1123d82:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123d90:	add    %rdi,%rsi
 1123d93:	mov    %rsi,%r13
 1123d96:	mov    -0x38(%rbp),%r10
 1123d9a:	mov    -0x88(%rbp),%r15
 1123da1:	mov    -0x40(%rbp),%rbx
 1123da5:	mov    -0x128(%rbp),%rdx
 1123dac:	lea    -0x650(,%rax,2),%rsi
 1123db4:	add    %rbp,%rsi
 1123db7:	sub    %rax,%rdx
 1123dba:	lea    (%r10,%r13,2),%rdi
 1123dbe:	add    %rdx,%rdx
 1123dc1:	vzeroupper 
 1123dc4:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 1123dc9:	mov    -0x38(%rbp),%r10
 1123dcd:	vmovdqa -0x1215b5(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1123dd5:	mov    -0xe0(%rbp),%r13
 1123ddc:	sub    %r14,%r13
 1123ddf:	cmpb   $0x0,-0x140(%rbp)
 1123de6:	je     1123e20 <sort.block.block__anon_39113+0x6300>
 1123de8:	cmpq   $0x200,-0x100(%rbp)
 1123df3:	jae    1123e50 <sort.block.block__anon_39113+0x6330>
 1123df5:	lea    -0x650(%rbp),%rdi
 1123dfc:	mov    %r12,%rsi
 1123dff:	mov    -0x238(%rbp),%rdx
 1123e06:	vzeroupper 
 1123e09:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 1123e0e:	vmovdqa -0x1215f6(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1123e16:	mov    -0x38(%rbp),%r10
 1123e1a:	jmp    1123f6e <sort.block.block__anon_39113+0x644e>
 1123e1f:	nop
 1123e20:	lea    (%r10,%r14,2),%rax
 1123e24:	mov    %rbx,%rdx
 1123e27:	sub    %r14,%rdx
 1123e2a:	mov    %rdx,%rcx
 1123e2d:	shr    %rcx
 1123e30:	cmp    $0x20,%rdx
 1123e34:	setb   %sil
 1123e38:	cmp    $0xf,%rcx
 1123e3c:	sete   %dil
 1123e40:	or     %sil,%dil
 1123e43:	je     1123fb0 <sort.block.block__anon_39113+0x6490>
 1123e49:	xor    %esi,%esi
 1123e4b:	jmp    11243d0 <sort.block.block__anon_39113+0x68b0>
 1123e50:	mov    -0x230(%rbp),%rdx
 1123e57:	xor    %eax,%eax
 1123e59:	mov    -0xb0(%rbp),%rdi
 1123e60:	mov    -0x110(%rbp),%r8
 1123e67:	mov    -0x1d0(%rbp),%r9
 1123e6e:	xchg   %ax,%ax
 1123e70:	mov    %rdx,%rcx
 1123e73:	movzbl (%r12,%rax,2),%edx
 1123e78:	movzbl -0x7(%r9,%rax,2),%esi
 1123e7e:	mov    %sil,(%r12,%rax,2)
 1123e82:	mov    %dl,-0x7(%r9,%rax,2)
 1123e87:	movzbl 0x1(%r12,%rax,2),%edx
 1123e8d:	movzbl -0x6(%r9,%rax,2),%esi
 1123e93:	mov    %sil,0x1(%r12,%rax,2)
 1123e98:	mov    %dl,-0x6(%r9,%rax,2)
 1123e9d:	movzbl 0x2(%r12,%rax,2),%edx
 1123ea3:	movzbl -0x5(%r9,%rax,2),%esi
 1123ea9:	mov    %sil,0x2(%r12,%rax,2)
 1123eae:	mov    %dl,-0x5(%r9,%rax,2)
 1123eb3:	movzbl 0x3(%r12,%rax,2),%edx
 1123eb9:	movzbl -0x4(%r9,%rax,2),%esi
 1123ebf:	mov    %sil,0x3(%r12,%rax,2)
 1123ec4:	mov    %dl,-0x4(%r9,%rax,2)
 1123ec9:	movzbl 0x4(%r12,%rax,2),%edx
 1123ecf:	movzbl -0x3(%r9,%rax,2),%esi
 1123ed5:	mov    %sil,0x4(%r12,%rax,2)
 1123eda:	mov    %dl,-0x3(%r9,%rax,2)
 1123edf:	movzbl 0x5(%r12,%rax,2),%edx
 1123ee5:	movzbl -0x2(%r9,%rax,2),%esi
 1123eeb:	mov    %sil,0x5(%r12,%rax,2)
 1123ef0:	mov    %dl,-0x2(%r9,%rax,2)
 1123ef5:	movzbl 0x6(%r12,%rax,2),%edx
 1123efb:	movzbl -0x1(%r9,%rax,2),%esi
 1123f01:	mov    %sil,0x6(%r12,%rax,2)
 1123f06:	mov    %dl,-0x1(%r9,%rax,2)
 1123f0b:	movzbl 0x7(%r12,%rax,2),%edx
 1123f11:	movzbl (%r9,%rax,2),%esi
 1123f16:	mov    %sil,0x7(%r12,%rax,2)
 1123f1b:	mov    %dl,(%r9,%rax,2)
 1123f1f:	add    $0x4,%rax
 1123f23:	lea    0x8(%rcx),%rdx
 1123f27:	cmp    %rax,%r8
 1123f2a:	jne    1123e70 <sort.block.block__anon_39113+0x6350>
 1123f30:	test   %rdi,%rdi
 1123f33:	je     1123f6e <sort.block.block__anon_39113+0x644e>
 1123f35:	mov    -0xb0(%rbp),%rdx
 1123f3c:	nopl   0x0(%rax)
 1123f40:	movzbl (%r12,%rax,2),%esi
 1123f45:	movzbl -0x1(%rcx),%edi
 1123f49:	mov    %dil,(%r12,%rax,2)
 1123f4d:	mov    %sil,-0x1(%rcx)
 1123f51:	movzbl 0x1(%r12,%rax,2),%esi
 1123f57:	movzbl (%rcx),%edi
 1123f5a:	mov    %dil,0x1(%r12,%rax,2)
 1123f5f:	mov    %sil,(%rcx)
 1123f62:	inc    %rax
 1123f65:	add    $0x2,%rcx
 1123f69:	dec    %rdx
 1123f6c:	jne    1123f40 <sort.block.block__anon_39113+0x6420>
 1123f6e:	mov    -0xe0(%rbp),%rdx
 1123f75:	cmp    %r14,%rdx
 1123f78:	mov    -0xe8(%rbp),%r12
 1123f7f:	je     1122d90 <sort.block.block__anon_39113+0x5270>
 1123f85:	mov    -0x78(%rbp),%rax
 1123f89:	sub    %r13,%rax
 1123f8c:	lea    (%r10,%rax,2),%rax
 1123f90:	mov    %r14,%rcx
 1123f93:	sub    %rdx,%rcx
 1123f96:	cmp    $0xfffffffffffffffc,%rcx
 1123f9a:	jbe    1124131 <sort.block.block__anon_39113+0x6611>
 1123fa0:	xor    %ecx,%ecx
 1123fa2:	jmp    1124201 <sort.block.block__anon_39113+0x66e1>
 1123fa7:	nopw   0x0(%rax,%rax,1)
 1123fb0:	lea    -0x10(%rcx),%rsi
 1123fb4:	mov    %rsi,%rdi
 1123fb7:	shr    $0x4,%rdi
 1123fbb:	inc    %rdi
 1123fbe:	cmp    $0x30,%rsi
 1123fc2:	jae    1124258 <sort.block.block__anon_39113+0x6738>
 1123fc8:	xor    %r10d,%r10d
 1123fcb:	jmp    1124380 <sort.block.block__anon_39113+0x6860>
 1123fd0:	mov    %r14,-0x1c8(%rbp)
 1123fd7:	lea    (%r10,%r11,2),%rdi
 1123fdb:	mov    -0x50(%rbp),%rax
 1123fdf:	lea    (%rax,%r13,2),%rbx
 1123fe3:	xor    %esi,%esi
 1123fe5:	xor    %r8d,%r8d
 1123fe8:	xor    %eax,%eax
 1123fea:	mov    %rdx,-0x128(%rbp)
 1123ff1:	mov    %rax,%rcx
 1123ff4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1124000:	mov    %r11,%r9
 1124003:	movzwl (%rdi,%r8,2),%r10d
 1124008:	mov    -0x68(%rbp),%rax
 112400c:	mov    %rsi,%r14
 112400f:	movzwl (%rax,%rsi,2),%eax
 1124013:	mov    -0x30(%rbp),%rdx
 1124017:	mov    (%rdx),%r15
 112401a:	mov    %r10d,%r11d
 112401d:	shl    $0x4,%r11d
 1124021:	mov    %eax,%esi
 1124023:	shl    $0x4,%esi
 1124026:	mov    (%r15,%rsi,1),%rdx
 112402a:	cmp    %rdx,(%r15,%r11,1)
 112402e:	jne    112403f <sort.block.block__anon_39113+0x651f>
 1124030:	add    %r15,%r11
 1124033:	add    %r15,%rsi
 1124036:	movzwl 0xe(%r11),%edx
 112403b:	cmp    0xe(%rsi),%dx
 112403f:	mov    %r9,%r11
 1124042:	jae    1124080 <sort.block.block__anon_39113+0x6560>
 1124044:	mov    %r10d,%eax
 1124047:	shr    $0x8,%eax
 112404a:	movzbl -0x1(%rbx,%rcx,2),%edx
 112404f:	mov    %r10b,-0x1(%rbx,%rcx,2)
 1124054:	mov    %dl,(%rdi,%r8,2)
 1124058:	movzbl (%rbx,%rcx,2),%edx
 112405c:	mov    %al,(%rbx,%rcx,2)
 112405f:	mov    %dl,0x1(%rdi,%r8,2)
 1124064:	inc    %r8
 1124067:	inc    %rcx
 112406a:	cmp    -0x60(%rbp),%r8
 112406e:	mov    %r14,%rsi
 1124071:	jb     1124000 <sort.block.block__anon_39113+0x64e0>
 1124073:	jmp    11240ba <sort.block.block__anon_39113+0x659a>
 1124075:	data16 cs nopw 0x0(%rax,%rax,1)
 1124080:	movzbl -0x1(%rbx,%rcx,2),%edx
 1124085:	mov    %al,-0x1(%rbx,%rcx,2)
 1124089:	mov    -0x68(%rbp),%rsi
 112408d:	mov    %dl,(%rsi,%r14,2)
 1124091:	movzbl (%rbx,%rcx,2),%edx
 1124095:	mov    %ah,(%rbx,%rcx,2)
 1124098:	mov    %dl,0x1(%rsi,%r14,2)
 112409d:	mov    %r14,%rsi
 11240a0:	inc    %rsi
 11240a3:	lea    0x1(%rcx),%rax
 11240a7:	mov    -0x128(%rbp),%rdx
 11240ae:	cmp    %rdx,%rsi
 11240b1:	jb     1123ff1 <sort.block.block__anon_39113+0x64d1>
 11240b7:	inc    %rcx
 11240ba:	mov    -0x38(%rbp),%r10
 11240be:	mov    -0x88(%rbp),%r15
 11240c5:	mov    -0x40(%rbp),%rbx
 11240c9:	mov    -0x1c8(%rbp),%r14
 11240d0:	lea    (%rsi,%r13,1),%rax
 11240d4:	sub    %rax,%r11
 11240d7:	je     1123dd5 <sort.block.block__anon_39113+0x62b5>
 11240dd:	add    %r13,%r13
 11240e0:	lea    0x0(,%rcx,2),%rax
 11240e8:	add    %r13,%rax
 11240eb:	add    -0x50(%rbp),%rax
 11240ef:	mov    -0x1a8(%rbp),%rcx
 11240f6:	lea    (%rcx,%rsi,2),%rcx
 11240fa:	xor    %edx,%edx
 11240fc:	nopl   0x0(%rax)
 1124100:	movzbl -0x1(%rcx,%rdx,2),%esi
 1124105:	movzbl -0x1(%rax,%rdx,2),%edi
 112410a:	mov    %dil,-0x1(%rcx,%rdx,2)
 112410f:	mov    %sil,-0x1(%rax,%rdx,2)
 1124114:	movzbl (%rcx,%rdx,2),%esi
 1124118:	movzbl (%rax,%rdx,2),%edi
 112411c:	mov    %dil,(%rcx,%rdx,2)
 1124120:	mov    %sil,(%rax,%rdx,2)
 1124124:	inc    %rdx
 1124127:	cmp    %rdx,%r11
 112412a:	jne    1124100 <sort.block.block__anon_39113+0x65e0>
 112412c:	jmp    1123dd5 <sort.block.block__anon_39113+0x62b5>
 1124131:	mov    %r13,%rdx
 1124134:	and    $0xfffffffffffffffc,%rdx
 1124138:	mov    -0x80(%rbp),%rcx
 112413c:	lea    (%rcx,%r14,2),%rsi
 1124140:	xor    %ecx,%ecx
 1124142:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1124150:	movzbl -0x7(%rsi,%rcx,2),%edi
 1124155:	movzbl (%rax,%rcx,2),%r8d
 112415a:	mov    %r8b,-0x7(%rsi,%rcx,2)
 112415f:	mov    %dil,(%rax,%rcx,2)
 1124163:	movzbl -0x6(%rsi,%rcx,2),%edi
 1124168:	movzbl 0x1(%rax,%rcx,2),%r8d
 112416e:	mov    %r8b,-0x6(%rsi,%rcx,2)
 1124173:	mov    %dil,0x1(%rax,%rcx,2)
 1124178:	movzbl -0x5(%rsi,%rcx,2),%edi
 112417d:	movzbl 0x2(%rax,%rcx,2),%r8d
 1124183:	mov    %r8b,-0x5(%rsi,%rcx,2)
 1124188:	mov    %dil,0x2(%rax,%rcx,2)
 112418d:	movzbl -0x4(%rsi,%rcx,2),%edi
 1124192:	movzbl 0x3(%rax,%rcx,2),%r8d
 1124198:	mov    %r8b,-0x4(%rsi,%rcx,2)
 112419d:	mov    %dil,0x3(%rax,%rcx,2)
 11241a2:	movzbl -0x3(%rsi,%rcx,2),%edi
 11241a7:	movzbl 0x4(%rax,%rcx,2),%r8d
 11241ad:	mov    %r8b,-0x3(%rsi,%rcx,2)
 11241b2:	mov    %dil,0x4(%rax,%rcx,2)
 11241b7:	movzbl -0x2(%rsi,%rcx,2),%edi
 11241bc:	movzbl 0x5(%rax,%rcx,2),%r8d
 11241c2:	mov    %r8b,-0x2(%rsi,%rcx,2)
 11241c7:	mov    %dil,0x5(%rax,%rcx,2)
 11241cc:	movzbl -0x1(%rsi,%rcx,2),%edi
 11241d1:	movzbl 0x6(%rax,%rcx,2),%r8d
 11241d7:	mov    %r8b,-0x1(%rsi,%rcx,2)
 11241dc:	mov    %dil,0x6(%rax,%rcx,2)
 11241e1:	movzbl (%rsi,%rcx,2),%edi
 11241e5:	movzbl 0x7(%rax,%rcx,2),%r8d
 11241eb:	mov    %r8b,(%rsi,%rcx,2)
 11241ef:	mov    %dil,0x7(%rax,%rcx,2)
 11241f4:	add    $0x4,%rcx
 11241f8:	cmp    %rcx,%rdx
 11241fb:	jne    1124150 <sort.block.block__anon_39113+0x6630>
 1124201:	mov    %r13d,%edx
 1124204:	and    $0x3,%edx
 1124207:	je     1122d90 <sort.block.block__anon_39113+0x5270>
 112420d:	add    %r14,%r14
 1124210:	lea    (%r14,%rcx,2),%rsi
 1124214:	add    -0x50(%rbp),%rsi
 1124218:	xor    %edi,%edi
 112421a:	nopw   0x0(%rax,%rax,1)
 1124220:	movzbl -0x1(%rsi,%rdi,2),%r8d
 1124226:	movzbl (%rax,%rcx,2),%r9d
 112422b:	mov    %r9b,-0x1(%rsi,%rdi,2)
 1124230:	mov    %r8b,(%rax,%rcx,2)
 1124234:	movzbl (%rsi,%rdi,2),%r8d
 1124239:	movzbl 0x1(%rax,%rcx,2),%r9d
 112423f:	mov    %r9b,(%rsi,%rdi,2)
 1124243:	mov    %r8b,0x1(%rax,%rcx,2)
 1124248:	inc    %rcx
 112424b:	inc    %rdi
 112424e:	cmp    %rdi,%rdx
 1124251:	jne    1124220 <sort.block.block__anon_39113+0x6700>
 1124253:	jmp    1122d90 <sort.block.block__anon_39113+0x5270>
 1124258:	mov    %rdi,%rsi
 112425b:	movabs $0x1ffffffffffffffc,%r8
 1124265:	and    %r8,%rsi
 1124268:	mov    -0xc8(%rbp),%r8
 112426f:	lea    (%r8,%r14,2),%r8
 1124273:	xor    %r9d,%r9d
 1124276:	cs nopw 0x0(%rax,%rax,1)
 1124280:	mov    %r9,%r10
 1124283:	mov    %rdx,%r11
 1124286:	sub    %r9,%r11
 1124289:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124290:	vmovdqu -0x60(%r8,%r9,2),%ymm1
 1124297:	vpshufb %ymm2,%ymm1,%ymm1
 112429c:	vpermq $0x4e,%ymm1,%ymm1
 11242a2:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 11242a9:	or     $0x10,%r10
 11242ad:	vpshufb %ymm2,%ymm0,%ymm0
 11242b2:	vpermq $0x4e,%ymm0,%ymm0
 11242b8:	vmovdqu %ymm0,-0x60(%r8,%r9,2)
 11242bf:	mov    %r9,%r11
 11242c2:	mov    %rdx,%rbx
 11242c5:	sub    %r10,%rbx
 11242c8:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 11242ce:	vmovdqu -0x40(%r8,%r9,2),%ymm1
 11242d5:	vpshufb %ymm2,%ymm1,%ymm1
 11242da:	vpermq $0x4e,%ymm1,%ymm1
 11242e0:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 11242e6:	or     $0x20,%r11
 11242ea:	vpshufb %ymm2,%ymm0,%ymm0
 11242ef:	vpermq $0x4e,%ymm0,%ymm0
 11242f5:	vmovdqu %ymm0,-0x40(%r8,%r9,2)
 11242fc:	mov    %r9,%r10
 11242ff:	mov    %rdx,%rbx
 1124302:	sub    %r11,%rbx
 1124305:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 112430b:	vmovdqu -0x20(%r8,%r9,2),%ymm1
 1124312:	vpshufb %ymm2,%ymm1,%ymm1
 1124317:	vpermq $0x4e,%ymm1,%ymm1
 112431d:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124323:	or     $0x30,%r10
 1124327:	vpshufb %ymm2,%ymm0,%ymm0
 112432c:	vpermq $0x4e,%ymm0,%ymm0
 1124332:	vmovdqu %ymm0,-0x20(%r8,%r9,2)
 1124339:	mov    %rdx,%r11
 112433c:	sub    %r10,%r11
 112433f:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124346:	vmovdqu (%r8,%r9,2),%ymm1
 112434c:	vpshufb %ymm2,%ymm1,%ymm1
 1124351:	vpermq $0x4e,%ymm1,%ymm1
 1124357:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 112435e:	lea    0x40(%r9),%r10
 1124362:	vpshufb %ymm2,%ymm0,%ymm0
 1124367:	vpermq $0x4e,%ymm0,%ymm0
 112436d:	vmovdqu %ymm0,(%r8,%r9,2)
 1124373:	mov    %r10,%r9
 1124376:	add    $0xfffffffffffffffc,%rsi
 112437a:	jne    1124280 <sort.block.block__anon_39113+0x6760>
 1124380:	mov    %r10,%rsi
 1124383:	and    $0x3,%edi
 1124386:	mov    -0x40(%rbp),%rbx
 112438a:	je     11243d0 <sort.block.block__anon_39113+0x68b0>
 112438c:	nopl   0x0(%rax)
 1124390:	mov    %rdx,%rsi
 1124393:	sub    %r10,%rsi
 1124396:	vmovdqu -0x20(%rax,%rsi,2),%ymm0
 112439c:	vmovdqu (%rax,%r10,2),%ymm1
 11243a2:	vpshufb %ymm2,%ymm1,%ymm1
 11243a7:	vpermq $0x4e,%ymm1,%ymm1
 11243ad:	vmovdqu %ymm1,-0x20(%rax,%rsi,2)
 11243b3:	lea    0x10(%r10),%rsi
 11243b7:	vpshufb %ymm2,%ymm0,%ymm0
 11243bc:	vpermq $0x4e,%ymm0,%ymm0
 11243c2:	vmovdqu %ymm0,(%rax,%r10,2)
 11243c8:	mov    %rsi,%r10
 11243cb:	dec    %rdi
 11243ce:	jne    1124390 <sort.block.block__anon_39113+0x6870>
 11243d0:	mov    %rsi,%rdi
 11243d3:	sub    %rcx,%rdi
 11243d6:	jae    1124517 <sort.block.block__anon_39113+0x69f7>
 11243dc:	mov    %ecx,%r8d
 11243df:	sub    %esi,%r8d
 11243e2:	and    $0x3,%r8d
 11243e6:	je     1124426 <sort.block.block__anon_39113+0x6906>
 11243e8:	mov    -0x50(%rbp),%r9
 11243ec:	lea    (%r9,%r14,2),%r9
 11243f0:	mov    %rsi,%r10
 11243f3:	not    %r10
 11243f6:	movzbl -0x1(%r9,%rsi,2),%r11d
 11243fc:	movzbl (%r12,%r10,2),%ebx
 1124401:	mov    %bl,-0x1(%r9,%rsi,2)
 1124406:	mov    %r11b,(%r12,%r10,2)
 112440a:	movzbl (%r9,%rsi,2),%r11d
 112440f:	movzbl 0x1(%r12,%r10,2),%ebx
 1124415:	mov    %bl,(%r9,%rsi,2)
 1124419:	mov    %r11b,0x1(%r12,%r10,2)
 112441e:	inc    %rsi
 1124421:	dec    %r8
 1124424:	jne    11243f0 <sort.block.block__anon_39113+0x68d0>
 1124426:	cmp    $0xfffffffffffffffc,%rdi
 112442a:	mov    -0x40(%rbp),%rbx
 112442e:	ja     1124517 <sort.block.block__anon_39113+0x69f7>
 1124434:	mov    -0x80(%rbp),%rdi
 1124438:	lea    (%rdi,%r14,2),%rdi
 112443c:	nopl   0x0(%rax)
 1124440:	mov    %rsi,%r8
 1124443:	not    %r8
 1124446:	movzbl -0x7(%rdi,%rsi,2),%r9d
 112444c:	movzbl (%r12,%r8,2),%r10d
 1124451:	mov    %r10b,-0x7(%rdi,%rsi,2)
 1124456:	mov    %r9b,(%r12,%r8,2)
 112445a:	movzbl -0x6(%rdi,%rsi,2),%r9d
 1124460:	movzbl 0x1(%r12,%r8,2),%r10d
 1124466:	mov    %r10b,-0x6(%rdi,%rsi,2)
 112446b:	mov    %r9b,0x1(%r12,%r8,2)
 1124470:	mov    $0xfffffffffffffffe,%r8
 1124477:	sub    %rsi,%r8
 112447a:	movzbl -0x5(%rdi,%rsi,2),%r9d
 1124480:	movzbl (%r12,%r8,2),%r10d
 1124485:	mov    %r10b,-0x5(%rdi,%rsi,2)
 112448a:	mov    %r9b,(%r12,%r8,2)
 112448e:	movzbl -0x4(%rdi,%rsi,2),%r9d
 1124494:	movzbl 0x1(%r12,%r8,2),%r10d
 112449a:	mov    %r10b,-0x4(%rdi,%rsi,2)
 112449f:	mov    %r9b,0x1(%r12,%r8,2)
 11244a4:	mov    $0xfffffffffffffffd,%r8
 11244ab:	sub    %rsi,%r8
 11244ae:	movzbl -0x3(%rdi,%rsi,2),%r9d
 11244b4:	movzbl (%r12,%r8,2),%r10d
 11244b9:	mov    %r10b,-0x3(%rdi,%rsi,2)
 11244be:	mov    %r9b,(%r12,%r8,2)
 11244c2:	movzbl -0x2(%rdi,%rsi,2),%r9d
 11244c8:	movzbl 0x1(%r12,%r8,2),%r10d
 11244ce:	mov    %r10b,-0x2(%rdi,%rsi,2)
 11244d3:	mov    %r9b,0x1(%r12,%r8,2)
 11244d8:	mov    $0xfffffffffffffffc,%r8
 11244df:	sub    %rsi,%r8
 11244e2:	movzbl -0x1(%rdi,%rsi,2),%r9d
 11244e8:	movzbl (%r12,%r8,2),%r10d
 11244ed:	mov    %r10b,-0x1(%rdi,%rsi,2)
 11244f2:	mov    %r9b,(%r12,%r8,2)
 11244f6:	movzbl (%rdi,%rsi,2),%r9d
 11244fb:	movzbl 0x1(%r12,%r8,2),%r10d
 1124501:	mov    %r10b,(%rdi,%rsi,2)
 1124505:	mov    %r9b,0x1(%r12,%r8,2)
 112450a:	add    $0x4,%rsi
 112450e:	cmp    %rsi,%rcx
 1124511:	jne    1124440 <sort.block.block__anon_39113+0x6920>
 1124517:	mov    -0x78(%rbp),%rcx
 112451b:	sub    %r14,%rcx
 112451e:	mov    %rcx,%rdi
 1124521:	sub    %rdx,%rdi
 1124524:	mov    %rdi,%rdx
 1124527:	shr    %rdx
 112452a:	cmp    $0xf,%rdx
 112452e:	jne    1124540 <sort.block.block__anon_39113+0x6a20>
 1124530:	xor    %esi,%esi
 1124532:	jmp    11246d9 <sort.block.block__anon_39113+0x6bb9>
 1124537:	nopw   0x0(%rax,%rax,1)
 1124540:	lea    -0x10(%rdx),%rsi
 1124544:	mov    %rsi,%r8
 1124547:	shr    $0x4,%r8
 112454b:	inc    %r8
 112454e:	cmp    $0x30,%rsi
 1124552:	jae    112455b <sort.block.block__anon_39113+0x6a3b>
 1124554:	xor    %esi,%esi
 1124556:	jmp    1124674 <sort.block.block__anon_39113+0x6b54>
 112455b:	mov    %r8,%r9
 112455e:	movabs $0x1ffffffffffffffc,%rsi
 1124568:	and    %rsi,%r9
 112456b:	xor    %r10d,%r10d
 112456e:	xchg   %ax,%ax
 1124570:	mov    %r10,%rsi
 1124573:	mov    %rdi,%r11
 1124576:	sub    %r10,%r11
 1124579:	vmovdqu -0x20(%r12,%r11,2),%ymm0
 1124580:	vmovdqu (%r12,%r10,2),%ymm1
 1124586:	vpshufb %ymm2,%ymm1,%ymm1
 112458b:	vpermq $0x4e,%ymm1,%ymm1
 1124591:	vmovdqu %ymm1,-0x20(%r12,%r11,2)
 1124598:	or     $0x10,%rsi
 112459c:	vpshufb %ymm2,%ymm0,%ymm0
 11245a1:	vpermq $0x4e,%ymm0,%ymm0
 11245a7:	vmovdqu %ymm0,(%r12,%r10,2)
 11245ad:	mov    %r10,%r11
 11245b0:	mov    %rdi,%rbx
 11245b3:	sub    %rsi,%rbx
 11245b6:	vmovdqu -0x20(%r12,%rbx,2),%ymm0
 11245bd:	vmovdqu 0x20(%r12,%r10,2),%ymm1
 11245c4:	vpshufb %ymm2,%ymm1,%ymm1
 11245c9:	vpermq $0x4e,%ymm1,%ymm1
 11245cf:	vmovdqu %ymm1,-0x20(%r12,%rbx,2)
 11245d6:	or     $0x20,%r11
 11245da:	vpshufb %ymm2,%ymm0,%ymm0
 11245df:	vpermq $0x4e,%ymm0,%ymm0
 11245e5:	vmovdqu %ymm0,0x20(%r12,%r10,2)
 11245ec:	mov    %r10,%rsi
 11245ef:	mov    %rdi,%rbx
 11245f2:	sub    %r11,%rbx
 11245f5:	vmovdqu -0x20(%r12,%rbx,2),%ymm0
 11245fc:	vmovdqu 0x40(%r12,%r10,2),%ymm1
 1124603:	vpshufb %ymm2,%ymm1,%ymm1
 1124608:	vpermq $0x4e,%ymm1,%ymm1
 112460e:	vmovdqu %ymm1,-0x20(%r12,%rbx,2)
 1124615:	or     $0x30,%rsi
 1124619:	vpshufb %ymm2,%ymm0,%ymm0
 112461e:	vpermq $0x4e,%ymm0,%ymm0
 1124624:	vmovdqu %ymm0,0x40(%r12,%r10,2)
 112462b:	mov    %rdi,%r11
 112462e:	sub    %rsi,%r11
 1124631:	vmovdqu -0x20(%r12,%r11,2),%ymm0
 1124638:	vmovdqu 0x60(%r12,%r10,2),%ymm1
 112463f:	vpshufb %ymm2,%ymm1,%ymm1
 1124644:	vpermq $0x4e,%ymm1,%ymm1
 112464a:	vmovdqu %ymm1,-0x20(%r12,%r11,2)
 1124651:	lea    0x40(%r10),%rsi
 1124655:	vpshufb %ymm2,%ymm0,%ymm0
 112465a:	vpermq $0x4e,%ymm0,%ymm0
 1124660:	vmovdqu %ymm0,0x60(%r12,%r10,2)
 1124667:	mov    %rsi,%r10
 112466a:	add    $0xfffffffffffffffc,%r9
 112466e:	jne    1124570 <sort.block.block__anon_39113+0x6a50>
 1124674:	and    $0x3,%r8d
 1124678:	mov    -0x40(%rbp),%rbx
 112467c:	je     11246d9 <sort.block.block__anon_39113+0x6bb9>
 112467e:	shl    $0x4,%r8d
 1124682:	xor    %r9d,%r9d
 1124685:	mov    %rsi,%r10
 1124688:	nopl   0x0(%rax,%rax,1)
 1124690:	mov    %rdi,%r11
 1124693:	sub    %r10,%r11
 1124696:	vmovdqu -0x20(%r12,%r11,2),%ymm0
 112469d:	vmovdqu (%r12,%r10,2),%ymm1
 11246a3:	vpshufb %ymm2,%ymm1,%ymm1
 11246a8:	vpermq $0x4e,%ymm1,%ymm1
 11246ae:	vmovdqu %ymm1,-0x20(%r12,%r11,2)
 11246b5:	vpshufb %ymm2,%ymm0,%ymm0
 11246ba:	vpermq $0x4e,%ymm0,%ymm0
 11246c0:	vmovdqu %ymm0,(%r12,%r10,2)
 11246c6:	add    $0x10,%r10
 11246ca:	add    $0xfffffffffffffff0,%r9
 11246ce:	mov    %r8,%r11
 11246d1:	add    %r9,%r11
 11246d4:	jne    1124690 <sort.block.block__anon_39113+0x6b70>
 11246d6:	sub    %r9,%rsi
 11246d9:	mov    %rsi,%r8
 11246dc:	sub    %rdx,%r8
 11246df:	jae    1124848 <sort.block.block__anon_39113+0x6d28>
 11246e5:	lea    (%r12,%rdi,2),%rdi
 11246e9:	mov    %edx,%r9d
 11246ec:	sub    %esi,%r9d
 11246ef:	and    $0x3,%r9d
 11246f3:	je     112475b <sort.block.block__anon_39113+0x6c3b>
 11246f5:	mov    %r13,-0x60(%rbp)
 11246f9:	neg    %r9
 11246fc:	xor    %r10d,%r10d
 11246ff:	mov    %rsi,%r11
 1124702:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1124710:	mov    %r11,%rbx
 1124713:	not    %rbx
 1124716:	movzbl (%r12,%r11,2),%r15d
 112471b:	movzbl (%rdi,%rbx,2),%r13d
 1124720:	mov    %r13b,(%r12,%r11,2)
 1124724:	mov    %r15b,(%rdi,%rbx,2)
 1124728:	movzbl 0x1(%r12,%r11,2),%r15d
 112472e:	movzbl 0x1(%rdi,%rbx,2),%r13d
 1124734:	mov    %r13b,0x1(%r12,%r11,2)
 1124739:	mov    %r15b,0x1(%rdi,%rbx,2)
 112473e:	inc    %r11
 1124741:	dec    %r10
 1124744:	cmp    %r10,%r9
 1124747:	jne    1124710 <sort.block.block__anon_39113+0x6bf0>
 1124749:	sub    %r10,%rsi
 112474c:	mov    -0x88(%rbp),%r15
 1124753:	mov    -0x40(%rbp),%rbx
 1124757:	mov    -0x60(%rbp),%r13
 112475b:	cmp    $0xfffffffffffffffc,%r8
 112475f:	ja     1124848 <sort.block.block__anon_39113+0x6d28>
 1124765:	sub    %rsi,%rdx
 1124768:	nopl   0x0(%rax,%rax,1)
 1124770:	mov    %rsi,%r8
 1124773:	not    %r8
 1124776:	movzbl (%r12,%rsi,2),%r9d
 112477b:	movzbl (%rdi,%r8,2),%r10d
 1124780:	mov    %r10b,(%r12,%rsi,2)
 1124784:	mov    %r9b,(%rdi,%r8,2)
 1124788:	movzbl 0x1(%r12,%rsi,2),%r9d
 112478e:	movzbl 0x1(%rdi,%r8,2),%r10d
 1124794:	mov    %r10b,0x1(%r12,%rsi,2)
 1124799:	mov    %r9b,0x1(%rdi,%r8,2)
 112479e:	mov    $0xfffffffffffffffe,%r8
 11247a5:	sub    %rsi,%r8
 11247a8:	movzbl 0x2(%r12,%rsi,2),%r9d
 11247ae:	movzbl (%rdi,%r8,2),%r10d
 11247b3:	mov    %r10b,0x2(%r12,%rsi,2)
 11247b8:	mov    %r9b,(%rdi,%r8,2)
 11247bc:	movzbl 0x3(%r12,%rsi,2),%r9d
 11247c2:	movzbl 0x1(%rdi,%r8,2),%r10d
 11247c8:	mov    %r10b,0x3(%r12,%rsi,2)
 11247cd:	mov    %r9b,0x1(%rdi,%r8,2)
 11247d2:	mov    $0xfffffffffffffffd,%r8
 11247d9:	sub    %rsi,%r8
 11247dc:	movzbl 0x4(%r12,%rsi,2),%r9d
 11247e2:	movzbl (%rdi,%r8,2),%r10d
 11247e7:	mov    %r10b,0x4(%r12,%rsi,2)
 11247ec:	mov    %r9b,(%rdi,%r8,2)
 11247f0:	movzbl 0x5(%r12,%rsi,2),%r9d
 11247f6:	movzbl 0x1(%rdi,%r8,2),%r10d
 11247fc:	mov    %r10b,0x5(%r12,%rsi,2)
 1124801:	mov    %r9b,0x1(%rdi,%r8,2)
 1124806:	mov    $0xfffffffffffffffc,%r8
 112480d:	sub    %rsi,%r8
 1124810:	movzbl 0x6(%r12,%rsi,2),%r9d
 1124816:	movzbl (%rdi,%r8,2),%r10d
 112481b:	mov    %r10b,0x6(%r12,%rsi,2)
 1124820:	mov    %r9b,(%rdi,%r8,2)
 1124824:	movzbl 0x7(%r12,%rsi,2),%r9d
 112482a:	movzbl 0x1(%rdi,%r8,2),%r10d
 1124830:	mov    %r10b,0x7(%r12,%rsi,2)
 1124835:	mov    %r9b,0x1(%rdi,%r8,2)
 112483a:	add    $0x4,%rsi
 112483e:	add    $0xfffffffffffffffc,%rdx
 1124842:	jne    1124770 <sort.block.block__anon_39113+0x6c50>
 1124848:	mov    %rcx,%rdx
 112484b:	shr    %rdx
 112484e:	cmp    $0x20,%rcx
 1124852:	setb   %sil
 1124856:	cmp    $0xf,%rdx
 112485a:	sete   %dil
 112485e:	or     %sil,%dil
 1124861:	je     1124880 <sort.block.block__anon_39113+0x6d60>
 1124863:	xor    %esi,%esi
 1124865:	mov    -0xe8(%rbp),%r12
 112486c:	jmp    1124a20 <sort.block.block__anon_39113+0x6f00>
 1124871:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1124880:	lea    -0x10(%rdx),%rsi
 1124884:	mov    %rsi,%rdi
 1124887:	shr    $0x4,%rdi
 112488b:	inc    %rdi
 112488e:	cmp    $0x30,%rsi
 1124892:	mov    -0xe8(%rbp),%r12
 1124899:	jae    11248a3 <sort.block.block__anon_39113+0x6d83>
 112489b:	xor    %r10d,%r10d
 112489e:	jmp    11249d0 <sort.block.block__anon_39113+0x6eb0>
 11248a3:	mov    %rdi,%rsi
 11248a6:	movabs $0x1ffffffffffffffc,%r8
 11248b0:	and    %r8,%rsi
 11248b3:	mov    -0xc8(%rbp),%r8
 11248ba:	lea    (%r8,%r14,2),%r8
 11248be:	xor    %r9d,%r9d
 11248c1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11248d0:	mov    %r9,%r10
 11248d3:	mov    %rcx,%r11
 11248d6:	sub    %r9,%r11
 11248d9:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 11248e0:	vmovdqu -0x60(%r8,%r9,2),%ymm1
 11248e7:	vpshufb %ymm2,%ymm1,%ymm1
 11248ec:	vpermq $0x4e,%ymm1,%ymm1
 11248f2:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 11248f9:	or     $0x10,%r10
 11248fd:	vpshufb %ymm2,%ymm0,%ymm0
 1124902:	vpermq $0x4e,%ymm0,%ymm0
 1124908:	vmovdqu %ymm0,-0x60(%r8,%r9,2)
 112490f:	mov    %r9,%r11
 1124912:	mov    %rcx,%rbx
 1124915:	sub    %r10,%rbx
 1124918:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 112491e:	vmovdqu -0x40(%r8,%r9,2),%ymm1
 1124925:	vpshufb %ymm2,%ymm1,%ymm1
 112492a:	vpermq $0x4e,%ymm1,%ymm1
 1124930:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124936:	or     $0x20,%r11
 112493a:	vpshufb %ymm2,%ymm0,%ymm0
 112493f:	vpermq $0x4e,%ymm0,%ymm0
 1124945:	vmovdqu %ymm0,-0x40(%r8,%r9,2)
 112494c:	mov    %r9,%r10
 112494f:	mov    %rcx,%rbx
 1124952:	sub    %r11,%rbx
 1124955:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 112495b:	vmovdqu -0x20(%r8,%r9,2),%ymm1
 1124962:	vpshufb %ymm2,%ymm1,%ymm1
 1124967:	vpermq $0x4e,%ymm1,%ymm1
 112496d:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124973:	or     $0x30,%r10
 1124977:	vpshufb %ymm2,%ymm0,%ymm0
 112497c:	vpermq $0x4e,%ymm0,%ymm0
 1124982:	vmovdqu %ymm0,-0x20(%r8,%r9,2)
 1124989:	mov    %rcx,%r11
 112498c:	sub    %r10,%r11
 112498f:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124996:	vmovdqu (%r8,%r9,2),%ymm1
 112499c:	vpshufb %ymm2,%ymm1,%ymm1
 11249a1:	vpermq $0x4e,%ymm1,%ymm1
 11249a7:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 11249ae:	lea    0x40(%r9),%r10
 11249b2:	vpshufb %ymm2,%ymm0,%ymm0
 11249b7:	vpermq $0x4e,%ymm0,%ymm0
 11249bd:	vmovdqu %ymm0,(%r8,%r9,2)
 11249c3:	mov    %r10,%r9
 11249c6:	add    $0xfffffffffffffffc,%rsi
 11249ca:	jne    11248d0 <sort.block.block__anon_39113+0x6db0>
 11249d0:	mov    %r10,%rsi
 11249d3:	and    $0x3,%edi
 11249d6:	mov    -0x40(%rbp),%rbx
 11249da:	je     1124a20 <sort.block.block__anon_39113+0x6f00>
 11249dc:	nopl   0x0(%rax)
 11249e0:	mov    %rcx,%rsi
 11249e3:	sub    %r10,%rsi
 11249e6:	vmovdqu -0x20(%rax,%rsi,2),%ymm0
 11249ec:	vmovdqu (%rax,%r10,2),%ymm1
 11249f2:	vpshufb %ymm2,%ymm1,%ymm1
 11249f7:	vpermq $0x4e,%ymm1,%ymm1
 11249fd:	vmovdqu %ymm1,-0x20(%rax,%rsi,2)
 1124a03:	lea    0x10(%r10),%rsi
 1124a07:	vpshufb %ymm2,%ymm0,%ymm0
 1124a0c:	vpermq $0x4e,%ymm0,%ymm0
 1124a12:	vmovdqu %ymm0,(%rax,%r10,2)
 1124a18:	mov    %rsi,%r10
 1124a1b:	dec    %rdi
 1124a1e:	jne    11249e0 <sort.block.block__anon_39113+0x6ec0>
 1124a20:	mov    %rsi,%rcx
 1124a23:	sub    %rdx,%rcx
 1124a26:	mov    -0x38(%rbp),%r10
 1124a2a:	jae    1122d90 <sort.block.block__anon_39113+0x5270>
 1124a30:	mov    -0x78(%rbp),%rax
 1124a34:	lea    (%r10,%rax,2),%rax
 1124a38:	mov    %edx,%edi
 1124a3a:	sub    %esi,%edi
 1124a3c:	and    $0x3,%edi
 1124a3f:	je     1124a86 <sort.block.block__anon_39113+0x6f66>
 1124a41:	mov    -0x50(%rbp),%r8
 1124a45:	lea    (%r8,%r14,2),%r8
 1124a49:	nopl   0x0(%rax)
 1124a50:	mov    %rsi,%r9
 1124a53:	not    %r9
 1124a56:	movzbl -0x1(%r8,%rsi,2),%r10d
 1124a5c:	movzbl (%rax,%r9,2),%r11d
 1124a61:	mov    %r11b,-0x1(%r8,%rsi,2)
 1124a66:	mov    %r10b,(%rax,%r9,2)
 1124a6a:	movzbl (%r8,%rsi,2),%r10d
 1124a6f:	movzbl 0x1(%rax,%r9,2),%r11d
 1124a75:	mov    %r11b,(%r8,%rsi,2)
 1124a79:	mov    %r10b,0x1(%rax,%r9,2)
 1124a7e:	inc    %rsi
 1124a81:	dec    %rdi
 1124a84:	jne    1124a50 <sort.block.block__anon_39113+0x6f30>
 1124a86:	cmp    $0xfffffffffffffffc,%rcx
 1124a8a:	mov    -0x38(%rbp),%r10
 1124a8e:	ja     1122d90 <sort.block.block__anon_39113+0x5270>
 1124a94:	mov    -0x80(%rbp),%rcx
 1124a98:	lea    (%rcx,%r14,2),%rcx
 1124a9c:	nopl   0x0(%rax)
 1124aa0:	mov    %rsi,%rdi
 1124aa3:	not    %rdi
 1124aa6:	movzbl -0x7(%rcx,%rsi,2),%r8d
 1124aac:	movzbl (%rax,%rdi,2),%r9d
 1124ab1:	mov    %r9b,-0x7(%rcx,%rsi,2)
 1124ab6:	mov    %r8b,(%rax,%rdi,2)
 1124aba:	movzbl -0x6(%rcx,%rsi,2),%r8d
 1124ac0:	movzbl 0x1(%rax,%rdi,2),%r9d
 1124ac6:	mov    %r9b,-0x6(%rcx,%rsi,2)
 1124acb:	mov    %r8b,0x1(%rax,%rdi,2)
 1124ad0:	mov    $0xfffffffffffffffe,%rdi
 1124ad7:	sub    %rsi,%rdi
 1124ada:	movzbl -0x5(%rcx,%rsi,2),%r8d
 1124ae0:	movzbl (%rax,%rdi,2),%r9d
 1124ae5:	mov    %r9b,-0x5(%rcx,%rsi,2)
 1124aea:	mov    %r8b,(%rax,%rdi,2)
 1124aee:	movzbl -0x4(%rcx,%rsi,2),%r8d
 1124af4:	movzbl 0x1(%rax,%rdi,2),%r9d
 1124afa:	mov    %r9b,-0x4(%rcx,%rsi,2)
 1124aff:	mov    %r8b,0x1(%rax,%rdi,2)
 1124b04:	mov    $0xfffffffffffffffd,%rdi
 1124b0b:	sub    %rsi,%rdi
 1124b0e:	movzbl -0x3(%rcx,%rsi,2),%r8d
 1124b14:	movzbl (%rax,%rdi,2),%r9d
 1124b19:	mov    %r9b,-0x3(%rcx,%rsi,2)
 1124b1e:	mov    %r8b,(%rax,%rdi,2)
 1124b22:	movzbl -0x2(%rcx,%rsi,2),%r8d
 1124b28:	movzbl 0x1(%rax,%rdi,2),%r9d
 1124b2e:	mov    %r9b,-0x2(%rcx,%rsi,2)
 1124b33:	mov    %r8b,0x1(%rax,%rdi,2)
 1124b38:	mov    $0xfffffffffffffffc,%rdi
 1124b3f:	sub    %rsi,%rdi
 1124b42:	movzbl -0x1(%rcx,%rsi,2),%r8d
 1124b48:	movzbl (%rax,%rdi,2),%r9d
 1124b4d:	mov    %r9b,-0x1(%rcx,%rsi,2)
 1124b52:	mov    %r8b,(%rax,%rdi,2)
 1124b56:	movzbl (%rcx,%rsi,2),%r8d
 1124b5b:	movzbl 0x1(%rax,%rdi,2),%r9d
 1124b61:	mov    %r9b,(%rcx,%rsi,2)
 1124b65:	mov    %r8b,0x1(%rax,%rdi,2)
 1124b6a:	add    $0x4,%rsi
 1124b6e:	cmp    %rsi,%rdx
 1124b71:	jne    1124aa0 <sort.block.block__anon_39113+0x6f80>
 1124b77:	jmp    1122d90 <sort.block.block__anon_39113+0x5270>
 1124b7c:	lea    -0x10(%rdx),%rdi
 1124b80:	mov    %rdi,%r8
 1124b83:	shr    $0x4,%r8
 1124b87:	inc    %r8
 1124b8a:	cmp    $0x30,%rdi
 1124b8e:	jae    1124b97 <sort.block.block__anon_39113+0x7077>
 1124b90:	xor    %edi,%edi
 1124b92:	jmp    1124cb0 <sort.block.block__anon_39113+0x7190>
 1124b97:	mov    %r8,%r9
 1124b9a:	movabs $0x1ffffffffffffffc,%rdi
 1124ba4:	and    %rdi,%r9
 1124ba7:	xor    %r10d,%r10d
 1124baa:	nopw   0x0(%rax,%rax,1)
 1124bb0:	mov    %r10,%rdi
 1124bb3:	mov    %rsi,%r11
 1124bb6:	sub    %r10,%r11
 1124bb9:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124bc0:	vmovdqu (%rax,%r10,2),%ymm1
 1124bc6:	vpshufb %ymm2,%ymm1,%ymm1
 1124bcb:	vpermq $0x4e,%ymm1,%ymm1
 1124bd1:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 1124bd8:	or     $0x10,%rdi
 1124bdc:	vpshufb %ymm2,%ymm0,%ymm0
 1124be1:	vpermq $0x4e,%ymm0,%ymm0
 1124be7:	vmovdqu %ymm0,(%rax,%r10,2)
 1124bed:	mov    %r10,%r11
 1124bf0:	mov    %rsi,%rbx
 1124bf3:	sub    %rdi,%rbx
 1124bf6:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 1124bfc:	vmovdqu 0x20(%rax,%r10,2),%ymm1
 1124c03:	vpshufb %ymm2,%ymm1,%ymm1
 1124c08:	vpermq $0x4e,%ymm1,%ymm1
 1124c0e:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124c14:	or     $0x20,%r11
 1124c18:	vpshufb %ymm2,%ymm0,%ymm0
 1124c1d:	vpermq $0x4e,%ymm0,%ymm0
 1124c23:	vmovdqu %ymm0,0x20(%rax,%r10,2)
 1124c2a:	mov    %r10,%rdi
 1124c2d:	mov    %rsi,%rbx
 1124c30:	sub    %r11,%rbx
 1124c33:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 1124c39:	vmovdqu 0x40(%rax,%r10,2),%ymm1
 1124c40:	vpshufb %ymm2,%ymm1,%ymm1
 1124c45:	vpermq $0x4e,%ymm1,%ymm1
 1124c4b:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124c51:	or     $0x30,%rdi
 1124c55:	vpshufb %ymm2,%ymm0,%ymm0
 1124c5a:	vpermq $0x4e,%ymm0,%ymm0
 1124c60:	vmovdqu %ymm0,0x40(%rax,%r10,2)
 1124c67:	mov    %rsi,%r11
 1124c6a:	sub    %rdi,%r11
 1124c6d:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124c74:	vmovdqu 0x60(%rax,%r10,2),%ymm1
 1124c7b:	vpshufb %ymm2,%ymm1,%ymm1
 1124c80:	vpermq $0x4e,%ymm1,%ymm1
 1124c86:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 1124c8d:	lea    0x40(%r10),%rdi
 1124c91:	vpshufb %ymm2,%ymm0,%ymm0
 1124c96:	vpermq $0x4e,%ymm0,%ymm0
 1124c9c:	vmovdqu %ymm0,0x60(%rax,%r10,2)
 1124ca3:	mov    %rdi,%r10
 1124ca6:	add    $0xfffffffffffffffc,%r9
 1124caa:	jne    1124bb0 <sort.block.block__anon_39113+0x7090>
 1124cb0:	and    $0x3,%r8d
 1124cb4:	mov    -0x40(%rbp),%rbx
 1124cb8:	je     1124d19 <sort.block.block__anon_39113+0x71f9>
 1124cba:	shl    $0x4,%r8d
 1124cbe:	xor    %r9d,%r9d
 1124cc1:	mov    %rdi,%r10
 1124cc4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1124cd0:	mov    %rsi,%r11
 1124cd3:	sub    %r10,%r11
 1124cd6:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124cdd:	vmovdqu (%rax,%r10,2),%ymm1
 1124ce3:	vpshufb %ymm2,%ymm1,%ymm1
 1124ce8:	vpermq $0x4e,%ymm1,%ymm1
 1124cee:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 1124cf5:	vpshufb %ymm2,%ymm0,%ymm0
 1124cfa:	vpermq $0x4e,%ymm0,%ymm0
 1124d00:	vmovdqu %ymm0,(%rax,%r10,2)
 1124d06:	add    $0x10,%r10
 1124d0a:	add    $0xfffffffffffffff0,%r9
 1124d0e:	mov    %r8,%r11
 1124d11:	add    %r9,%r11
 1124d14:	jne    1124cd0 <sort.block.block__anon_39113+0x71b0>
 1124d16:	sub    %r9,%rdi
 1124d19:	mov    %rdi,%r8
 1124d1c:	sub    %rdx,%r8
 1124d1f:	jae    1124e88 <sort.block.block__anon_39113+0x7368>
 1124d25:	mov    %edx,%r9d
 1124d28:	sub    %edi,%r9d
 1124d2b:	and    $0x3,%r9d
 1124d2f:	je     1124d9b <sort.block.block__anon_39113+0x727b>
 1124d31:	neg    %r9
 1124d34:	xor    %r10d,%r10d
 1124d37:	mov    %rdi,%r11
 1124d3a:	nopw   0x0(%rax,%rax,1)
 1124d40:	mov    %r11,%rbx
 1124d43:	not    %rbx
 1124d46:	movzbl (%rax,%r11,2),%r14d
 1124d4b:	mov    -0x70(%rbp),%rcx
 1124d4f:	movzbl (%rcx,%rbx,2),%r15d
 1124d54:	mov    %r15b,(%rax,%r11,2)
 1124d58:	mov    -0x70(%rbp),%rcx
 1124d5c:	mov    %r14b,(%rcx,%rbx,2)
 1124d60:	movzbl 0x1(%rax,%r11,2),%r14d
 1124d66:	mov    -0x70(%rbp),%rcx
 1124d6a:	movzbl 0x1(%rcx,%rbx,2),%r15d
 1124d70:	mov    %r15b,0x1(%rax,%r11,2)
 1124d75:	mov    -0x70(%rbp),%rcx
 1124d79:	mov    %r14b,0x1(%rcx,%rbx,2)
 1124d7e:	mov    -0x70(%rbp),%r14
 1124d82:	inc    %r11
 1124d85:	dec    %r10
 1124d88:	cmp    %r10,%r9
 1124d8b:	jne    1124d40 <sort.block.block__anon_39113+0x7220>
 1124d8d:	sub    %r10,%rdi
 1124d90:	mov    -0x88(%rbp),%r15
 1124d97:	mov    -0x40(%rbp),%rbx
 1124d9b:	cmp    $0xfffffffffffffffc,%r8
 1124d9f:	ja     1124e88 <sort.block.block__anon_39113+0x7368>
 1124da5:	sub    %rdi,%rdx
 1124da8:	nopl   0x0(%rax,%rax,1)
 1124db0:	mov    %rdi,%r8
 1124db3:	not    %r8
 1124db6:	movzbl (%rax,%rdi,2),%r9d
 1124dbb:	movzbl (%r14,%r8,2),%r10d
 1124dc0:	mov    %r10b,(%rax,%rdi,2)
 1124dc4:	mov    %r9b,(%r14,%r8,2)
 1124dc8:	movzbl 0x1(%rax,%rdi,2),%r9d
 1124dce:	movzbl 0x1(%r14,%r8,2),%r10d
 1124dd4:	mov    %r10b,0x1(%rax,%rdi,2)
 1124dd9:	mov    %r9b,0x1(%r14,%r8,2)
 1124dde:	mov    $0xfffffffffffffffe,%r8
 1124de5:	sub    %rdi,%r8
 1124de8:	movzbl 0x2(%rax,%rdi,2),%r9d
 1124dee:	movzbl (%r14,%r8,2),%r10d
 1124df3:	mov    %r10b,0x2(%rax,%rdi,2)
 1124df8:	mov    %r9b,(%r14,%r8,2)
 1124dfc:	movzbl 0x3(%rax,%rdi,2),%r9d
 1124e02:	movzbl 0x1(%r14,%r8,2),%r10d
 1124e08:	mov    %r10b,0x3(%rax,%rdi,2)
 1124e0d:	mov    %r9b,0x1(%r14,%r8,2)
 1124e12:	mov    $0xfffffffffffffffd,%r8
 1124e19:	sub    %rdi,%r8
 1124e1c:	movzbl 0x4(%rax,%rdi,2),%r9d
 1124e22:	movzbl (%r14,%r8,2),%r10d
 1124e27:	mov    %r10b,0x4(%rax,%rdi,2)
 1124e2c:	mov    %r9b,(%r14,%r8,2)
 1124e30:	movzbl 0x5(%rax,%rdi,2),%r9d
 1124e36:	movzbl 0x1(%r14,%r8,2),%r10d
 1124e3c:	mov    %r10b,0x5(%rax,%rdi,2)
 1124e41:	mov    %r9b,0x1(%r14,%r8,2)
 1124e46:	mov    $0xfffffffffffffffc,%r8
 1124e4d:	sub    %rdi,%r8
 1124e50:	movzbl 0x6(%rax,%rdi,2),%r9d
 1124e56:	movzbl (%r14,%r8,2),%r10d
 1124e5b:	mov    %r10b,0x6(%rax,%rdi,2)
 1124e60:	mov    %r9b,(%r14,%r8,2)
 1124e64:	movzbl 0x7(%rax,%rdi,2),%r9d
 1124e6a:	movzbl 0x1(%r14,%r8,2),%r10d
 1124e70:	mov    %r10b,0x7(%rax,%rdi,2)
 1124e75:	mov    %r9b,0x1(%r14,%r8,2)
 1124e7a:	add    $0x4,%rdi
 1124e7e:	add    $0xfffffffffffffffc,%rdx
 1124e82:	jne    1124db0 <sort.block.block__anon_39113+0x7290>
 1124e88:	mov    -0xd8(%rbp),%rdx
 1124e8f:	sub    %rbx,%rdx
 1124e92:	mov    %rdx,%r8
 1124e95:	sub    %rsi,%r8
 1124e98:	mov    %r8,%rsi
 1124e9b:	shr    %rsi
 1124e9e:	cmp    $0x20,%r8
 1124ea2:	setb   %dil
 1124ea6:	cmp    $0xf,%rsi
 1124eaa:	sete   %r9b
 1124eae:	or     %dil,%r9b
 1124eb1:	je     1124eba <sort.block.block__anon_39113+0x739a>
 1124eb3:	xor    %edi,%edi
 1124eb5:	jmp    112507d <sort.block.block__anon_39113+0x755d>
 1124eba:	lea    -0x10(%rsi),%rdi
 1124ebe:	mov    %rdi,%r9
 1124ec1:	shr    $0x4,%r9
 1124ec5:	inc    %r9
 1124ec8:	cmp    $0x30,%rdi
 1124ecc:	jae    1124ed5 <sort.block.block__anon_39113+0x73b5>
 1124ece:	xor    %edi,%edi
 1124ed0:	jmp    1125014 <sort.block.block__anon_39113+0x74f4>
 1124ed5:	mov    %r9,%r10
 1124ed8:	movabs $0x1ffffffffffffffc,%rdi
 1124ee2:	and    %rdi,%r10
 1124ee5:	xor    %r11d,%r11d
 1124ee8:	nopl   0x0(%rax,%rax,1)
 1124ef0:	mov    %r11,%rdi
 1124ef3:	mov    %r8,%rbx
 1124ef6:	sub    %r11,%rbx
 1124ef9:	vmovdqu -0x20(%r14,%rbx,2),%ymm0
 1124f00:	vmovdqu (%r14,%r11,2),%ymm1
 1124f06:	vpshufb %ymm2,%ymm1,%ymm1
 1124f0b:	vpermq $0x4e,%ymm1,%ymm1
 1124f11:	vmovdqu %ymm1,-0x20(%r14,%rbx,2)
 1124f18:	or     $0x10,%rdi
 1124f1c:	vpshufb %ymm2,%ymm0,%ymm0
 1124f21:	vpermq $0x4e,%ymm0,%ymm0
 1124f27:	vmovdqu %ymm0,(%r14,%r11,2)
 1124f2d:	mov    %r11,%rbx
 1124f30:	mov    %r8,%r14
 1124f33:	sub    %rdi,%r14
 1124f36:	mov    -0x70(%rbp),%rcx
 1124f3a:	vmovdqu -0x20(%rcx,%r14,2),%ymm0
 1124f41:	mov    -0x70(%rbp),%rcx
 1124f45:	vmovdqu 0x20(%rcx,%r11,2),%ymm1
 1124f4c:	vpshufb %ymm2,%ymm1,%ymm1
 1124f51:	vpermq $0x4e,%ymm1,%ymm1
 1124f57:	mov    -0x70(%rbp),%rcx
 1124f5b:	vmovdqu %ymm1,-0x20(%rcx,%r14,2)
 1124f62:	or     $0x20,%rbx
 1124f66:	vpshufb %ymm2,%ymm0,%ymm0
 1124f6b:	vpermq $0x4e,%ymm0,%ymm0
 1124f71:	mov    -0x70(%rbp),%rcx
 1124f75:	vmovdqu %ymm0,0x20(%rcx,%r11,2)
 1124f7c:	mov    %r11,%rdi
 1124f7f:	mov    %r8,%r14
 1124f82:	sub    %rbx,%r14
 1124f85:	mov    -0x70(%rbp),%rcx
 1124f89:	vmovdqu -0x20(%rcx,%r14,2),%ymm0
 1124f90:	mov    -0x70(%rbp),%rcx
 1124f94:	vmovdqu 0x40(%rcx,%r11,2),%ymm1
 1124f9b:	vpshufb %ymm2,%ymm1,%ymm1
 1124fa0:	vpermq $0x4e,%ymm1,%ymm1
 1124fa6:	mov    -0x70(%rbp),%rcx
 1124faa:	vmovdqu %ymm1,-0x20(%rcx,%r14,2)
 1124fb1:	mov    -0x70(%rbp),%r14
 1124fb5:	or     $0x30,%rdi
 1124fb9:	vpshufb %ymm2,%ymm0,%ymm0
 1124fbe:	vpermq $0x4e,%ymm0,%ymm0
 1124fc4:	vmovdqu %ymm0,0x40(%r14,%r11,2)
 1124fcb:	mov    %r8,%rbx
 1124fce:	sub    %rdi,%rbx
 1124fd1:	vmovdqu -0x20(%r14,%rbx,2),%ymm0
 1124fd8:	vmovdqu 0x60(%r14,%r11,2),%ymm1
 1124fdf:	vpshufb %ymm2,%ymm1,%ymm1
 1124fe4:	vpermq $0x4e,%ymm1,%ymm1
 1124fea:	vmovdqu %ymm1,-0x20(%r14,%rbx,2)
 1124ff1:	lea    0x40(%r11),%rdi
 1124ff5:	vpshufb %ymm2,%ymm0,%ymm0
 1124ffa:	vpermq $0x4e,%ymm0,%ymm0
 1125000:	vmovdqu %ymm0,0x60(%r14,%r11,2)
 1125007:	mov    %rdi,%r11
 112500a:	add    $0xfffffffffffffffc,%r10
 112500e:	jne    1124ef0 <sort.block.block__anon_39113+0x73d0>
 1125014:	and    $0x3,%r9d
 1125018:	mov    -0x40(%rbp),%rbx
 112501c:	je     112507d <sort.block.block__anon_39113+0x755d>
 112501e:	shl    $0x4,%r9d
 1125022:	xor    %r10d,%r10d
 1125025:	mov    %rdi,%r11
 1125028:	nopl   0x0(%rax,%rax,1)
 1125030:	mov    %r8,%rbx
 1125033:	sub    %r11,%rbx
 1125036:	vmovdqu -0x20(%r14,%rbx,2),%ymm0
 112503d:	vmovdqu (%r14,%r11,2),%ymm1
 1125043:	vpshufb %ymm2,%ymm1,%ymm1
 1125048:	vpermq $0x4e,%ymm1,%ymm1
 112504e:	vmovdqu %ymm1,-0x20(%r14,%rbx,2)
 1125055:	vpshufb %ymm2,%ymm0,%ymm0
 112505a:	vpermq $0x4e,%ymm0,%ymm0
 1125060:	vmovdqu %ymm0,(%r14,%r11,2)
 1125066:	add    $0x10,%r11
 112506a:	add    $0xfffffffffffffff0,%r10
 112506e:	mov    %r9,%rbx
 1125071:	add    %r10,%rbx
 1125074:	jne    1125030 <sort.block.block__anon_39113+0x7510>
 1125076:	sub    %r10,%rdi
 1125079:	mov    -0x40(%rbp),%rbx
 112507d:	mov    %rdi,%r9
 1125080:	sub    %rsi,%r9
 1125083:	jae    11251e8 <sort.block.block__anon_39113+0x76c8>
 1125089:	lea    (%r14,%r8,2),%r8
 112508d:	mov    %esi,%r10d
 1125090:	sub    %edi,%r10d
 1125093:	and    $0x3,%r10d
 1125097:	je     1125101 <sort.block.block__anon_39113+0x75e1>
 1125099:	neg    %r10
 112509c:	xor    %r11d,%r11d
 112509f:	mov    %rdi,%rbx
 11250a2:	mov    %r14,%rcx
 11250a5:	data16 cs nopw 0x0(%rax,%rax,1)
 11250b0:	mov    %rbx,%r14
 11250b3:	not    %r14
 11250b6:	movzbl (%rcx,%rbx,2),%r15d
 11250bb:	movzbl (%r8,%r14,2),%r12d
 11250c0:	mov    %r12b,(%rcx,%rbx,2)
 11250c4:	mov    %r15b,(%r8,%r14,2)
 11250c8:	movzbl 0x1(%rcx,%rbx,2),%r15d
 11250ce:	movzbl 0x1(%r8,%r14,2),%r12d
 11250d4:	mov    %r12b,0x1(%rcx,%rbx,2)
 11250d9:	mov    %r15b,0x1(%r8,%r14,2)
 11250de:	inc    %rbx
 11250e1:	dec    %r11
 11250e4:	cmp    %r11,%r10
 11250e7:	jne    11250b0 <sort.block.block__anon_39113+0x7590>
 11250e9:	sub    %r11,%rdi
 11250ec:	mov    -0x88(%rbp),%r15
 11250f3:	mov    -0xe8(%rbp),%r12
 11250fa:	mov    -0x40(%rbp),%rbx
 11250fe:	mov    %rcx,%r14
 1125101:	cmp    $0xfffffffffffffffc,%r9
 1125105:	ja     11251e8 <sort.block.block__anon_39113+0x76c8>
 112510b:	sub    %rdi,%rsi
 112510e:	xchg   %ax,%ax
 1125110:	mov    %rdi,%r9
 1125113:	not    %r9
 1125116:	movzbl (%r14,%rdi,2),%r10d
 112511b:	movzbl (%r8,%r9,2),%r11d
 1125120:	mov    %r11b,(%r14,%rdi,2)
 1125124:	mov    %r10b,(%r8,%r9,2)
 1125128:	movzbl 0x1(%r14,%rdi,2),%r10d
 112512e:	movzbl 0x1(%r8,%r9,2),%r11d
 1125134:	mov    %r11b,0x1(%r14,%rdi,2)
 1125139:	mov    %r10b,0x1(%r8,%r9,2)
 112513e:	mov    $0xfffffffffffffffe,%r9
 1125145:	sub    %rdi,%r9
 1125148:	movzbl 0x2(%r14,%rdi,2),%r10d
 112514e:	movzbl (%r8,%r9,2),%r11d
 1125153:	mov    %r11b,0x2(%r14,%rdi,2)
 1125158:	mov    %r10b,(%r8,%r9,2)
 112515c:	movzbl 0x3(%r14,%rdi,2),%r10d
 1125162:	movzbl 0x1(%r8,%r9,2),%r11d
 1125168:	mov    %r11b,0x3(%r14,%rdi,2)
 112516d:	mov    %r10b,0x1(%r8,%r9,2)
 1125172:	mov    $0xfffffffffffffffd,%r9
 1125179:	sub    %rdi,%r9
 112517c:	movzbl 0x4(%r14,%rdi,2),%r10d
 1125182:	movzbl (%r8,%r9,2),%r11d
 1125187:	mov    %r11b,0x4(%r14,%rdi,2)
 112518c:	mov    %r10b,(%r8,%r9,2)
 1125190:	movzbl 0x5(%r14,%rdi,2),%r10d
 1125196:	movzbl 0x1(%r8,%r9,2),%r11d
 112519c:	mov    %r11b,0x5(%r14,%rdi,2)
 11251a1:	mov    %r10b,0x1(%r8,%r9,2)
 11251a6:	mov    $0xfffffffffffffffc,%r9
 11251ad:	sub    %rdi,%r9
 11251b0:	movzbl 0x6(%r14,%rdi,2),%r10d
 11251b6:	movzbl (%r8,%r9,2),%r11d
 11251bb:	mov    %r11b,0x6(%r14,%rdi,2)
 11251c0:	mov    %r10b,(%r8,%r9,2)
 11251c4:	movzbl 0x7(%r14,%rdi,2),%r10d
 11251ca:	movzbl 0x1(%r8,%r9,2),%r11d
 11251d0:	mov    %r11b,0x7(%r14,%rdi,2)
 11251d5:	mov    %r10b,0x1(%r8,%r9,2)
 11251da:	add    $0x4,%rdi
 11251de:	add    $0xfffffffffffffffc,%rsi
 11251e2:	jne    1125110 <sort.block.block__anon_39113+0x75f0>
 11251e8:	mov    %rdx,%rsi
 11251eb:	shr    %rsi
 11251ee:	cmp    $0x20,%rdx
 11251f2:	setb   %dl
 11251f5:	cmp    $0xf,%rsi
 11251f9:	sete   %dil
 11251fd:	or     %dl,%dil
 1125200:	je     1125210 <sort.block.block__anon_39113+0x76f0>
 1125202:	xor    %edx,%edx
 1125204:	mov    -0x90(%rbp),%r11
 112520b:	jmp    11253a4 <sort.block.block__anon_39113+0x7884>
 1125210:	lea    -0x10(%rsi),%rdx
 1125214:	mov    %rdx,%rdi
 1125217:	shr    $0x4,%rdi
 112521b:	inc    %rdi
 112521e:	cmp    $0x30,%rdx
 1125222:	mov    -0x90(%rbp),%r11
 1125229:	jae    112523b <sort.block.block__anon_39113+0x771b>
 112522b:	xor    %edx,%edx
 112522d:	and    $0x3,%edi
 1125230:	jne    112533e <sort.block.block__anon_39113+0x781e>
 1125236:	jmp    11253a4 <sort.block.block__anon_39113+0x7884>
 112523b:	mov    %rdi,%r8
 112523e:	movabs $0x1ffffffffffffffc,%rdx
 1125248:	and    %rdx,%r8
 112524b:	mov    -0x58(%rbp),%rdx
 112524f:	mov    -0xd8(%rbp),%rcx
 1125256:	lea    (%rdx,%rcx,2),%r9
 112525a:	xor    %edx,%edx
 112525c:	xor    %r10d,%r10d
 112525f:	nop
 1125260:	vmovdqu (%r9,%rdx,2),%ymm0
 1125266:	vmovdqu (%rax,%r10,2),%ymm1
 112526c:	vpshufb %ymm2,%ymm1,%ymm1
 1125271:	vpermq $0x4e,%ymm1,%ymm1
 1125277:	vmovdqu %ymm1,(%r9,%rdx,2)
 112527d:	vpshufb %ymm2,%ymm0,%ymm0
 1125282:	vpermq $0x4e,%ymm0,%ymm0
 1125288:	vmovdqu %ymm0,(%rax,%r10,2)
 112528e:	vmovdqu -0x20(%r9,%rdx,2),%ymm0
 1125295:	vmovdqu 0x20(%rax,%r10,2),%ymm1
 112529c:	vpshufb %ymm2,%ymm1,%ymm1
 11252a1:	vpermq $0x4e,%ymm1,%ymm1
 11252a7:	vmovdqu %ymm1,-0x20(%r9,%rdx,2)
 11252ae:	vpshufb %ymm2,%ymm0,%ymm0
 11252b3:	vpermq $0x4e,%ymm0,%ymm0
 11252b9:	vmovdqu %ymm0,0x20(%rax,%r10,2)
 11252c0:	vmovdqu -0x40(%r9,%rdx,2),%ymm0
 11252c7:	vmovdqu 0x40(%rax,%r10,2),%ymm1
 11252ce:	vpshufb %ymm2,%ymm1,%ymm1
 11252d3:	vpermq $0x4e,%ymm1,%ymm1
 11252d9:	vmovdqu %ymm1,-0x40(%r9,%rdx,2)
 11252e0:	vpshufb %ymm2,%ymm0,%ymm0
 11252e5:	vpermq $0x4e,%ymm0,%ymm0
 11252eb:	vmovdqu %ymm0,0x40(%rax,%r10,2)
 11252f2:	vmovdqu -0x60(%r9,%rdx,2),%ymm0
 11252f9:	vmovdqu 0x60(%rax,%r10,2),%ymm1
 1125300:	vpshufb %ymm2,%ymm1,%ymm1
 1125305:	vpermq $0x4e,%ymm1,%ymm1
 112530b:	vmovdqu %ymm1,-0x60(%r9,%rdx,2)
 1125312:	vpshufb %ymm2,%ymm0,%ymm0
 1125317:	vpermq $0x4e,%ymm0,%ymm0
 112531d:	vmovdqu %ymm0,0x60(%rax,%r10,2)
 1125324:	add    $0x40,%r10
 1125328:	add    $0xffffffffffffffc0,%rdx
 112532c:	add    $0xfffffffffffffffc,%r8
 1125330:	jne    1125260 <sort.block.block__anon_39113+0x7740>
 1125336:	neg    %rdx
 1125339:	and    $0x3,%edi
 112533c:	je     11253a4 <sort.block.block__anon_39113+0x7884>
 112533e:	mov    %r11,%r14
 1125341:	mov    -0x58(%rbp),%r8
 1125345:	mov    -0xd8(%rbp),%rcx
 112534c:	lea    (%r8,%rcx,2),%r8
 1125350:	sub    %rdx,%r8
 1125353:	sub    %rdx,%r8
 1125356:	shl    $0x4,%edi
 1125359:	xor    %r9d,%r9d
 112535c:	mov    %rdx,%r10
 112535f:	nop
 1125360:	vmovdqu (%r8,%r9,2),%ymm0
 1125366:	vmovdqu (%rax,%r10,2),%ymm1
 112536c:	vpshufb %ymm2,%ymm1,%ymm1
 1125371:	vpermq $0x4e,%ymm1,%ymm1
 1125377:	vmovdqu %ymm1,(%r8,%r9,2)
 112537d:	vpshufb %ymm2,%ymm0,%ymm0
 1125382:	vpermq $0x4e,%ymm0,%ymm0
 1125388:	vmovdqu %ymm0,(%rax,%r10,2)
 112538e:	add    $0x10,%r10
 1125392:	add    $0xfffffffffffffff0,%r9
 1125396:	mov    %rdi,%r11
 1125399:	add    %r9,%r11
 112539c:	jne    1125360 <sort.block.block__anon_39113+0x7840>
 112539e:	sub    %r9,%rdx
 11253a1:	mov    %r14,%r11
 11253a4:	mov    %rdx,%rdi
 11253a7:	sub    %rsi,%rdi
 11253aa:	jae    112550d <sort.block.block__anon_39113+0x79ed>
 11253b0:	mov    %esi,%r8d
 11253b3:	sub    %edx,%r8d
 11253b6:	and    $0x3,%r8d
 11253ba:	je     1125424 <sort.block.block__anon_39113+0x7904>
 11253bc:	mov    %r11,%r15
 11253bf:	mov    -0x48(%rbp),%r9
 11253c3:	mov    -0xd8(%rbp),%rcx
 11253ca:	lea    (%r9,%rcx,2),%r9
 11253ce:	sub    %rdx,%r9
 11253d1:	sub    %rdx,%r9
 11253d4:	neg    %r8
 11253d7:	xor    %r10d,%r10d
 11253da:	mov    %rdx,%r11
 11253dd:	nopl   (%rax)
 11253e0:	movzbl (%rax,%r11,2),%ebx
 11253e5:	movzbl -0x1(%r9,%r10,2),%r14d
 11253eb:	mov    %r14b,(%rax,%r11,2)
 11253ef:	mov    %bl,-0x1(%r9,%r10,2)
 11253f4:	movzbl 0x1(%rax,%r11,2),%ebx
 11253fa:	movzbl (%r9,%r10,2),%r14d
 11253ff:	mov    %r14b,0x1(%rax,%r11,2)
 1125404:	mov    %bl,(%r9,%r10,2)
 1125408:	inc    %r11
 112540b:	dec    %r10
 112540e:	cmp    %r10,%r8
 1125411:	jne    11253e0 <sort.block.block__anon_39113+0x78c0>
 1125413:	sub    %r10,%rdx
 1125416:	mov    -0x40(%rbp),%rbx
 112541a:	mov    %r15,%r11
 112541d:	mov    -0x88(%rbp),%r15
 1125424:	cmp    $0xfffffffffffffffc,%rdi
 1125428:	ja     112550d <sort.block.block__anon_39113+0x79ed>
 112542e:	mov    -0x48(%rbp),%rdi
 1125432:	mov    -0xd8(%rbp),%rcx
 1125439:	lea    (%rdi,%rcx,2),%rdi
 112543d:	mov    %rdx,%r8
 1125440:	neg    %r8
 1125443:	neg    %rsi
 1125446:	cs nopw 0x0(%rax,%rax,1)
 1125450:	movzbl (%rax,%rdx,2),%r9d
 1125455:	movzbl -0x1(%rdi,%r8,2),%r10d
 112545b:	mov    %r10b,(%rax,%rdx,2)
 112545f:	mov    %r9b,-0x1(%rdi,%r8,2)
 1125464:	movzbl 0x1(%rax,%rdx,2),%r9d
 112546a:	movzbl (%rdi,%r8,2),%r10d
 112546f:	mov    %r10b,0x1(%rax,%rdx,2)
 1125474:	mov    %r9b,(%rdi,%r8,2)
 1125478:	movzbl 0x2(%rax,%rdx,2),%r9d
 112547e:	movzbl -0x3(%rdi,%r8,2),%r10d
 1125484:	mov    %r10b,0x2(%rax,%rdx,2)
 1125489:	mov    %r9b,-0x3(%rdi,%r8,2)
 112548e:	movzbl 0x3(%rax,%rdx,2),%r9d
 1125494:	movzbl -0x2(%rdi,%r8,2),%r10d
 112549a:	mov    %r10b,0x3(%rax,%rdx,2)
 112549f:	mov    %r9b,-0x2(%rdi,%r8,2)
 11254a4:	movzbl 0x4(%rax,%rdx,2),%r9d
 11254aa:	movzbl -0x5(%rdi,%r8,2),%r10d
 11254b0:	mov    %r10b,0x4(%rax,%rdx,2)
 11254b5:	mov    %r9b,-0x5(%rdi,%r8,2)
 11254ba:	movzbl 0x5(%rax,%rdx,2),%r9d
 11254c0:	movzbl -0x4(%rdi,%r8,2),%r10d
 11254c6:	mov    %r10b,0x5(%rax,%rdx,2)
 11254cb:	mov    %r9b,-0x4(%rdi,%r8,2)
 11254d0:	movzbl 0x6(%rax,%rdx,2),%r9d
 11254d6:	movzbl -0x7(%rdi,%r8,2),%r10d
 11254dc:	mov    %r10b,0x6(%rax,%rdx,2)
 11254e1:	mov    %r9b,-0x7(%rdi,%r8,2)
 11254e6:	movzbl 0x7(%rax,%rdx,2),%r9d
 11254ec:	movzbl -0x6(%rdi,%r8,2),%r10d
 11254f2:	mov    %r10b,0x7(%rax,%rdx,2)
 11254f7:	mov    %r9b,-0x6(%rdi,%r8,2)
 11254fc:	add    $0x4,%rdx
 1125500:	add    $0xfffffffffffffffc,%r8
 1125504:	cmp    %r8,%rsi
 1125507:	jne    1125450 <sort.block.block__anon_39113+0x7930>
 112550d:	mov    -0x60(%rbp),%rax
 1125511:	lea    (%rax,%rbx,1),%rdx
 1125515:	add    %rax,%r12
 1125518:	mov    %rbx,%rcx
 112551b:	mov    -0x108(%rbp),%rax
 1125522:	mov    %rax,-0xd8(%rbp)
 1125529:	mov    %r13,%rbx
 112552c:	mov    %rdx,%rsi
 112552f:	mov    -0x38(%rbp),%r10
 1125533:	jmp    1122db1 <sort.block.block__anon_39113+0x5291>
 1125538:	cmp    $0x3,%rdx
 112553c:	mov    -0x70(%rbp),%r11
 1125540:	jae    1125557 <sort.block.block__anon_39113+0x7a37>
 1125542:	xor    %ecx,%ecx
 1125544:	mov    -0xb0(%rbp),%rdi
 112554b:	mov    -0xf0(%rbp),%r8
 1125552:	jmp    1125621 <sort.block.block__anon_39113+0x7b01>
 1125557:	xor    %ecx,%ecx
 1125559:	mov    -0xb0(%rbp),%rdi
 1125560:	mov    -0xf0(%rbp),%r8
 1125567:	nopw   0x0(%rax,%rax,1)
 1125570:	movzbl (%rax,%rcx,2),%edx
 1125574:	movzbl (%r11,%rcx,2),%esi
 1125579:	mov    %sil,(%rax,%rcx,2)
 112557d:	mov    %dl,(%r11,%rcx,2)
 1125581:	movzbl 0x1(%rax,%rcx,2),%edx
 1125586:	movzbl 0x1(%r11,%rcx,2),%esi
 112558c:	mov    %sil,0x1(%rax,%rcx,2)
 1125591:	mov    %dl,0x1(%r11,%rcx,2)
 1125596:	movzbl 0x2(%rax,%rcx,2),%edx
 112559b:	movzbl 0x2(%r11,%rcx,2),%esi
 11255a1:	mov    %sil,0x2(%rax,%rcx,2)
 11255a6:	mov    %dl,0x2(%r11,%rcx,2)
 11255ab:	movzbl 0x3(%rax,%rcx,2),%edx
 11255b0:	movzbl 0x3(%r11,%rcx,2),%esi
 11255b6:	mov    %sil,0x3(%rax,%rcx,2)
 11255bb:	mov    %dl,0x3(%r11,%rcx,2)
 11255c0:	movzbl 0x4(%rax,%rcx,2),%edx
 11255c5:	movzbl 0x4(%r11,%rcx,2),%esi
 11255cb:	mov    %sil,0x4(%rax,%rcx,2)
 11255d0:	mov    %dl,0x4(%r11,%rcx,2)
 11255d5:	movzbl 0x5(%rax,%rcx,2),%edx
 11255da:	movzbl 0x5(%r11,%rcx,2),%esi
 11255e0:	mov    %sil,0x5(%rax,%rcx,2)
 11255e5:	mov    %dl,0x5(%r11,%rcx,2)
 11255ea:	movzbl 0x6(%rax,%rcx,2),%edx
 11255ef:	movzbl 0x6(%r11,%rcx,2),%esi
 11255f5:	mov    %sil,0x6(%rax,%rcx,2)
 11255fa:	mov    %dl,0x6(%r11,%rcx,2)
 11255ff:	movzbl 0x7(%rax,%rcx,2),%edx
 1125604:	movzbl 0x7(%r11,%rcx,2),%esi
 112560a:	mov    %sil,0x7(%rax,%rcx,2)
 112560f:	mov    %dl,0x7(%r11,%rcx,2)
 1125614:	add    $0x4,%rcx
 1125618:	cmp    %rcx,%r9
 112561b:	jne    1125570 <sort.block.block__anon_39113+0x7a50>
 1125621:	test   %rdi,%rdi
 1125624:	je     112565e <sort.block.block__anon_39113+0x7b3e>
 1125626:	mov    %rdi,%rdx
 1125629:	nopl   0x0(%rax)
 1125630:	movzbl (%rax,%rcx,2),%esi
 1125634:	movzbl (%r11,%rcx,2),%edi
 1125639:	mov    %dil,(%rax,%rcx,2)
 112563d:	mov    %sil,(%r11,%rcx,2)
 1125641:	movzbl 0x1(%rax,%rcx,2),%esi
 1125646:	movzbl 0x1(%r11,%rcx,2),%edi
 112564c:	mov    %dil,0x1(%rax,%rcx,2)
 1125651:	mov    %sil,0x1(%r11,%rcx,2)
 1125656:	inc    %rcx
 1125659:	dec    %rdx
 112565c:	jne    1125630 <sort.block.block__anon_39113+0x7b10>
 112565e:	lea    (%rbx,%r15,1),%rdx
 1125662:	add    %r15,%r12
 1125665:	mov    -0x108(%rbp),%rax
 112566c:	add    %r15,%rax
 112566f:	mov    -0xd8(%rbp),%rcx
 1125676:	lea    (%rcx,%r15,1),%r14
 112567a:	cmp    -0x1f8(%rbp),%rcx
 1125681:	cmova  %r8,%r14
 1125685:	mov    %rdx,%rsi
 1125688:	mov    -0x90(%rbp),%r11
 112568f:	jmp    1122d6f <sort.block.block__anon_39113+0x524f>
 1125694:	mov    %r15,%r12
 1125697:	mov    -0xf0(%rbp),%r14
 112569e:	cmp    $0x201,%r12
 11256a5:	mov    -0xa0(%rbp),%rax
 11256ac:	mov    -0xa8(%rbp),%rcx
 11256b3:	jae    1122b97 <sort.block.block__anon_39113+0x5077>
 11256b9:	cmp    %r11,%r14
 11256bc:	je     1125799 <sort.block.block__anon_39113+0x7c79>
 11256c2:	cmp    %rbx,%r11
 11256c5:	je     1125799 <sort.block.block__anon_39113+0x7c79>
 11256cb:	neg    %r14
 11256ce:	xor    %eax,%eax
 11256d0:	mov    %r14,-0xf0(%rbp)
 11256d7:	mov    %rbx,%rcx
 11256da:	movzwl -0x650(%rbp,%rax,2),%esi
 11256e2:	movzwl %si,%edi
 11256e5:	lea    (%r14,%r11,1),%r8
 11256e9:	mov    %r10,%rdx
 11256ec:	mov    %r11,-0x90(%rbp)
 11256f3:	lea    (%r10,%r11,2),%r10
 11256f7:	lea    (%rdx,%rbx,2),%r9
 11256fb:	shl    $0x4,%edi
 11256fe:	xor    %r13d,%r13d
 1125701:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125710:	movzwl (%r10,%r13,2),%r11d
 1125715:	mov    -0x30(%rbp),%rbx
 1125719:	mov    (%rbx),%rbx
 112571c:	mov    %r11d,%r14d
 112571f:	shl    $0x4,%r14d
 1125723:	mov    (%rbx,%rdi,1),%r15
 1125727:	cmp    %r15,(%rbx,%r14,1)
 112572b:	jne    112573d <sort.block.block__anon_39113+0x7c1d>
 112572d:	add    %rbx,%r14
 1125730:	add    %rdi,%rbx
 1125733:	movzwl 0xe(%r14),%r14d
 1125738:	cmp    0xe(%rbx),%r14w
 112573d:	jae    1125760 <sort.block.block__anon_39113+0x7c40>
 112573f:	mov    %r11w,(%r9,%r13,2)
 1125744:	inc    %r13
 1125747:	mov    %r8,%r11
 112574a:	add    %r13,%r11
 112574d:	jne    1125710 <sort.block.block__anon_39113+0x7bf0>
 112574f:	jmp    11257bc <sort.block.block__anon_39113+0x7c9c>
 1125751:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125760:	mov    %si,(%r9,%r13,2)
 1125765:	inc    %rax
 1125768:	lea    (%rcx,%r13,1),%rbx
 112576c:	inc    %rbx
 112576f:	mov    -0x90(%rbp),%r11
 1125776:	add    %r13,%r11
 1125779:	cmp    %r12,%rax
 112577c:	mov    -0x38(%rbp),%r10
 1125780:	mov    -0xf0(%rbp),%r14
 1125787:	jne    11256d7 <sort.block.block__anon_39113+0x7bb7>
 112578d:	lea    (%rcx,%r13,1),%rbx
 1125791:	inc    %rbx
 1125794:	mov    %r12,%rax
 1125797:	jmp    11257c6 <sort.block.block__anon_39113+0x7ca6>
 1125799:	xor    %eax,%eax
 112579b:	jmp    11257c6 <sort.block.block__anon_39113+0x7ca6>
 112579d:	sub    %r11,%r14
 11257a0:	mov    -0x68(%rbp),%r15
 11257a4:	jne    11257eb <sort.block.block__anon_39113+0x7ccb>
 11257a6:	xor    %eax,%eax
 11257a8:	xor    %ecx,%ecx
 11257aa:	lea    (%rax,%rbx,1),%rdx
 11257ae:	sub    %rdx,%r11
 11257b1:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 11257b7:	jmp    11258d4 <sort.block.block__anon_39113+0x7db4>
 11257bc:	add    %r13,%rcx
 11257bf:	mov    %rcx,%rbx
 11257c2:	mov    -0x38(%rbp),%r10
 11257c6:	lea    -0x650(,%rax,2),%rsi
 11257ce:	add    %rbp,%rsi
 11257d1:	sub    %rax,%r12
 11257d4:	lea    (%r10,%rbx,2),%rdi
 11257d8:	add    %r12,%r12
 11257db:	mov    %r12,%rdx
 11257de:	vzeroupper 
 11257e1:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 11257e6:	jmp    112274c <sort.block.block__anon_39113+0x4c2c>
 11257eb:	mov    %r12,-0x60(%rbp)
 11257ef:	mov    %r14,%r12
 11257f2:	lea    (%r10,%r11,2),%rdx
 11257f6:	mov    -0x50(%rbp),%rax
 11257fa:	mov    %rbx,-0x40(%rbp)
 11257fe:	lea    (%rax,%rbx,2),%rsi
 1125802:	xor    %eax,%eax
 1125804:	xor    %edi,%edi
 1125806:	xor    %r8d,%r8d
 1125809:	mov    %r8,%rcx
 112580c:	nopl   0x0(%rax)
 1125810:	mov    %r11,%r13
 1125813:	movzwl (%rdx,%rdi,2),%r8d
 1125818:	movzwl (%r15,%rax,2),%ebx
 112581d:	mov    -0x30(%rbp),%r9
 1125821:	mov    (%r9),%r10
 1125824:	mov    %r8d,%r9d
 1125827:	shl    $0x4,%r9d
 112582b:	mov    %ebx,%r11d
 112582e:	shl    $0x4,%r11d
 1125832:	mov    (%r10,%r11,1),%r14
 1125836:	cmp    %r14,(%r10,%r9,1)
 112583a:	jne    112584c <sort.block.block__anon_39113+0x7d2c>
 112583c:	add    %r10,%r9
 112583f:	add    %r10,%r11
 1125842:	movzwl 0xe(%r9),%r9d
 1125847:	cmp    0xe(%r11),%r9w
 112584c:	mov    %r13,%r11
 112584f:	jae    1125890 <sort.block.block__anon_39113+0x7d70>
 1125851:	mov    %r8d,%r9d
 1125854:	shr    $0x8,%r9d
 1125858:	movzbl -0x1(%rsi,%rcx,2),%r10d
 112585e:	mov    %r8b,-0x1(%rsi,%rcx,2)
 1125863:	mov    %r10b,(%rdx,%rdi,2)
 1125867:	movzbl (%rsi,%rcx,2),%r8d
 112586c:	mov    %r9b,(%rsi,%rcx,2)
 1125870:	mov    %r8b,0x1(%rdx,%rdi,2)
 1125875:	inc    %rdi
 1125878:	inc    %rcx
 112587b:	cmp    %r12,%rdi
 112587e:	jb     1125810 <sort.block.block__anon_39113+0x7cf0>
 1125880:	jmp    11258bf <sort.block.block__anon_39113+0x7d9f>
 1125882:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125890:	movzbl -0x1(%rsi,%rcx,2),%r8d
 1125896:	mov    %bl,-0x1(%rsi,%rcx,2)
 112589a:	mov    %r8b,(%r15,%rax,2)
 112589e:	movzbl (%rsi,%rcx,2),%r8d
 11258a3:	mov    %bh,(%rsi,%rcx,2)
 11258a6:	mov    %r8b,0x1(%r15,%rax,2)
 11258ab:	inc    %rax
 11258ae:	lea    0x1(%rcx),%r8
 11258b2:	cmp    -0x60(%rbp),%rax
 11258b6:	jb     1125809 <sort.block.block__anon_39113+0x7ce9>
 11258bc:	inc    %rcx
 11258bf:	mov    -0x38(%rbp),%r10
 11258c3:	mov    -0x40(%rbp),%rbx
 11258c7:	lea    (%rax,%rbx,1),%rdx
 11258cb:	sub    %rdx,%r11
 11258ce:	je     1122758 <sort.block.block__anon_39113+0x4c38>
 11258d4:	add    %rbx,%rbx
 11258d7:	lea    (%rbx,%rcx,2),%rcx
 11258db:	add    -0x50(%rbp),%rcx
 11258df:	mov    -0x1a8(%rbp),%rdx
 11258e6:	lea    (%rdx,%rax,2),%rax
 11258ea:	xor    %edx,%edx
 11258ec:	nopl   0x0(%rax)
 11258f0:	movzbl -0x1(%rax,%rdx,2),%esi
 11258f5:	movzbl -0x1(%rcx,%rdx,2),%edi
 11258fa:	mov    %dil,-0x1(%rax,%rdx,2)
 11258ff:	mov    %sil,-0x1(%rcx,%rdx,2)
 1125904:	movzbl (%rax,%rdx,2),%esi
 1125908:	movzbl (%rcx,%rdx,2),%edi
 112590c:	mov    %dil,(%rax,%rdx,2)
 1125910:	mov    %sil,(%rcx,%rdx,2)
 1125914:	inc    %rdx
 1125917:	cmp    %rdx,%r11
 112591a:	jne    11258f0 <sort.block.block__anon_39113+0x7dd0>
 112591c:	jmp    1122758 <sort.block.block__anon_39113+0x4c38>
 1125921:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125930:	mov    -0x1e8(%rbp),%r14
 1125937:	cmp    $0x2,%r14
 112593b:	mov    -0x98(%rbp),%r13
 1125942:	mov    -0x68(%rbp),%rbx
 1125946:	jb     11259d0 <sort.block.block__anon_39113+0x7eb0>
 112594c:	mov    -0x30(%rbp),%rax
 1125950:	mov    (%rax),%rax
 1125953:	mov    $0x1,%ecx
 1125958:	jmp    1125968 <sort.block.block__anon_39113+0x7e48>
 112595a:	nopw   0x0(%rax,%rax,1)
 1125960:	inc    %rcx
 1125963:	cmp    %r14,%rcx
 1125966:	je     11259d0 <sort.block.block__anon_39113+0x7eb0>
 1125968:	mov    %rcx,%rdx
 112596b:	nopl   0x0(%rax,%rax,1)
 1125970:	movzwl (%rbx,%rdx,2),%esi
 1125974:	movzwl -0x2(%rbx,%rdx,2),%edi
 1125979:	mov    %esi,%r8d
 112597c:	shl    $0x4,%r8d
 1125980:	mov    (%rax,%r8,1),%r10
 1125984:	mov    %edi,%r9d
 1125987:	shl    $0x4,%r9d
 112598b:	mov    (%rax,%r9,1),%r11
 112598f:	cmp    %r11,%r10
 1125992:	jne    11259a4 <sort.block.block__anon_39113+0x7e84>
 1125994:	add    %rax,%r8
 1125997:	add    %rax,%r9
 112599a:	movzwl 0xe(%r8),%r8d
 112599f:	cmp    0xe(%r9),%r8w
 11259a4:	jae    1125960 <sort.block.block__anon_39113+0x7e40>
 11259a6:	mov    %esi,%r8d
 11259a9:	shr    $0x8,%r8d
 11259ad:	mov    %edi,%r9d
 11259b0:	shr    $0x8,%r9d
 11259b4:	mov    %dil,(%rbx,%rdx,2)
 11259b8:	dec    %rdx
 11259bb:	mov    %sil,(%rbx,%rdx,2)
 11259bf:	mov    %r9b,0x3(%rbx,%rdx,2)
 11259c4:	mov    %r8b,0x1(%rbx,%rdx,2)
 11259c9:	test   %rdx,%rdx
 11259cc:	jne    1125970 <sort.block.block__anon_39113+0x7e50>
 11259ce:	jmp    1125960 <sort.block.block__anon_39113+0x7e40>
 11259d0:	mov    $0x1,%cl
 11259d2:	lea    -0x1a0(%rbp),%rax
 11259d9:	jmp    11259f6 <sort.block.block__anon_39113+0x7ed6>
 11259db:	nopl   0x0(%rax,%rax,1)
 11259e0:	lea    -0x178(%rbp),%rax
 11259e7:	testb  $0x1,-0x60(%rbp)
 11259eb:	mov    $0x0,%ecx
 11259f0:	je     111f8f0 <sort.block.block__anon_39113+0x1dd0>
 11259f6:	mov    %ecx,-0x60(%rbp)
 11259f9:	mov    0x10(%rax),%r10
 11259fd:	lea    (%r10,%r10,1),%rsi
 1125a01:	mov    0x8(%rax),%rcx
 1125a05:	cmp    %rcx,(%rax)
 1125a08:	jbe    1126540 <sort.block.block__anon_39113+0x8a20>
 1125a0e:	test   %r10,%r10
 1125a11:	je     11259e0 <sort.block.block__anon_39113+0x7ec0>
 1125a13:	mov    0x18(%rax),%rdi
 1125a17:	mov    0x20(%rax),%rax
 1125a1b:	mov    %rax,-0x68(%rbp)
 1125a1f:	lea    (%rdi,%r10,1),%rdx
 1125a23:	jmp    1125a4d <sort.block.block__anon_39113+0x7f2d>
 1125a25:	data16 cs nopw 0x0(%rax,%rax,1)
 1125a30:	inc    %rdi
 1125a33:	mov    -0x40(%rbp),%rsi
 1125a37:	add    $0xfffffffffffffffe,%rsi
 1125a3b:	mov    %rdi,%r10
 1125a3e:	sub    %r9,%r10
 1125a41:	neg    %r10
 1125a44:	sub    %r9,%rdi
 1125a47:	lea    (%rdi,%rdx,1),%rdi
 1125a4b:	je     11259e0 <sort.block.block__anon_39113+0x7ec0>
 1125a4d:	mov    %rsi,-0x40(%rbp)
 1125a51:	mov    %rdx,%r9
 1125a54:	mov    -0x68(%rbp),%rax
 1125a58:	sub    %rdx,%rax
 1125a5b:	je     1125bd0 <sort.block.block__anon_39113+0x80b0>
 1125a61:	mov    -0x38(%rbp),%rcx
 1125a65:	movzwl (%rcx,%rdi,2),%ecx
 1125a69:	mov    %rax,%rdx
 1125a6c:	mov    -0x40(%rbp),%rsi
 1125a70:	or     %rsi,%rdx
 1125a73:	shr    $0x20,%rdx
 1125a77:	je     1125a80 <sort.block.block__anon_39113+0x7f60>
 1125a79:	xor    %edx,%edx
 1125a7b:	div    %rsi
 1125a7e:	jmp    1125a84 <sort.block.block__anon_39113+0x7f64>
 1125a80:	xor    %edx,%edx
 1125a82:	div    %esi
 1125a84:	cmp    $0x1,%rax
 1125a88:	adc    $0x0,%rax
 1125a8c:	mov    -0x30(%rbp),%rdx
 1125a90:	mov    (%rdx),%r11
 1125a93:	shl    $0x4,%ecx
 1125a96:	lea    (%r11,%rcx,1),%r14
 1125a9a:	mov    (%r11,%rcx,1),%r15
 1125a9e:	mov    -0x68(%rbp),%rbx
 1125aa2:	sub    %rax,%rbx
 1125aa5:	mov    %r9,%rdx
 1125aa8:	jmp    1125abe <sort.block.block__anon_39113+0x7f9e>
 1125aaa:	nopw   0x0(%rax,%rax,1)
 1125ab0:	jae    1125b02 <sort.block.block__anon_39113+0x7fe2>
 1125ab2:	mov    %rcx,%rdx
 1125ab5:	cmp    %rbx,%rcx
 1125ab8:	jae    1125b50 <sort.block.block__anon_39113+0x8030>
 1125abe:	lea    (%rdx,%rax,1),%rcx
 1125ac2:	movzwl 0x0(%r13,%rcx,2),%r12d
 1125ac8:	shl    $0x4,%r12d
 1125acc:	cmp    %r15,(%r11,%r12,1)
 1125ad0:	jne    1125ab0 <sort.block.block__anon_39113+0x7f90>
 1125ad2:	add    %r11,%r12
 1125ad5:	movzwl 0xe(%r12),%r12d
 1125adb:	cmp    0xe(%r14),%r12w
 1125ae0:	jb     1125ab2 <sort.block.block__anon_39113+0x7f92>
 1125ae2:	jmp    1125b02 <sort.block.block__anon_39113+0x7fe2>
 1125ae4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125af0:	xor    %ebx,%ebx
 1125af2:	add    %rbx,%rdx
 1125af5:	cmp    $0x2,%rax
 1125af9:	mov    %rcx,%rax
 1125afc:	jb     1125bd0 <sort.block.block__anon_39113+0x80b0>
 1125b02:	mov    -0x38(%rbp),%rcx
 1125b06:	lea    (%rcx,%rdx,2),%rcx
 1125b0a:	mov    %rax,%rbx
 1125b0d:	and    $0xfffffffffffffffe,%rbx
 1125b11:	movzwl (%rbx,%rcx,1),%ecx
 1125b15:	shl    $0x4,%ecx
 1125b18:	cmp    %r15,(%r11,%rcx,1)
 1125b1c:	jne    1125b2a <sort.block.block__anon_39113+0x800a>
 1125b1e:	add    %r11,%rcx
 1125b21:	movzwl 0xe(%rcx),%ecx
 1125b25:	cmp    0xe(%r14),%cx
 1125b2a:	setb   %bl
 1125b2d:	mov    %rax,%rcx
 1125b30:	shr    %rcx
 1125b33:	test   %bl,%bl
 1125b35:	je     1125af0 <sort.block.block__anon_39113+0x7fd0>
 1125b37:	mov    %eax,%ebx
 1125b39:	and    $0x1,%ebx
 1125b3c:	add    %rcx,%rbx
 1125b3f:	add    %rbx,%rdx
 1125b42:	cmp    $0x2,%rax
 1125b46:	mov    %rcx,%rax
 1125b49:	jae    1125b02 <sort.block.block__anon_39113+0x7fe2>
 1125b4b:	jmp    1125bd0 <sort.block.block__anon_39113+0x80b0>
 1125b50:	mov    -0x68(%rbp),%rdx
 1125b54:	mov    %rdx,%rax
 1125b57:	sub    %rcx,%rax
 1125b5a:	jbe    1125bd0 <sort.block.block__anon_39113+0x80b0>
 1125b5c:	mov    %rcx,%rdx
 1125b5f:	jmp    1125b7e <sort.block.block__anon_39113+0x805e>
 1125b61:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125b70:	xor    %ebx,%ebx
 1125b72:	add    %rbx,%rdx
 1125b75:	cmp    $0x1,%rax
 1125b79:	mov    %rcx,%rax
 1125b7c:	jbe    1125bd0 <sort.block.block__anon_39113+0x80b0>
 1125b7e:	mov    -0x38(%rbp),%rcx
 1125b82:	lea    (%rcx,%rdx,2),%rcx
 1125b86:	mov    %rax,%rbx
 1125b89:	and    $0xfffffffffffffffe,%rbx
 1125b8d:	movzwl (%rbx,%rcx,1),%ecx
 1125b91:	shl    $0x4,%ecx
 1125b94:	cmp    %r15,(%r11,%rcx,1)
 1125b98:	jne    1125ba6 <sort.block.block__anon_39113+0x8086>
 1125b9a:	add    %r11,%rcx
 1125b9d:	movzwl 0xe(%rcx),%ecx
 1125ba1:	cmp    0xe(%r14),%cx
 1125ba6:	setb   %bl
 1125ba9:	mov    %rax,%rcx
 1125bac:	shr    %rcx
 1125baf:	test   %bl,%bl
 1125bb1:	je     1125b70 <sort.block.block__anon_39113+0x8050>
 1125bb3:	mov    %eax,%ebx
 1125bb5:	and    $0x1,%ebx
 1125bb8:	add    %rcx,%rbx
 1125bbb:	add    %rbx,%rdx
 1125bbe:	cmp    $0x1,%rax
 1125bc2:	mov    %rcx,%rax
 1125bc5:	ja     1125b7e <sort.block.block__anon_39113+0x805e>
 1125bc7:	nopw   0x0(%rax,%rax,1)
 1125bd0:	mov    %r10,%rax
 1125bd3:	shr    %rax
 1125bd6:	cmp    $0x20,%r10
 1125bda:	setb   %cl
 1125bdd:	cmp    $0xf,%rax
 1125be1:	sete   %r11b
 1125be5:	or     %cl,%r11b
 1125be8:	je     1125c00 <sort.block.block__anon_39113+0x80e0>
 1125bea:	xor    %r11d,%r11d
 1125bed:	jmp    1125d9f <sort.block.block__anon_39113+0x827f>
 1125bf2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125c00:	lea    -0x10(%rax),%rcx
 1125c04:	mov    %rcx,%r14
 1125c07:	shr    $0x4,%r14
 1125c0b:	inc    %r14
 1125c0e:	cmp    $0x30,%rcx
 1125c12:	jae    1125c30 <sort.block.block__anon_39113+0x8110>
 1125c14:	xor    %r11d,%r11d
 1125c17:	and    $0x3,%r14d
 1125c1b:	jne    1125d2f <sort.block.block__anon_39113+0x820f>
 1125c21:	jmp    1125d9f <sort.block.block__anon_39113+0x827f>
 1125c26:	cs nopw 0x0(%rax,%rax,1)
 1125c30:	mov    %r14,%rcx
 1125c33:	movabs $0x1ffffffffffffffc,%rsi
 1125c3d:	and    %rsi,%rcx
 1125c40:	lea    (%rdi,%rdi,1),%r8
 1125c44:	mov    -0xc8(%rbp),%rsi
 1125c4b:	lea    (%rsi,%rdi,2),%rbx
 1125c4f:	lea    (%r8,%r10,2),%r15
 1125c53:	add    -0x58(%rbp),%r15
 1125c57:	xor    %r11d,%r11d
 1125c5a:	nopw   0x0(%rax,%rax,1)
 1125c60:	vmovdqu (%r15,%r11,2),%ymm0
 1125c66:	vmovdqu -0x60(%rbx),%ymm1
 1125c6b:	vpshufb %ymm2,%ymm1,%ymm1
 1125c70:	vpermq $0x4e,%ymm1,%ymm1
 1125c76:	vmovdqu %ymm1,(%r15,%r11,2)
 1125c7c:	vpshufb %ymm2,%ymm0,%ymm0
 1125c81:	vpermq $0x4e,%ymm0,%ymm0
 1125c87:	vmovdqu %ymm0,-0x60(%rbx)
 1125c8c:	vmovdqu -0x20(%r15,%r11,2),%ymm0
 1125c93:	vmovdqu -0x40(%rbx),%ymm1
 1125c98:	vpshufb %ymm2,%ymm1,%ymm1
 1125c9d:	vpermq $0x4e,%ymm1,%ymm1
 1125ca3:	vmovdqu %ymm1,-0x20(%r15,%r11,2)
 1125caa:	vpshufb %ymm2,%ymm0,%ymm0
 1125caf:	vpermq $0x4e,%ymm0,%ymm0
 1125cb5:	vmovdqu %ymm0,-0x40(%rbx)
 1125cba:	vmovdqu -0x40(%r15,%r11,2),%ymm0
 1125cc1:	vmovdqu -0x20(%rbx),%ymm1
 1125cc6:	vpshufb %ymm2,%ymm1,%ymm1
 1125ccb:	vpermq $0x4e,%ymm1,%ymm1
 1125cd1:	vmovdqu %ymm1,-0x40(%r15,%r11,2)
 1125cd8:	vpshufb %ymm2,%ymm0,%ymm0
 1125cdd:	vpermq $0x4e,%ymm0,%ymm0
 1125ce3:	vmovdqu %ymm0,-0x20(%rbx)
 1125ce8:	vmovdqu -0x60(%r15,%r11,2),%ymm0
 1125cef:	vmovdqu (%rbx),%ymm1
 1125cf3:	vpshufb %ymm2,%ymm1,%ymm1
 1125cf8:	vpermq $0x4e,%ymm1,%ymm1
 1125cfe:	vmovdqu %ymm1,-0x60(%r15,%r11,2)
 1125d05:	vpshufb %ymm2,%ymm0,%ymm0
 1125d0a:	vpermq $0x4e,%ymm0,%ymm0
 1125d10:	vmovdqu %ymm0,(%rbx)
 1125d14:	sub    $0xffffffffffffff80,%rbx
 1125d18:	add    $0xffffffffffffffc0,%r11
 1125d1c:	add    $0xfffffffffffffffc,%rcx
 1125d20:	jne    1125c60 <sort.block.block__anon_39113+0x8140>
 1125d26:	neg    %r11
 1125d29:	and    $0x3,%r14d
 1125d2d:	je     1125d9f <sort.block.block__anon_39113+0x827f>
 1125d2f:	lea    (%r10,%r10,1),%rcx
 1125d33:	lea    (%rcx,%rdi,2),%rbx
 1125d37:	add    -0x58(%rbp),%rbx
 1125d3b:	mov    %r11,%rcx
 1125d3e:	neg    %rcx
 1125d41:	add    %r11,%r11
 1125d44:	lea    (%r11,%rdi,2),%r11
 1125d48:	add    -0x38(%rbp),%r11
 1125d4c:	shl    $0x5,%r14d
 1125d50:	xor    %r15d,%r15d
 1125d53:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125d60:	vmovdqu (%rbx,%rcx,2),%ymm0
 1125d65:	vmovdqu (%r11,%r15,1),%ymm1
 1125d6b:	vpshufb %ymm2,%ymm1,%ymm1
 1125d70:	vpermq $0x4e,%ymm1,%ymm1
 1125d76:	vmovdqu %ymm1,(%rbx,%rcx,2)
 1125d7b:	vpshufb %ymm2,%ymm0,%ymm0
 1125d80:	vpermq $0x4e,%ymm0,%ymm0
 1125d86:	vmovdqu %ymm0,(%r11,%r15,1)
 1125d8c:	add    $0xfffffffffffffff0,%rcx
 1125d90:	add    $0x20,%r15
 1125d94:	cmp    %r15,%r14
 1125d97:	jne    1125d60 <sort.block.block__anon_39113+0x8240>
 1125d99:	neg    %rcx
 1125d9c:	mov    %rcx,%r11
 1125d9f:	mov    %r11,%rcx
 1125da2:	sub    %rax,%rcx
 1125da5:	jae    1125eed <sort.block.block__anon_39113+0x83cd>
 1125dab:	mov    %eax,%ebx
 1125dad:	sub    %r11d,%ebx
 1125db0:	and    $0x3,%ebx
 1125db3:	je     1125e1a <sort.block.block__anon_39113+0x82fa>
 1125db5:	mov    -0x48(%rbp),%rsi
 1125db9:	lea    (%rsi,%r9,2),%r14
 1125dbd:	sub    %r11,%r14
 1125dc0:	sub    %r11,%r14
 1125dc3:	lea    (%rdi,%rdi,1),%r15
 1125dc7:	lea    (%r15,%r11,2),%r15
 1125dcb:	add    -0x50(%rbp),%r15
 1125dcf:	neg    %rbx
 1125dd2:	xor    %r12d,%r12d
 1125dd5:	data16 cs nopw 0x0(%rax,%rax,1)
 1125de0:	movzbl -0x1(%r15),%r13d
 1125de5:	movzbl -0x1(%r14,%r12,2),%r8d
 1125deb:	mov    %r8b,-0x1(%r15)
 1125def:	mov    %r13b,-0x1(%r14,%r12,2)
 1125df4:	movzbl (%r15),%r8d
 1125df8:	movzbl (%r14,%r12,2),%r13d
 1125dfd:	mov    %r13b,(%r15)
 1125e00:	mov    %r8b,(%r14,%r12,2)
 1125e04:	dec    %r12
 1125e07:	add    $0x2,%r15
 1125e0b:	cmp    %r12,%rbx
 1125e0e:	jne    1125de0 <sort.block.block__anon_39113+0x82c0>
 1125e10:	sub    %r12,%r11
 1125e13:	mov    -0x98(%rbp),%r13
 1125e1a:	cmp    $0xfffffffffffffffc,%rcx
 1125e1e:	ja     1125eed <sort.block.block__anon_39113+0x83cd>
 1125e24:	mov    -0x80(%rbp),%rcx
 1125e28:	lea    (%rcx,%rdi,2),%rcx
 1125e2c:	mov    -0x48(%rbp),%rsi
 1125e30:	lea    (%rsi,%r9,2),%rbx
 1125e34:	sub    %r11,%rbx
 1125e37:	sub    %r11,%rbx
 1125e3a:	nopw   0x0(%rax,%rax,1)
 1125e40:	movzbl -0x7(%rcx,%r11,2),%r8d
 1125e46:	movzbl -0x1(%rbx),%r14d
 1125e4b:	mov    %r14b,-0x7(%rcx,%r11,2)
 1125e50:	mov    %r8b,-0x1(%rbx)
 1125e54:	movzbl -0x6(%rcx,%r11,2),%r8d
 1125e5a:	movzbl (%rbx),%r14d
 1125e5e:	mov    %r14b,-0x6(%rcx,%r11,2)
 1125e63:	mov    %r8b,(%rbx)
 1125e66:	movzbl -0x5(%rcx,%r11,2),%r8d
 1125e6c:	movzbl -0x3(%rbx),%r14d
 1125e71:	mov    %r14b,-0x5(%rcx,%r11,2)
 1125e76:	mov    %r8b,-0x3(%rbx)
 1125e7a:	movzbl -0x4(%rcx,%r11,2),%r8d
 1125e80:	movzbl -0x2(%rbx),%r14d
 1125e85:	mov    %r14b,-0x4(%rcx,%r11,2)
 1125e8a:	mov    %r8b,-0x2(%rbx)
 1125e8e:	movzbl -0x3(%rcx,%r11,2),%r8d
 1125e94:	movzbl -0x5(%rbx),%r14d
 1125e99:	mov    %r14b,-0x3(%rcx,%r11,2)
 1125e9e:	mov    %r8b,-0x5(%rbx)
 1125ea2:	movzbl -0x2(%rcx,%r11,2),%r8d
 1125ea8:	movzbl -0x4(%rbx),%r14d
 1125ead:	mov    %r14b,-0x2(%rcx,%r11,2)
 1125eb2:	mov    %r8b,-0x4(%rbx)
 1125eb6:	movzbl -0x1(%rcx,%r11,2),%r8d
 1125ebc:	movzbl -0x7(%rbx),%r14d
 1125ec1:	mov    %r14b,-0x1(%rcx,%r11,2)
 1125ec6:	mov    %r8b,-0x7(%rbx)
 1125eca:	movzbl (%rcx,%r11,2),%r8d
 1125ecf:	movzbl -0x6(%rbx),%r14d
 1125ed4:	mov    %r14b,(%rcx,%r11,2)
 1125ed8:	mov    %r8b,-0x6(%rbx)
 1125edc:	add    $0x4,%r11
 1125ee0:	add    $0xfffffffffffffff8,%rbx
 1125ee4:	cmp    %r11,%rax
 1125ee7:	jne    1125e40 <sort.block.block__anon_39113+0x8320>
 1125eed:	mov    %rdx,%rax
 1125ef0:	sub    %rdi,%rax
 1125ef3:	mov    %rax,%r15
 1125ef6:	sub    %r10,%r15
 1125ef9:	mov    %r15,%r11
 1125efc:	shr    %r11
 1125eff:	cmp    $0x20,%r15
 1125f03:	setb   %cl
 1125f06:	cmp    $0xf,%r11
 1125f0a:	sete   %r8b
 1125f0e:	or     %cl,%r8b
 1125f11:	je     1125f20 <sort.block.block__anon_39113+0x8400>
 1125f13:	xor    %r14d,%r14d
 1125f16:	jmp    11260e4 <sort.block.block__anon_39113+0x85c4>
 1125f1b:	nopl   0x0(%rax,%rax,1)
 1125f20:	lea    -0x10(%r11),%rcx
 1125f24:	mov    %rcx,%r12
 1125f27:	shr    $0x4,%r12
 1125f2b:	inc    %r12
 1125f2e:	cmp    $0x30,%rcx
 1125f32:	jae    1125f50 <sort.block.block__anon_39113+0x8430>
 1125f34:	xor    %r14d,%r14d
 1125f37:	and    $0x3,%r12d
 1125f3b:	jne    1126072 <sort.block.block__anon_39113+0x8552>
 1125f41:	jmp    11260e4 <sort.block.block__anon_39113+0x85c4>
 1125f46:	cs nopw 0x0(%rax,%rax,1)
 1125f50:	mov    %r12,%rbx
 1125f53:	movabs $0x1ffffffffffffffc,%rcx
 1125f5d:	and    %rcx,%rbx
 1125f60:	lea    (%r9,%r9,1),%rcx
 1125f64:	mov    -0xc8(%rbp),%rsi
 1125f6b:	lea    (%rsi,%r9,2),%r13
 1125f6f:	lea    (%rcx,%rdx,2),%rcx
 1125f73:	sub    %rdi,%rcx
 1125f76:	sub    %rdi,%rcx
 1125f79:	sub    %r10,%rcx
 1125f7c:	sub    %r10,%rcx
 1125f7f:	add    -0x38(%rbp),%rcx
 1125f83:	xor    %r14d,%r14d
 1125f86:	cs nopw 0x0(%rax,%rax,1)
 1125f90:	vmovdqu -0x20(%rcx,%r14,2),%ymm0
 1125f97:	vmovdqu -0x60(%r13),%ymm1
 1125f9d:	vpshufb %ymm2,%ymm1,%ymm1
 1125fa2:	vpermq $0x4e,%ymm1,%ymm1
 1125fa8:	vmovdqu %ymm1,-0x20(%rcx,%r14,2)
 1125faf:	vpshufb %ymm2,%ymm0,%ymm0
 1125fb4:	vpermq $0x4e,%ymm0,%ymm0
 1125fba:	vmovdqu %ymm0,-0x60(%r13)
 1125fc0:	vmovdqu -0x40(%rcx,%r14,2),%ymm0
 1125fc7:	vmovdqu -0x40(%r13),%ymm1
 1125fcd:	vpshufb %ymm2,%ymm1,%ymm1
 1125fd2:	vpermq $0x4e,%ymm1,%ymm1
 1125fd8:	vmovdqu %ymm1,-0x40(%rcx,%r14,2)
 1125fdf:	vpshufb %ymm2,%ymm0,%ymm0
 1125fe4:	vpermq $0x4e,%ymm0,%ymm0
 1125fea:	vmovdqu %ymm0,-0x40(%r13)
 1125ff0:	vmovdqu -0x60(%rcx,%r14,2),%ymm0
 1125ff7:	vmovdqu -0x20(%r13),%ymm1
 1125ffd:	vpshufb %ymm2,%ymm1,%ymm1
 1126002:	vpermq $0x4e,%ymm1,%ymm1
 1126008:	vmovdqu %ymm1,-0x60(%rcx,%r14,2)
 112600f:	vpshufb %ymm2,%ymm0,%ymm0
 1126014:	vpermq $0x4e,%ymm0,%ymm0
 112601a:	vmovdqu %ymm0,-0x20(%r13)
 1126020:	vmovdqu -0x80(%rcx,%r14,2),%ymm0
 1126027:	vmovdqu 0x0(%r13),%ymm1
 112602d:	vpshufb %ymm2,%ymm1,%ymm1
 1126032:	vpermq $0x4e,%ymm1,%ymm1
 1126038:	vmovdqu %ymm1,-0x80(%rcx,%r14,2)
 112603f:	vpshufb %ymm2,%ymm0,%ymm0
 1126044:	vpermq $0x4e,%ymm0,%ymm0
 112604a:	vmovdqu %ymm0,0x0(%r13)
 1126050:	sub    $0xffffffffffffff80,%r13
 1126054:	add    $0xffffffffffffffc0,%r14
 1126058:	add    $0xfffffffffffffffc,%rbx
 112605c:	jne    1125f90 <sort.block.block__anon_39113+0x8470>
 1126062:	neg    %r14
 1126065:	mov    -0x98(%rbp),%r13
 112606c:	and    $0x3,%r12d
 1126070:	je     11260e4 <sort.block.block__anon_39113+0x85c4>
 1126072:	lea    (%r9,%r9,1),%rcx
 1126076:	lea    (%rcx,%rdx,2),%rcx
 112607a:	sub    %rdi,%rcx
 112607d:	sub    %rdi,%rcx
 1126080:	lea    (%r14,%r14,1),%r8
 1126084:	sub    %r8,%rcx
 1126087:	sub    %r10,%rcx
 112608a:	sub    %r10,%rcx
 112608d:	add    -0x58(%rbp),%rcx
 1126091:	lea    (%r8,%r9,2),%rbx
 1126095:	add    -0x38(%rbp),%rbx
 1126099:	shl    $0x4,%r12d
 112609d:	xor    %r13d,%r13d
 11260a0:	vmovdqu (%rcx,%r13,2),%ymm0
 11260a6:	vmovdqu (%rbx),%ymm1
 11260aa:	vpshufb %ymm2,%ymm1,%ymm1
 11260af:	vpermq $0x4e,%ymm1,%ymm1
 11260b5:	vmovdqu %ymm1,(%rcx,%r13,2)
 11260bb:	vpshufb %ymm2,%ymm0,%ymm0
 11260c0:	vpermq $0x4e,%ymm0,%ymm0
 11260c6:	vmovdqu %ymm0,(%rbx)
 11260ca:	add    $0xfffffffffffffff0,%r13
 11260ce:	add    $0x20,%rbx
 11260d2:	mov    %r12,%r8
 11260d5:	add    %r13,%r8
 11260d8:	jne    11260a0 <sort.block.block__anon_39113+0x8580>
 11260da:	sub    %r13,%r14
 11260dd:	mov    -0x98(%rbp),%r13
 11260e4:	mov    %r14,%rbx
 11260e7:	sub    %r11,%rbx
 11260ea:	jae    112623d <sort.block.block__anon_39113+0x871d>
 11260f0:	mov    %r11d,%ecx
 11260f3:	sub    %r14d,%ecx
 11260f6:	and    $0x3,%ecx
 11260f9:	je     112616a <sort.block.block__anon_39113+0x864a>
 11260fb:	lea    (%r9,%r9,1),%r8
 11260ff:	lea    (%r8,%rdx,2),%r12
 1126103:	sub    %r14,%r12
 1126106:	sub    %r14,%r12
 1126109:	sub    %rdi,%r12
 112610c:	sub    %rdi,%r12
 112610f:	add    %r10,%r10
 1126112:	sub    %r10,%r12
 1126115:	add    -0x48(%rbp),%r12
 1126119:	lea    (%r8,%r14,2),%r10
 112611d:	add    -0x50(%rbp),%r10
 1126121:	neg    %rcx
 1126124:	xor    %r13d,%r13d
 1126127:	nopw   0x0(%rax,%rax,1)
 1126130:	movzbl -0x1(%r10),%r8d
 1126135:	movzbl -0x1(%r12,%r13,2),%esi
 112613b:	mov    %sil,-0x1(%r10)
 112613f:	mov    %r8b,-0x1(%r12,%r13,2)
 1126144:	movzbl (%r10),%esi
 1126148:	movzbl (%r12,%r13,2),%r8d
 112614d:	mov    %r8b,(%r10)
 1126150:	mov    %sil,(%r12,%r13,2)
 1126154:	dec    %r13
 1126157:	add    $0x2,%r10
 112615b:	cmp    %r13,%rcx
 112615e:	jne    1126130 <sort.block.block__anon_39113+0x8610>
 1126160:	sub    %r13,%r14
 1126163:	mov    -0x98(%rbp),%r13
 112616a:	cmp    $0xfffffffffffffffc,%rbx
 112616e:	ja     112623d <sort.block.block__anon_39113+0x871d>
 1126174:	mov    -0x80(%rbp),%rcx
 1126178:	lea    (%rcx,%r9,2),%rcx
 112617c:	add    %r15,%r15
 112617f:	lea    (%r15,%r9,2),%r10
 1126183:	sub    %r14,%r10
 1126186:	sub    %r14,%r10
 1126189:	add    -0x48(%rbp),%r10
 112618d:	nopl   (%rax)
 1126190:	movzbl -0x7(%rcx,%r14,2),%esi
 1126196:	movzbl -0x1(%r10),%r8d
 112619b:	mov    %r8b,-0x7(%rcx,%r14,2)
 11261a0:	mov    %sil,-0x1(%r10)
 11261a4:	movzbl -0x6(%rcx,%r14,2),%esi
 11261aa:	movzbl (%r10),%r8d
 11261ae:	mov    %r8b,-0x6(%rcx,%r14,2)
 11261b3:	mov    %sil,(%r10)
 11261b6:	movzbl -0x5(%rcx,%r14,2),%esi
 11261bc:	movzbl -0x3(%r10),%r8d
 11261c1:	mov    %r8b,-0x5(%rcx,%r14,2)
 11261c6:	mov    %sil,-0x3(%r10)
 11261ca:	movzbl -0x4(%rcx,%r14,2),%esi
 11261d0:	movzbl -0x2(%r10),%r8d
 11261d5:	mov    %r8b,-0x4(%rcx,%r14,2)
 11261da:	mov    %sil,-0x2(%r10)
 11261de:	movzbl -0x3(%rcx,%r14,2),%esi
 11261e4:	movzbl -0x5(%r10),%r8d
 11261e9:	mov    %r8b,-0x3(%rcx,%r14,2)
 11261ee:	mov    %sil,-0x5(%r10)
 11261f2:	movzbl -0x2(%rcx,%r14,2),%esi
 11261f8:	movzbl -0x4(%r10),%r8d
 11261fd:	mov    %r8b,-0x2(%rcx,%r14,2)
 1126202:	mov    %sil,-0x4(%r10)
 1126206:	movzbl -0x1(%rcx,%r14,2),%esi
 112620c:	movzbl -0x7(%r10),%r8d
 1126211:	mov    %r8b,-0x1(%rcx,%r14,2)
 1126216:	mov    %sil,-0x7(%r10)
 112621a:	movzbl (%rcx,%r14,2),%esi
 112621f:	movzbl -0x6(%r10),%r8d
 1126224:	mov    %r8b,(%rcx,%r14,2)
 1126228:	mov    %sil,-0x6(%r10)
 112622c:	add    $0x4,%r14
 1126230:	add    $0xfffffffffffffff8,%r10
 1126234:	cmp    %r14,%r11
 1126237:	jne    1126190 <sort.block.block__anon_39113+0x8670>
 112623d:	mov    %rax,%r10
 1126240:	shr    %r10
 1126243:	cmp    $0x20,%rax
 1126247:	setb   %al
 112624a:	cmp    $0xf,%r10
 112624e:	sete   %cl
 1126251:	or     %al,%cl
 1126253:	je     1126260 <sort.block.block__anon_39113+0x8740>
 1126255:	xor    %eax,%eax
 1126257:	jmp    11263ef <sort.block.block__anon_39113+0x88cf>
 112625c:	nopl   0x0(%rax)
 1126260:	lea    -0x10(%r10),%rax
 1126264:	mov    %rax,%r11
 1126267:	shr    $0x4,%r11
 112626b:	inc    %r11
 112626e:	cmp    $0x30,%rax
 1126272:	jae    1126290 <sort.block.block__anon_39113+0x8770>
 1126274:	xor    %eax,%eax
 1126276:	and    $0x3,%r11d
 112627a:	jne    112638f <sort.block.block__anon_39113+0x886f>
 1126280:	jmp    11263ef <sort.block.block__anon_39113+0x88cf>
 1126285:	data16 cs nopw 0x0(%rax,%rax,1)
 1126290:	mov    %r11,%rcx
 1126293:	movabs $0x1ffffffffffffffc,%rax
 112629d:	and    %rax,%rcx
 11262a0:	mov    -0xc8(%rbp),%rax
 11262a7:	lea    (%rax,%rdi,2),%rbx
 11262ab:	mov    -0x58(%rbp),%rax
 11262af:	lea    (%rax,%rdx,2),%r14
 11262b3:	xor    %eax,%eax
 11262b5:	data16 cs nopw 0x0(%rax,%rax,1)
 11262c0:	vmovdqu (%r14,%rax,2),%ymm0
 11262c6:	vmovdqu -0x60(%rbx),%ymm1
 11262cb:	vpshufb %ymm2,%ymm1,%ymm1
 11262d0:	vpermq $0x4e,%ymm1,%ymm1
 11262d6:	vmovdqu %ymm1,(%r14,%rax,2)
 11262dc:	vpshufb %ymm2,%ymm0,%ymm0
 11262e1:	vpermq $0x4e,%ymm0,%ymm0
 11262e7:	vmovdqu %ymm0,-0x60(%rbx)
 11262ec:	vmovdqu -0x20(%r14,%rax,2),%ymm0
 11262f3:	vmovdqu -0x40(%rbx),%ymm1
 11262f8:	vpshufb %ymm2,%ymm1,%ymm1
 11262fd:	vpermq $0x4e,%ymm1,%ymm1
 1126303:	vmovdqu %ymm1,-0x20(%r14,%rax,2)
 112630a:	vpshufb %ymm2,%ymm0,%ymm0
 112630f:	vpermq $0x4e,%ymm0,%ymm0
 1126315:	vmovdqu %ymm0,-0x40(%rbx)
 112631a:	vmovdqu -0x40(%r14,%rax,2),%ymm0
 1126321:	vmovdqu -0x20(%rbx),%ymm1
 1126326:	vpshufb %ymm2,%ymm1,%ymm1
 112632b:	vpermq $0x4e,%ymm1,%ymm1
 1126331:	vmovdqu %ymm1,-0x40(%r14,%rax,2)
 1126338:	vpshufb %ymm2,%ymm0,%ymm0
 112633d:	vpermq $0x4e,%ymm0,%ymm0
 1126343:	vmovdqu %ymm0,-0x20(%rbx)
 1126348:	vmovdqu -0x60(%r14,%rax,2),%ymm0
 112634f:	vmovdqu (%rbx),%ymm1
 1126353:	vpshufb %ymm2,%ymm1,%ymm1
 1126358:	vpermq $0x4e,%ymm1,%ymm1
 112635e:	vmovdqu %ymm1,-0x60(%r14,%rax,2)
 1126365:	vpshufb %ymm2,%ymm0,%ymm0
 112636a:	vpermq $0x4e,%ymm0,%ymm0
 1126370:	vmovdqu %ymm0,(%rbx)
 1126374:	sub    $0xffffffffffffff80,%rbx
 1126378:	add    $0xffffffffffffffc0,%rax
 112637c:	add    $0xfffffffffffffffc,%rcx
 1126380:	jne    11262c0 <sort.block.block__anon_39113+0x87a0>
 1126386:	neg    %rax
 1126389:	and    $0x3,%r11d
 112638d:	je     11263ef <sort.block.block__anon_39113+0x88cf>
 112638f:	mov    -0x58(%rbp),%rcx
 1126393:	lea    (%rcx,%rdx,2),%rbx
 1126397:	mov    %rax,%rcx
 112639a:	neg    %rcx
 112639d:	add    %rax,%rax
 11263a0:	lea    (%rax,%rdi,2),%rax
 11263a4:	add    -0x38(%rbp),%rax
 11263a8:	shl    $0x5,%r11d
 11263ac:	xor    %r14d,%r14d
 11263af:	nop
 11263b0:	vmovdqu (%rbx,%rcx,2),%ymm0
 11263b5:	vmovdqu (%rax,%r14,1),%ymm1
 11263bb:	vpshufb %ymm2,%ymm1,%ymm1
 11263c0:	vpermq $0x4e,%ymm1,%ymm1
 11263c6:	vmovdqu %ymm1,(%rbx,%rcx,2)
 11263cb:	vpshufb %ymm2,%ymm0,%ymm0
 11263d0:	vpermq $0x4e,%ymm0,%ymm0
 11263d6:	vmovdqu %ymm0,(%rax,%r14,1)
 11263dc:	add    $0xfffffffffffffff0,%rcx
 11263e0:	add    $0x20,%r14
 11263e4:	cmp    %r14,%r11
 11263e7:	jne    11263b0 <sort.block.block__anon_39113+0x8890>
 11263e9:	neg    %rcx
 11263ec:	mov    %rcx,%rax
 11263ef:	mov    %rax,%rcx
 11263f2:	sub    %r10,%rcx
 11263f5:	jae    1125a30 <sort.block.block__anon_39113+0x7f10>
 11263fb:	mov    %r10d,%r11d
 11263fe:	sub    %eax,%r11d
 1126401:	and    $0x3,%r11d
 1126405:	je     1126463 <sort.block.block__anon_39113+0x8943>
 1126407:	mov    -0x48(%rbp),%r8
 112640b:	lea    (%r8,%rdx,2),%rbx
 112640f:	sub    %rax,%rbx
 1126412:	sub    %rax,%rbx
 1126415:	lea    (%rdi,%rdi,1),%rsi
 1126419:	lea    (%rsi,%rax,2),%r14
 112641d:	add    -0x50(%rbp),%r14
 1126421:	neg    %r11
 1126424:	xor    %r15d,%r15d
 1126427:	nopw   0x0(%rax,%rax,1)
 1126430:	movzbl -0x1(%r14),%esi
 1126435:	movzbl -0x1(%rbx,%r15,2),%r8d
 112643b:	mov    %r8b,-0x1(%r14)
 112643f:	mov    %sil,-0x1(%rbx,%r15,2)
 1126444:	movzbl (%r14),%esi
 1126448:	movzbl (%rbx,%r15,2),%r8d
 112644d:	mov    %r8b,(%r14)
 1126450:	mov    %sil,(%rbx,%r15,2)
 1126454:	dec    %r15
 1126457:	add    $0x2,%r14
 112645b:	cmp    %r15,%r11
 112645e:	jne    1126430 <sort.block.block__anon_39113+0x8910>
 1126460:	sub    %r15,%rax
 1126463:	cmp    $0xfffffffffffffffc,%rcx
 1126467:	ja     1125a30 <sort.block.block__anon_39113+0x7f10>
 112646d:	mov    -0x80(%rbp),%rcx
 1126471:	lea    (%rcx,%rdi,2),%rcx
 1126475:	mov    -0x48(%rbp),%r8
 1126479:	lea    (%r8,%rdx,2),%r11
 112647d:	sub    %rax,%r11
 1126480:	sub    %rax,%r11
 1126483:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1126490:	movzbl -0x7(%rcx,%rax,2),%esi
 1126495:	movzbl -0x1(%r11),%r8d
 112649a:	mov    %r8b,-0x7(%rcx,%rax,2)
 112649f:	mov    %sil,-0x1(%r11)
 11264a3:	movzbl -0x6(%rcx,%rax,2),%esi
 11264a8:	movzbl (%r11),%r8d
 11264ac:	mov    %r8b,-0x6(%rcx,%rax,2)
 11264b1:	mov    %sil,(%r11)
 11264b4:	movzbl -0x5(%rcx,%rax,2),%esi
 11264b9:	movzbl -0x3(%r11),%r8d
 11264be:	mov    %r8b,-0x5(%rcx,%rax,2)
 11264c3:	mov    %sil,-0x3(%r11)
 11264c7:	movzbl -0x4(%rcx,%rax,2),%esi
 11264cc:	movzbl -0x2(%r11),%r8d
 11264d1:	mov    %r8b,-0x4(%rcx,%rax,2)
 11264d6:	mov    %sil,-0x2(%r11)
 11264da:	movzbl -0x3(%rcx,%rax,2),%esi
 11264df:	movzbl -0x5(%r11),%r8d
 11264e4:	mov    %r8b,-0x3(%rcx,%rax,2)
 11264e9:	mov    %sil,-0x5(%r11)
 11264ed:	movzbl -0x2(%rcx,%rax,2),%esi
 11264f2:	movzbl -0x4(%r11),%r8d
 11264f7:	mov    %r8b,-0x2(%rcx,%rax,2)
 11264fc:	mov    %sil,-0x4(%r11)
 1126500:	movzbl -0x1(%rcx,%rax,2),%esi
 1126505:	movzbl -0x7(%r11),%r8d
 112650a:	mov    %r8b,-0x1(%rcx,%rax,2)
 112650f:	mov    %sil,-0x7(%r11)
 1126513:	movzbl (%rcx,%rax,2),%esi
 1126517:	movzbl -0x6(%r11),%r8d
 112651c:	mov    %r8b,(%rcx,%rax,2)
 1126520:	mov    %sil,-0x6(%r11)
 1126524:	add    $0x4,%rax
 1126528:	add    $0xfffffffffffffff8,%r11
 112652c:	cmp    %rax,%r10
 112652f:	jne    1126490 <sort.block.block__anon_39113+0x8970>
 1126535:	jmp    1125a30 <sort.block.block__anon_39113+0x7f10>
 112653a:	nopw   0x0(%rax,%rax,1)
 1126540:	jae    11259e0 <sort.block.block__anon_39113+0x7ec0>
 1126546:	test   %r10,%r10
 1126549:	je     11259e0 <sort.block.block__anon_39113+0x7ec0>
 112654f:	mov    0x18(%rax),%rdi
 1126553:	mov    0x20(%rax),%r8
 1126557:	mov    %r8,%rdx
 112655a:	sub    %r10,%rdx
 112655d:	mov    %rdi,-0x68(%rbp)
 1126561:	jmp    112658b <sort.block.block__anon_39113+0x8a6b>
 1126563:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1126570:	not    %rax
 1126573:	add    %rax,%r8
 1126576:	mov    -0x40(%rbp),%rsi
 112657a:	add    $0xfffffffffffffffe,%rsi
 112657e:	cmp    %rdx,%r8
 1126581:	mov    -0x68(%rbp),%rdi
 1126585:	je     11259e0 <sort.block.block__anon_39113+0x7ec0>
 112658b:	mov    %rsi,-0x40(%rbp)
 112658f:	mov    %rdx,%r9
 1126592:	mov    %rdx,%rax
 1126595:	sub    %rdi,%rax
 1126598:	je     11266f0 <sort.block.block__anon_39113+0x8bd0>
 112659e:	movzwl 0x0(%r13,%r8,2),%r15d
 11265a4:	mov    %rax,%rcx
 11265a7:	mov    -0x40(%rbp),%rsi
 11265ab:	or     %rsi,%rcx
 11265ae:	shr    $0x20,%rcx
 11265b2:	je     11265bb <sort.block.block__anon_39113+0x8a9b>
 11265b4:	xor    %edx,%edx
 11265b6:	div    %rsi
 11265b9:	jmp    11265bf <sort.block.block__anon_39113+0x8a9f>
 11265bb:	xor    %edx,%edx
 11265bd:	div    %esi
 11265bf:	cmp    $0x1,%rax
 11265c3:	adc    $0x0,%rax
 11265c7:	lea    (%rax,%rdi,1),%rcx
 11265cb:	mov    -0x30(%rbp),%rdx
 11265cf:	mov    (%rdx),%r10
 11265d2:	mov    %r15d,%r14d
 11265d5:	shl    $0x4,%r14d
 11265d9:	add    %r10,%r14
 11265dc:	mov    %r9,%rdx
 11265df:	nop
 11265e0:	sub    %rax,%rdx
 11265e3:	mov    %rdx,%r12
 11265e6:	sub    %rdi,%r12
 11265e9:	jbe    112667e <sort.block.block__anon_39113+0x8b5e>
 11265ef:	movzwl 0x0(%r13,%rdx,2),%ebx
 11265f5:	mov    (%r14),%r11
 11265f8:	shl    $0x4,%ebx
 11265fb:	cmp    (%r10,%rbx,1),%r11
 11265ff:	jne    112660d <sort.block.block__anon_39113+0x8aed>
 1126601:	add    %r10,%rbx
 1126604:	movzwl 0xe(%r14),%esi
 1126609:	cmp    0xe(%rbx),%si
 112660d:	jae    1126681 <sort.block.block__anon_39113+0x8b61>
 112660f:	cmp    %rcx,%rdx
 1126612:	jae    11265e0 <sort.block.block__anon_39113+0x8ac0>
 1126614:	mov    %rdi,%rdx
 1126617:	jmp    1126639 <sort.block.block__anon_39113+0x8b19>
 1126619:	nopl   0x0(%rax)
 1126620:	mov    %r12d,%ecx
 1126623:	and    $0x1,%ecx
 1126626:	add    %rax,%rcx
 1126629:	add    %rcx,%rdx
 112662c:	cmp    $0x1,%r12
 1126630:	mov    %rax,%r12
 1126633:	jbe    11266f0 <sort.block.block__anon_39113+0x8bd0>
 1126639:	mov    -0x38(%rbp),%rax
 112663d:	lea    (%rax,%rdx,2),%rax
 1126641:	mov    %r12,%rcx
 1126644:	and    $0xfffffffffffffffe,%rcx
 1126648:	movzwl (%rcx,%rax,1),%eax
 112664c:	shl    $0x4,%eax
 112664f:	cmp    (%r10,%rax,1),%r11
 1126653:	jne    1126661 <sort.block.block__anon_39113+0x8b41>
 1126655:	add    %r10,%rax
 1126658:	movzwl 0xe(%r14),%ecx
 112665d:	cmp    0xe(%rax),%cx
 1126661:	setb   %cl
 1126664:	mov    %r12,%rax
 1126667:	shr    %rax
 112666a:	test   %cl,%cl
 112666c:	je     1126620 <sort.block.block__anon_39113+0x8b00>
 112666e:	xor    %ecx,%ecx
 1126670:	add    %rcx,%rdx
 1126673:	cmp    $0x1,%r12
 1126677:	mov    %rax,%r12
 112667a:	ja     1126639 <sort.block.block__anon_39113+0x8b19>
 112667c:	jmp    11266f0 <sort.block.block__anon_39113+0x8bd0>
 112667e:	mov    (%r14),%r11
 1126681:	shl    $0x4,%r15d
 1126685:	lea    (%r10,%r15,1),%rcx
 1126689:	add    $0xe,%rcx
 112668d:	jmp    11266a6 <sort.block.block__anon_39113+0x8b86>
 112668f:	nop
 1126690:	mov    %eax,%r14d
 1126693:	and    $0x1,%r14d
 1126697:	add    %rbx,%r14
 112669a:	add    %r14,%rdx
 112669d:	cmp    $0x2,%rax
 11266a1:	mov    %rbx,%rax
 11266a4:	jb     11266f0 <sort.block.block__anon_39113+0x8bd0>
 11266a6:	mov    -0x38(%rbp),%rsi
 11266aa:	lea    (%rsi,%rdx,2),%rsi
 11266ae:	mov    %rax,%rbx
 11266b1:	and    $0xfffffffffffffffe,%rbx
 11266b5:	movzwl (%rbx,%rsi,1),%ebx
 11266b9:	shl    $0x4,%ebx
 11266bc:	cmp    (%r10,%rbx,1),%r11
 11266c0:	jne    11266cc <sort.block.block__anon_39113+0x8bac>
 11266c2:	add    %r10,%rbx
 11266c5:	movzwl (%rcx),%esi
 11266c8:	cmp    0xe(%rbx),%si
 11266cc:	setb   %r14b
 11266d0:	mov    %rax,%rbx
 11266d3:	shr    %rbx
 11266d6:	test   %r14b,%r14b
 11266d9:	je     1126690 <sort.block.block__anon_39113+0x8b70>
 11266db:	xor    %r14d,%r14d
 11266de:	add    %r14,%rdx
 11266e1:	cmp    $0x2,%rax
 11266e5:	mov    %rbx,%rax
 11266e8:	jae    11266a6 <sort.block.block__anon_39113+0x8b86>
 11266ea:	nopw   0x0(%rax,%rax,1)
 11266f0:	mov    %r9,%rax
 11266f3:	sub    %rdx,%rax
 11266f6:	mov    %rax,%r10
 11266f9:	shr    %r10
 11266fc:	cmp    $0x20,%rax
 1126700:	setb   %cl
 1126703:	cmp    $0xf,%r10
 1126707:	sete   %sil
 112670b:	or     %cl,%sil
 112670e:	je     1126720 <sort.block.block__anon_39113+0x8c00>
 1126710:	xor    %r11d,%r11d
 1126713:	jmp    11268af <sort.block.block__anon_39113+0x8d8f>
 1126718:	nopl   0x0(%rax,%rax,1)
 1126720:	lea    -0x10(%r10),%rcx
 1126724:	mov    %rcx,%r14
 1126727:	shr    $0x4,%r14
 112672b:	inc    %r14
 112672e:	cmp    $0x30,%rcx
 1126732:	jae    1126750 <sort.block.block__anon_39113+0x8c30>
 1126734:	xor    %r11d,%r11d
 1126737:	and    $0x3,%r14d
 112673b:	jne    112684f <sort.block.block__anon_39113+0x8d2f>
 1126741:	jmp    11268af <sort.block.block__anon_39113+0x8d8f>
 1126746:	cs nopw 0x0(%rax,%rax,1)
 1126750:	mov    %r14,%rcx
 1126753:	movabs $0x1ffffffffffffffc,%rsi
 112675d:	and    %rsi,%rcx
 1126760:	mov    -0xc8(%rbp),%rsi
 1126767:	lea    (%rsi,%rdx,2),%rbx
 112676b:	mov    -0x58(%rbp),%rsi
 112676f:	lea    (%rsi,%r9,2),%r15
 1126773:	xor    %r11d,%r11d
 1126776:	cs nopw 0x0(%rax,%rax,1)
 1126780:	vmovdqu (%r15,%r11,2),%ymm0
 1126786:	vmovdqu -0x60(%rbx),%ymm1
 112678b:	vpshufb %ymm2,%ymm1,%ymm1
 1126790:	vpermq $0x4e,%ymm1,%ymm1
 1126796:	vmovdqu %ymm1,(%r15,%r11,2)
 112679c:	vpshufb %ymm2,%ymm0,%ymm0
 11267a1:	vpermq $0x4e,%ymm0,%ymm0
 11267a7:	vmovdqu %ymm0,-0x60(%rbx)
 11267ac:	vmovdqu -0x20(%r15,%r11,2),%ymm0
 11267b3:	vmovdqu -0x40(%rbx),%ymm1
 11267b8:	vpshufb %ymm2,%ymm1,%ymm1
 11267bd:	vpermq $0x4e,%ymm1,%ymm1
 11267c3:	vmovdqu %ymm1,-0x20(%r15,%r11,2)
 11267ca:	vpshufb %ymm2,%ymm0,%ymm0
 11267cf:	vpermq $0x4e,%ymm0,%ymm0
 11267d5:	vmovdqu %ymm0,-0x40(%rbx)
 11267da:	vmovdqu -0x40(%r15,%r11,2),%ymm0
 11267e1:	vmovdqu -0x20(%rbx),%ymm1
 11267e6:	vpshufb %ymm2,%ymm1,%ymm1
 11267eb:	vpermq $0x4e,%ymm1,%ymm1
 11267f1:	vmovdqu %ymm1,-0x40(%r15,%r11,2)
 11267f8:	vpshufb %ymm2,%ymm0,%ymm0
 11267fd:	vpermq $0x4e,%ymm0,%ymm0
 1126803:	vmovdqu %ymm0,-0x20(%rbx)
 1126808:	vmovdqu -0x60(%r15,%r11,2),%ymm0
 112680f:	vmovdqu (%rbx),%ymm1
 1126813:	vpshufb %ymm2,%ymm1,%ymm1
 1126818:	vpermq $0x4e,%ymm1,%ymm1
 112681e:	vmovdqu %ymm1,-0x60(%r15,%r11,2)
 1126825:	vpshufb %ymm2,%ymm0,%ymm0
 112682a:	vpermq $0x4e,%ymm0,%ymm0
 1126830:	vmovdqu %ymm0,(%rbx)
 1126834:	sub    $0xffffffffffffff80,%rbx
 1126838:	add    $0xffffffffffffffc0,%r11
 112683c:	add    $0xfffffffffffffffc,%rcx
 1126840:	jne    1126780 <sort.block.block__anon_39113+0x8c60>
 1126846:	neg    %r11
 1126849:	and    $0x3,%r14d
 112684d:	je     11268af <sort.block.block__anon_39113+0x8d8f>
 112684f:	mov    -0x58(%rbp),%rcx
 1126853:	lea    (%rcx,%r9,2),%rbx
 1126857:	mov    %r11,%rcx
 112685a:	neg    %rcx
 112685d:	add    %r11,%r11
 1126860:	lea    (%r11,%rdx,2),%r11
 1126864:	add    -0x38(%rbp),%r11
 1126868:	shl    $0x5,%r14d
 112686c:	xor    %r15d,%r15d
 112686f:	nop
 1126870:	vmovdqu (%rbx,%rcx,2),%ymm0
 1126875:	vmovdqu (%r11,%r15,1),%ymm1
 112687b:	vpshufb %ymm2,%ymm1,%ymm1
 1126880:	vpermq $0x4e,%ymm1,%ymm1
 1126886:	vmovdqu %ymm1,(%rbx,%rcx,2)
 112688b:	vpshufb %ymm2,%ymm0,%ymm0
 1126890:	vpermq $0x4e,%ymm0,%ymm0
 1126896:	vmovdqu %ymm0,(%r11,%r15,1)
 112689c:	add    $0xfffffffffffffff0,%rcx
 11268a0:	add    $0x20,%r15
 11268a4:	cmp    %r15,%r14
 11268a7:	jne    1126870 <sort.block.block__anon_39113+0x8d50>
 11268a9:	neg    %rcx
 11268ac:	mov    %rcx,%r11
 11268af:	mov    %r11,%rcx
 11268b2:	sub    %r10,%rcx
 11268b5:	jae    11269fd <sort.block.block__anon_39113+0x8edd>
 11268bb:	mov    %r10d,%ebx
 11268be:	sub    %r11d,%ebx
 11268c1:	and    $0x3,%ebx
 11268c4:	je     112692a <sort.block.block__anon_39113+0x8e0a>
 11268c6:	lea    (%r11,%r11,1),%rsi
 11268ca:	mov    -0x48(%rbp),%rdi
 11268ce:	lea    (%rdi,%r9,2),%r14
 11268d2:	sub    %rsi,%r14
 11268d5:	lea    (%rsi,%rdx,2),%r15
 11268d9:	add    -0x50(%rbp),%r15
 11268dd:	neg    %rbx
 11268e0:	xor    %r12d,%r12d
 11268e3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11268f0:	movzbl -0x1(%r15),%esi
 11268f5:	movzbl -0x1(%r14,%r12,2),%r13d
 11268fb:	mov    %r13b,-0x1(%r15)
 11268ff:	mov    %sil,-0x1(%r14,%r12,2)
 1126904:	movzbl (%r15),%esi
 1126908:	movzbl (%r14,%r12,2),%r13d
 112690d:	mov    %r13b,(%r15)
 1126910:	mov    %sil,(%r14,%r12,2)
 1126914:	dec    %r12
 1126917:	add    $0x2,%r15
 112691b:	cmp    %r12,%rbx
 112691e:	jne    11268f0 <sort.block.block__anon_39113+0x8dd0>
 1126920:	sub    %r12,%r11
 1126923:	mov    -0x98(%rbp),%r13
 112692a:	cmp    $0xfffffffffffffffc,%rcx
 112692e:	ja     11269fd <sort.block.block__anon_39113+0x8edd>
 1126934:	mov    -0x80(%rbp),%rcx
 1126938:	lea    (%rcx,%rdx,2),%rcx
 112693c:	mov    -0x48(%rbp),%rdi
 1126940:	lea    (%rdi,%r9,2),%rbx
 1126944:	sub    %r11,%rbx
 1126947:	sub    %r11,%rbx
 112694a:	nopw   0x0(%rax,%rax,1)
 1126950:	movzbl -0x7(%rcx,%r11,2),%esi
 1126956:	movzbl -0x1(%rbx),%r14d
 112695b:	mov    %r14b,-0x7(%rcx,%r11,2)
 1126960:	mov    %sil,-0x1(%rbx)
 1126964:	movzbl -0x6(%rcx,%r11,2),%esi
 112696a:	movzbl (%rbx),%r14d
 112696e:	mov    %r14b,-0x6(%rcx,%r11,2)
 1126973:	mov    %sil,(%rbx)
 1126976:	movzbl -0x5(%rcx,%r11,2),%esi
 112697c:	movzbl -0x3(%rbx),%r14d
 1126981:	mov    %r14b,-0x5(%rcx,%r11,2)
 1126986:	mov    %sil,-0x3(%rbx)
 112698a:	movzbl -0x4(%rcx,%r11,2),%esi
 1126990:	movzbl -0x2(%rbx),%r14d
 1126995:	mov    %r14b,-0x4(%rcx,%r11,2)
 112699a:	mov    %sil,-0x2(%rbx)
 112699e:	movzbl -0x3(%rcx,%r11,2),%esi
 11269a4:	movzbl -0x5(%rbx),%r14d
 11269a9:	mov    %r14b,-0x3(%rcx,%r11,2)
 11269ae:	mov    %sil,-0x5(%rbx)
 11269b2:	movzbl -0x2(%rcx,%r11,2),%esi
 11269b8:	movzbl -0x4(%rbx),%r14d
 11269bd:	mov    %r14b,-0x2(%rcx,%r11,2)
 11269c2:	mov    %sil,-0x4(%rbx)
 11269c6:	movzbl -0x1(%rcx,%r11,2),%esi
 11269cc:	movzbl -0x7(%rbx),%r14d
 11269d1:	mov    %r14b,-0x1(%rcx,%r11,2)
 11269d6:	mov    %sil,-0x7(%rbx)
 11269da:	movzbl (%rcx,%r11,2),%esi
 11269df:	movzbl -0x6(%rbx),%r14d
 11269e4:	mov    %r14b,(%rcx,%r11,2)
 11269e8:	mov    %sil,-0x6(%rbx)
 11269ec:	add    $0x4,%r11
 11269f0:	add    $0xfffffffffffffff8,%rbx
 11269f4:	cmp    %r11,%r10
 11269f7:	jne    1126950 <sort.block.block__anon_39113+0x8e30>
 11269fd:	mov    %r8,%r10
 1126a00:	sub    %rdx,%r10
 1126a03:	mov    %r10,%rcx
 1126a06:	sub    %rax,%rcx
 1126a09:	mov    %rcx,%r11
 1126a0c:	shr    %r11
 1126a0f:	cmp    $0x20,%rcx
 1126a13:	setb   %cl
 1126a16:	cmp    $0xf,%r11
 1126a1a:	sete   %sil
 1126a1e:	or     %cl,%sil
 1126a21:	je     1126a30 <sort.block.block__anon_39113+0x8f10>
 1126a23:	xor    %r14d,%r14d
 1126a26:	jmp    1126bbf <sort.block.block__anon_39113+0x909f>
 1126a2b:	nopl   0x0(%rax,%rax,1)
 1126a30:	lea    -0x10(%r11),%rcx
 1126a34:	mov    %rcx,%r15
 1126a37:	shr    $0x4,%r15
 1126a3b:	inc    %r15
 1126a3e:	cmp    $0x30,%rcx
 1126a42:	jae    1126a60 <sort.block.block__anon_39113+0x8f40>
 1126a44:	xor    %r14d,%r14d
 1126a47:	and    $0x3,%r15d
 1126a4b:	jne    1126b5f <sort.block.block__anon_39113+0x903f>
 1126a51:	jmp    1126bbf <sort.block.block__anon_39113+0x909f>
 1126a56:	cs nopw 0x0(%rax,%rax,1)
 1126a60:	mov    %r15,%rcx
 1126a63:	movabs $0x1ffffffffffffffc,%rsi
 1126a6d:	and    %rsi,%rcx
 1126a70:	mov    -0xc8(%rbp),%rsi
 1126a77:	lea    (%rsi,%r9,2),%rbx
 1126a7b:	mov    -0x58(%rbp),%rsi
 1126a7f:	lea    (%rsi,%r8,2),%r12
 1126a83:	xor    %r14d,%r14d
 1126a86:	cs nopw 0x0(%rax,%rax,1)
 1126a90:	vmovdqu (%r12,%r14,2),%ymm0
 1126a96:	vmovdqu -0x60(%rbx),%ymm1
 1126a9b:	vpshufb %ymm2,%ymm1,%ymm1
 1126aa0:	vpermq $0x4e,%ymm1,%ymm1
 1126aa6:	vmovdqu %ymm1,(%r12,%r14,2)
 1126aac:	vpshufb %ymm2,%ymm0,%ymm0
 1126ab1:	vpermq $0x4e,%ymm0,%ymm0
 1126ab7:	vmovdqu %ymm0,-0x60(%rbx)
 1126abc:	vmovdqu -0x20(%r12,%r14,2),%ymm0
 1126ac3:	vmovdqu -0x40(%rbx),%ymm1
 1126ac8:	vpshufb %ymm2,%ymm1,%ymm1
 1126acd:	vpermq $0x4e,%ymm1,%ymm1
 1126ad3:	vmovdqu %ymm1,-0x20(%r12,%r14,2)
 1126ada:	vpshufb %ymm2,%ymm0,%ymm0
 1126adf:	vpermq $0x4e,%ymm0,%ymm0
 1126ae5:	vmovdqu %ymm0,-0x40(%rbx)
 1126aea:	vmovdqu -0x40(%r12,%r14,2),%ymm0
 1126af1:	vmovdqu -0x20(%rbx),%ymm1
 1126af6:	vpshufb %ymm2,%ymm1,%ymm1
 1126afb:	vpermq $0x4e,%ymm1,%ymm1
 1126b01:	vmovdqu %ymm1,-0x40(%r12,%r14,2)
 1126b08:	vpshufb %ymm2,%ymm0,%ymm0
 1126b0d:	vpermq $0x4e,%ymm0,%ymm0
 1126b13:	vmovdqu %ymm0,-0x20(%rbx)
 1126b18:	vmovdqu -0x60(%r12,%r14,2),%ymm0
 1126b1f:	vmovdqu (%rbx),%ymm1
 1126b23:	vpshufb %ymm2,%ymm1,%ymm1
 1126b28:	vpermq $0x4e,%ymm1,%ymm1
 1126b2e:	vmovdqu %ymm1,-0x60(%r12,%r14,2)
 1126b35:	vpshufb %ymm2,%ymm0,%ymm0
 1126b3a:	vpermq $0x4e,%ymm0,%ymm0
 1126b40:	vmovdqu %ymm0,(%rbx)
 1126b44:	sub    $0xffffffffffffff80,%rbx
 1126b48:	add    $0xffffffffffffffc0,%r14
 1126b4c:	add    $0xfffffffffffffffc,%rcx
 1126b50:	jne    1126a90 <sort.block.block__anon_39113+0x8f70>
 1126b56:	neg    %r14
 1126b59:	and    $0x3,%r15d
 1126b5d:	je     1126bbf <sort.block.block__anon_39113+0x909f>
 1126b5f:	mov    -0x58(%rbp),%rcx
 1126b63:	lea    (%rcx,%r8,2),%rbx
 1126b67:	mov    %r14,%rcx
 1126b6a:	neg    %rcx
 1126b6d:	add    %r14,%r14
 1126b70:	lea    (%r14,%r9,2),%r14
 1126b74:	add    -0x38(%rbp),%r14
 1126b78:	shl    $0x5,%r15d
 1126b7c:	xor    %r12d,%r12d
 1126b7f:	nop
 1126b80:	vmovdqu (%rbx,%rcx,2),%ymm0
 1126b85:	vmovdqu (%r14,%r12,1),%ymm1
 1126b8b:	vpshufb %ymm2,%ymm1,%ymm1
 1126b90:	vpermq $0x4e,%ymm1,%ymm1
 1126b96:	vmovdqu %ymm1,(%rbx,%rcx,2)
 1126b9b:	vpshufb %ymm2,%ymm0,%ymm0
 1126ba0:	vpermq $0x4e,%ymm0,%ymm0
 1126ba6:	vmovdqu %ymm0,(%r14,%r12,1)
 1126bac:	add    $0xfffffffffffffff0,%rcx
 1126bb0:	add    $0x20,%r12
 1126bb4:	cmp    %r12,%r15
 1126bb7:	jne    1126b80 <sort.block.block__anon_39113+0x9060>
 1126bb9:	neg    %rcx
 1126bbc:	mov    %rcx,%r14
 1126bbf:	mov    %r14,%rcx
 1126bc2:	sub    %r11,%rcx
 1126bc5:	jae    1126d0d <sort.block.block__anon_39113+0x91ed>
 1126bcb:	mov    %r11d,%ebx
 1126bce:	sub    %r14d,%ebx
 1126bd1:	and    $0x3,%ebx
 1126bd4:	je     1126c3e <sort.block.block__anon_39113+0x911e>
 1126bd6:	mov    -0x48(%rbp),%rdi
 1126bda:	lea    (%rdi,%r8,2),%r15
 1126bde:	sub    %r14,%r15
 1126be1:	sub    %r14,%r15
 1126be4:	lea    (%r9,%r9,1),%rsi
 1126be8:	lea    (%rsi,%r14,2),%r12
 1126bec:	add    -0x50(%rbp),%r12
 1126bf0:	neg    %rbx
 1126bf3:	xor    %r13d,%r13d
 1126bf6:	cs nopw 0x0(%rax,%rax,1)
 1126c00:	movzbl -0x1(%r12),%esi
 1126c06:	movzbl -0x1(%r15,%r13,2),%edi
 1126c0c:	mov    %dil,-0x1(%r12)
 1126c11:	mov    %sil,-0x1(%r15,%r13,2)
 1126c16:	movzbl (%r12),%esi
 1126c1b:	movzbl (%r15,%r13,2),%edi
 1126c20:	mov    %dil,(%r12)
 1126c24:	mov    %sil,(%r15,%r13,2)
 1126c28:	dec    %r13
 1126c2b:	add    $0x2,%r12
 1126c2f:	cmp    %r13,%rbx
 1126c32:	jne    1126c00 <sort.block.block__anon_39113+0x90e0>
 1126c34:	sub    %r13,%r14
 1126c37:	mov    -0x98(%rbp),%r13
 1126c3e:	cmp    $0xfffffffffffffffc,%rcx
 1126c42:	ja     1126d0d <sort.block.block__anon_39113+0x91ed>
 1126c48:	mov    -0x80(%rbp),%rcx
 1126c4c:	lea    (%rcx,%r9,2),%rcx
 1126c50:	mov    -0x48(%rbp),%rdi
 1126c54:	lea    (%rdi,%r8,2),%r9
 1126c58:	sub    %r14,%r9
 1126c5b:	sub    %r14,%r9
 1126c5e:	xchg   %ax,%ax
 1126c60:	movzbl -0x7(%rcx,%r14,2),%esi
 1126c66:	movzbl -0x1(%r9),%edi
 1126c6b:	mov    %dil,-0x7(%rcx,%r14,2)
 1126c70:	mov    %sil,-0x1(%r9)
 1126c74:	movzbl -0x6(%rcx,%r14,2),%esi
 1126c7a:	movzbl (%r9),%edi
 1126c7e:	mov    %dil,-0x6(%rcx,%r14,2)
 1126c83:	mov    %sil,(%r9)
 1126c86:	movzbl -0x5(%rcx,%r14,2),%esi
 1126c8c:	movzbl -0x3(%r9),%edi
 1126c91:	mov    %dil,-0x5(%rcx,%r14,2)
 1126c96:	mov    %sil,-0x3(%r9)
 1126c9a:	movzbl -0x4(%rcx,%r14,2),%esi
 1126ca0:	movzbl -0x2(%r9),%edi
 1126ca5:	mov    %dil,-0x4(%rcx,%r14,2)
 1126caa:	mov    %sil,-0x2(%r9)
 1126cae:	movzbl -0x3(%rcx,%r14,2),%esi
 1126cb4:	movzbl -0x5(%r9),%edi
 1126cb9:	mov    %dil,-0x3(%rcx,%r14,2)
 1126cbe:	mov    %sil,-0x5(%r9)
 1126cc2:	movzbl -0x2(%rcx,%r14,2),%esi
 1126cc8:	movzbl -0x4(%r9),%edi
 1126ccd:	mov    %dil,-0x2(%rcx,%r14,2)
 1126cd2:	mov    %sil,-0x4(%r9)
 1126cd6:	movzbl -0x1(%rcx,%r14,2),%esi
 1126cdc:	movzbl -0x7(%r9),%edi
 1126ce1:	mov    %dil,-0x1(%rcx,%r14,2)
 1126ce6:	mov    %sil,-0x7(%r9)
 1126cea:	movzbl (%rcx,%r14,2),%esi
 1126cef:	movzbl -0x6(%r9),%edi
 1126cf4:	mov    %dil,(%rcx,%r14,2)
 1126cf8:	mov    %sil,-0x6(%r9)
 1126cfc:	add    $0x4,%r14
 1126d00:	add    $0xfffffffffffffff8,%r9
 1126d04:	cmp    %r14,%r11
 1126d07:	jne    1126c60 <sort.block.block__anon_39113+0x9140>
 1126d0d:	mov    %r10,%r9
 1126d10:	shr    %r9
 1126d13:	cmp    $0x20,%r10
 1126d17:	setb   %cl
 1126d1a:	cmp    $0xf,%r9
 1126d1e:	sete   %sil
 1126d22:	or     %cl,%sil
 1126d25:	je     1126d30 <sort.block.block__anon_39113+0x9210>
 1126d27:	xor    %r10d,%r10d
 1126d2a:	jmp    1126ebf <sort.block.block__anon_39113+0x939f>
 1126d2f:	nop
 1126d30:	lea    -0x10(%r9),%rcx
 1126d34:	mov    %rcx,%r11
 1126d37:	shr    $0x4,%r11
 1126d3b:	inc    %r11
 1126d3e:	cmp    $0x30,%rcx
 1126d42:	jae    1126d60 <sort.block.block__anon_39113+0x9240>
 1126d44:	xor    %r10d,%r10d
 1126d47:	and    $0x3,%r11d
 1126d4b:	jne    1126e5f <sort.block.block__anon_39113+0x933f>
 1126d51:	jmp    1126ebf <sort.block.block__anon_39113+0x939f>
 1126d56:	cs nopw 0x0(%rax,%rax,1)
 1126d60:	mov    %r11,%rcx
 1126d63:	movabs $0x1ffffffffffffffc,%rsi
 1126d6d:	and    %rsi,%rcx
 1126d70:	mov    -0xc8(%rbp),%rsi
 1126d77:	lea    (%rsi,%rdx,2),%rbx
 1126d7b:	mov    -0x58(%rbp),%rsi
 1126d7f:	lea    (%rsi,%r8,2),%r14
 1126d83:	xor    %r10d,%r10d
 1126d86:	cs nopw 0x0(%rax,%rax,1)
 1126d90:	vmovdqu (%r14,%r10,2),%ymm0
 1126d96:	vmovdqu -0x60(%rbx),%ymm1
 1126d9b:	vpshufb %ymm2,%ymm1,%ymm1
 1126da0:	vpermq $0x4e,%ymm1,%ymm1
 1126da6:	vmovdqu %ymm1,(%r14,%r10,2)
 1126dac:	vpshufb %ymm2,%ymm0,%ymm0
 1126db1:	vpermq $0x4e,%ymm0,%ymm0
 1126db7:	vmovdqu %ymm0,-0x60(%rbx)
 1126dbc:	vmovdqu -0x20(%r14,%r10,2),%ymm0
 1126dc3:	vmovdqu -0x40(%rbx),%ymm1
 1126dc8:	vpshufb %ymm2,%ymm1,%ymm1
 1126dcd:	vpermq $0x4e,%ymm1,%ymm1
 1126dd3:	vmovdqu %ymm1,-0x20(%r14,%r10,2)
 1126dda:	vpshufb %ymm2,%ymm0,%ymm0
 1126ddf:	vpermq $0x4e,%ymm0,%ymm0
 1126de5:	vmovdqu %ymm0,-0x40(%rbx)
 1126dea:	vmovdqu -0x40(%r14,%r10,2),%ymm0
 1126df1:	vmovdqu -0x20(%rbx),%ymm1
 1126df6:	vpshufb %ymm2,%ymm1,%ymm1
 1126dfb:	vpermq $0x4e,%ymm1,%ymm1
 1126e01:	vmovdqu %ymm1,-0x40(%r14,%r10,2)
 1126e08:	vpshufb %ymm2,%ymm0,%ymm0
 1126e0d:	vpermq $0x4e,%ymm0,%ymm0
 1126e13:	vmovdqu %ymm0,-0x20(%rbx)
 1126e18:	vmovdqu -0x60(%r14,%r10,2),%ymm0
 1126e1f:	vmovdqu (%rbx),%ymm1
 1126e23:	vpshufb %ymm2,%ymm1,%ymm1
 1126e28:	vpermq $0x4e,%ymm1,%ymm1
 1126e2e:	vmovdqu %ymm1,-0x60(%r14,%r10,2)
 1126e35:	vpshufb %ymm2,%ymm0,%ymm0
 1126e3a:	vpermq $0x4e,%ymm0,%ymm0
 1126e40:	vmovdqu %ymm0,(%rbx)
 1126e44:	sub    $0xffffffffffffff80,%rbx
 1126e48:	add    $0xffffffffffffffc0,%r10
 1126e4c:	add    $0xfffffffffffffffc,%rcx
 1126e50:	jne    1126d90 <sort.block.block__anon_39113+0x9270>
 1126e56:	neg    %r10
 1126e59:	and    $0x3,%r11d
 1126e5d:	je     1126ebf <sort.block.block__anon_39113+0x939f>
 1126e5f:	mov    -0x58(%rbp),%rcx
 1126e63:	lea    (%rcx,%r8,2),%rbx
 1126e67:	mov    %r10,%rcx
 1126e6a:	neg    %rcx
 1126e6d:	add    %r10,%r10
 1126e70:	lea    (%r10,%rdx,2),%r10
 1126e74:	add    -0x38(%rbp),%r10
 1126e78:	shl    $0x5,%r11d
 1126e7c:	xor    %r14d,%r14d
 1126e7f:	nop
 1126e80:	vmovdqu (%rbx,%rcx,2),%ymm0
 1126e85:	vmovdqu (%r10,%r14,1),%ymm1
 1126e8b:	vpshufb %ymm2,%ymm1,%ymm1
 1126e90:	vpermq $0x4e,%ymm1,%ymm1
 1126e96:	vmovdqu %ymm1,(%rbx,%rcx,2)
 1126e9b:	vpshufb %ymm2,%ymm0,%ymm0
 1126ea0:	vpermq $0x4e,%ymm0,%ymm0
 1126ea6:	vmovdqu %ymm0,(%r10,%r14,1)
 1126eac:	add    $0xfffffffffffffff0,%rcx
 1126eb0:	add    $0x20,%r14
 1126eb4:	cmp    %r14,%r11
 1126eb7:	jne    1126e80 <sort.block.block__anon_39113+0x9360>
 1126eb9:	neg    %rcx
 1126ebc:	mov    %rcx,%r10
 1126ebf:	mov    %r10,%rcx
 1126ec2:	sub    %r9,%rcx
 1126ec5:	jae    1126570 <sort.block.block__anon_39113+0x8a50>
 1126ecb:	mov    %r9d,%r11d
 1126ece:	sub    %r10d,%r11d
 1126ed1:	and    $0x3,%r11d
 1126ed5:	je     1126f33 <sort.block.block__anon_39113+0x9413>
 1126ed7:	lea    (%r10,%r10,1),%rsi
 1126edb:	mov    -0x48(%rbp),%rdi
 1126edf:	lea    (%rdi,%r8,2),%rbx
 1126ee3:	sub    %rsi,%rbx
 1126ee6:	lea    (%rsi,%rdx,2),%r14
 1126eea:	add    -0x50(%rbp),%r14
 1126eee:	neg    %r11
 1126ef1:	xor    %r15d,%r15d
 1126ef4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1126f00:	movzbl -0x1(%r14),%esi
 1126f05:	movzbl -0x1(%rbx,%r15,2),%edi
 1126f0b:	mov    %dil,-0x1(%r14)
 1126f0f:	mov    %sil,-0x1(%rbx,%r15,2)
 1126f14:	movzbl (%r14),%esi
 1126f18:	movzbl (%rbx,%r15,2),%edi
 1126f1d:	mov    %dil,(%r14)
 1126f20:	mov    %sil,(%rbx,%r15,2)
 1126f24:	dec    %r15
 1126f27:	add    $0x2,%r14
 1126f2b:	cmp    %r15,%r11
 1126f2e:	jne    1126f00 <sort.block.block__anon_39113+0x93e0>
 1126f30:	sub    %r15,%r10
 1126f33:	cmp    $0xfffffffffffffffc,%rcx
 1126f37:	ja     1126570 <sort.block.block__anon_39113+0x8a50>
 1126f3d:	mov    -0x80(%rbp),%rcx
 1126f41:	lea    (%rcx,%rdx,2),%rcx
 1126f45:	mov    -0x48(%rbp),%rdi
 1126f49:	lea    (%rdi,%r8,2),%r11
 1126f4d:	sub    %r10,%r11
 1126f50:	sub    %r10,%r11
 1126f53:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1126f60:	movzbl -0x7(%rcx,%r10,2),%esi
 1126f66:	movzbl -0x1(%r11),%edi
 1126f6b:	mov    %dil,-0x7(%rcx,%r10,2)
 1126f70:	mov    %sil,-0x1(%r11)
 1126f74:	movzbl -0x6(%rcx,%r10,2),%esi
 1126f7a:	movzbl (%r11),%edi
 1126f7e:	mov    %dil,-0x6(%rcx,%r10,2)
 1126f83:	mov    %sil,(%r11)
 1126f86:	movzbl -0x5(%rcx,%r10,2),%esi
 1126f8c:	movzbl -0x3(%r11),%edi
 1126f91:	mov    %dil,-0x5(%rcx,%r10,2)
 1126f96:	mov    %sil,-0x3(%r11)
 1126f9a:	movzbl -0x4(%rcx,%r10,2),%esi
 1126fa0:	movzbl -0x2(%r11),%edi
 1126fa5:	mov    %dil,-0x4(%rcx,%r10,2)
 1126faa:	mov    %sil,-0x2(%r11)
 1126fae:	movzbl -0x3(%rcx,%r10,2),%esi
 1126fb4:	movzbl -0x5(%r11),%edi
 1126fb9:	mov    %dil,-0x3(%rcx,%r10,2)
 1126fbe:	mov    %sil,-0x5(%r11)
 1126fc2:	movzbl -0x2(%rcx,%r10,2),%esi
 1126fc8:	movzbl -0x4(%r11),%edi
 1126fcd:	mov    %dil,-0x2(%rcx,%r10,2)
 1126fd2:	mov    %sil,-0x4(%r11)
 1126fd6:	movzbl -0x1(%rcx,%r10,2),%esi
 1126fdc:	movzbl -0x7(%r11),%edi
 1126fe1:	mov    %dil,-0x1(%rcx,%r10,2)
 1126fe6:	mov    %sil,-0x7(%r11)
 1126fea:	movzbl (%rcx,%r10,2),%esi
 1126fef:	movzbl -0x6(%r11),%edi
 1126ff4:	mov    %dil,(%rcx,%r10,2)
 1126ff8:	mov    %sil,-0x6(%r11)
 1126ffc:	add    $0x4,%r10
 1127000:	add    $0xfffffffffffffff8,%r11
 1127004:	cmp    %r10,%r9
 1127007:	jne    1126f60 <sort.block.block__anon_39113+0x9440>
 112700d:	jmp    1126570 <sort.block.block__anon_39113+0x8a50>
 1127012:	mov    %r9,-0xa0(%rbp)
 1127019:	jmp    1120dd6 <sort.block.block__anon_39113+0x32b6>
 112701e:	mov    -0xa8(%rbp),%rax
 1127025:	cmp    %rax,-0x188(%rbp)
 112702c:	jne    112703c <sort.block.block__anon_39113+0x951c>
 112702e:	mov    -0x168(%rbp),%rax
 1127035:	sub    %rax,-0x180(%rbp)
 112703c:	mov    -0xa0(%rbp),%rax
 1127043:	sub    %r9,%rax
 1127046:	mov    %rax,-0xa8(%rbp)
 112704d:	jmp    1120dd6 <sort.block.block__anon_39113+0x32b6>
 1127052:	movzwl 0x2(%rdi),%eax
 1127056:	movzwl (%rdi),%ecx
 1127059:	mov    -0x30(%rbp),%rdx
 112705d:	mov    (%rdx),%rsi
 1127060:	mov    %eax,%edx
 1127062:	shl    $0x4,%edx
 1127065:	mov    (%rsi,%rdx,1),%r8
 1127069:	mov    %ecx,%r10d
 112706c:	shl    $0x4,%r10d
 1127070:	mov    (%rsi,%r10,1),%r9
 1127074:	cmp    %r9,%r8
 1127077:	jne    1127088 <sort.block.block__anon_39113+0x9568>
 1127079:	add    %rsi,%rdx
 112707c:	add    %rsi,%r10
 112707f:	movzwl 0xe(%rdx),%edx
 1127083:	cmp    0xe(%r10),%dx
 1127088:	jae    112716d <sort.block.block__anon_39113+0x964d>
 112708e:	mov    %ecx,%edx
 1127090:	shr    $0x8,%edx
 1127093:	mov    %eax,%esi
 1127095:	shr    $0x8,%esi
 1127098:	mov    %al,(%rdi)
 112709a:	mov    %cl,0x2(%rdi)
 112709d:	mov    %sil,0x1(%rdi)
 11270a1:	mov    %dl,0x3(%rdi)
 11270a4:	jmp    112716d <sort.block.block__anon_39113+0x964d>
 11270a9:	jae    111dba1 <sort.block.block__anon_39113+0x81>
 11270af:	mov    %r8d,%ecx
 11270b2:	shr    $0x8,%ecx
 11270b5:	mov    -0x38(%rbp),%r10
 11270b9:	mov    %sil,(%r10)
 11270bc:	mov    %r8b,0x2(%r10)
 11270c0:	mov    %al,0x1(%r10)
 11270c4:	mov    %cl,0x3(%r10)
 11270c8:	movzwl 0x2(%r10),%ecx
 11270cd:	mov    -0x30(%rbp),%rax
 11270d1:	mov    (%rax),%rdx
 11270d4:	mov    %ecx,%eax
 11270d6:	shl    $0x4,%eax
 11270d9:	mov    (%rdx,%rax,1),%rdi
 11270dd:	mov    %ecx,%eax
 11270df:	shr    $0x8,%eax
 11270e2:	mov    %ecx,%esi
 11270e4:	movzwl 0x4(%r10),%r8d
 11270e9:	mov    %r8d,%r9d
 11270ec:	shl    $0x4,%r9d
 11270f0:	cmp    %rdi,(%rdx,%r9,1)
 11270f4:	jne    1127106 <sort.block.block__anon_39113+0x95e6>
 11270f6:	add    %rdx,%r9
 11270f9:	shl    $0x4,%ecx
 11270fc:	movzwl 0xe(%r9),%edi
 1127101:	cmp    0xe(%rdx,%rcx,1),%di
 1127106:	jae    112716d <sort.block.block__anon_39113+0x964d>
 1127108:	mov    %r8d,%ecx
 112710b:	shr    $0x8,%ecx
 112710e:	mov    %r8b,0x2(%r10)
 1127112:	mov    %sil,0x4(%r10)
 1127116:	mov    %cl,0x3(%r10)
 112711a:	mov    %al,0x5(%r10)
 112711e:	movzwl 0x2(%r10),%eax
 1127123:	movzwl (%r10),%edx
 1127127:	mov    -0x30(%rbp),%rsi
 112712b:	mov    (%rsi),%rdi
 112712e:	mov    %eax,%esi
 1127130:	shl    $0x4,%esi
 1127133:	mov    (%rdi,%rsi,1),%r9
 1127137:	mov    %edx,%r8d
 112713a:	shl    $0x4,%r8d
 112713e:	mov    (%rdi,%r8,1),%r10
 1127142:	cmp    %r10,%r9
 1127145:	jne    1127156 <sort.block.block__anon_39113+0x9636>
 1127147:	add    %rdi,%rsi
 112714a:	add    %rdi,%r8
 112714d:	movzwl 0xe(%rsi),%esi
 1127151:	cmp    0xe(%r8),%si
 1127156:	mov    -0x38(%rbp),%rdi
 112715a:	jae    112716d <sort.block.block__anon_39113+0x964d>
 112715c:	mov    %edx,%esi
 112715e:	shr    $0x8,%esi
 1127161:	mov    %al,(%rdi)
 1127163:	mov    %dl,0x2(%rdi)
 1127166:	mov    %cl,0x1(%rdi)
 1127169:	mov    %sil,0x3(%rdi)
 112716d:	add    $0x628,%rsp
 1127174:	pop    %rbx
 1127175:	pop    %r12
 1127177:	pop    %r13
 1127179:	pop    %r14
 112717b:	pop    %r15
 112717d:	pop    %rbp
 112717e:	vzeroupper 
 1127181:	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_zstd_huffman_wide_x2:

Disassembly of section .vort_zstd_huffman_only_decode:

Disassembly of section .vort_zstd_frr_decode:

Disassembly of section .vort_zstd_zz_frr_pair:

Disassembly of section .vort_zstd_ffr_decode:

Disassembly of section .vort_zstd_raw_fse_decode:

Disassembly of section .vort_zstd_zz_ffr_pair:

Disassembly of section .vort_zstd_split_zz:

Disassembly of section .vort_zstd_split_wide_literal_decode:

Disassembly of section .vort_zstd_split_dense_literal_decode:

Disassembly of section .vort_zstd_split_literal_decode:

Disassembly of section .vort_zstd_zzz_long_match:

Disassembly of section .vort_zstd_zz_fse_mapped:

Disassembly of section .vort_zstd_fse_256:

Disassembly of section .vort_zstd_fse_counts:

Disassembly of section .vort_zstd_huffman_build:

Disassembly of section .vort_zstd_medium_split:

Disassembly of section .vort_zstd_tiny_raw:

Disassembly of section .vort_zstd_small_frame_decode:

Disassembly of section .vort_zstd_small_sequence_decode:

Disassembly of section .vort_zstd_fast_records:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_dense_huffman:

Disassembly of section .vort_zstd_fast_encode:

Disassembly of section .vort_zstd_fast_large:

Disassembly of section .vort_zstd_fast_plan:

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_zz_optimal:

Disassembly of section .vort_zstd_single_beam:

Disassembly of section .plt:
