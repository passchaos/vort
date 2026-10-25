
/home/passchaos/project-z/vort/.zig-cache/o/ed94ec1c4a213c549af1a1d632f56d71/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000111aaa0 <zstd.finalizeSmallHuffmanLiteralPlan>:
 111aaa0:	push   %rbp
 111aaa1:	mov    %rsp,%rbp
 111aaa4:	push   %r15
 111aaa6:	push   %r14
 111aaa8:	push   %r13
 111aaaa:	push   %r12
 111aaac:	push   %rbx
 111aaad:	sub    $0x5c8,%rsp
 111aab4:	mov    (%rdi),%r15
 111aab7:	lea    -0x101(%r15),%rax
 111aabe:	cmp    $0xffffffffffffff00,%rax
 111aac4:	jbe    111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111aaca:	mov    %rdi,%r14
 111aacd:	movb   $0x0,0x908(%rdi)
 111aad4:	lea    -0x1(%r15),%rcx
 111aad8:	mov    %r15d,%eax
 111aadb:	and    $0x7,%eax
 111aade:	cmp    $0x7,%rcx
 111aae2:	jae    111adbe <zstd.finalizeSmallHuffmanLiteralPlan+0x31e>
 111aae8:	xor    %ecx,%ecx
 111aaea:	xor    %edx,%edx
 111aaec:	mov    %ecx,%esi
 111aaee:	test   %rax,%rax
 111aaf1:	je     111ab1e <zstd.finalizeSmallHuffmanLiteralPlan+0x7e>
 111aaf3:	add    %r14,%rdx
 111aaf6:	add    $0x608,%rdx
 111aafd:	xor    %edi,%edi
 111aaff:	nop
 111ab00:	movzbl (%rdx,%rdi,1),%esi
 111ab04:	movzbl %cl,%ecx
 111ab07:	cmp    %sil,%cl
 111ab0a:	cmova  %ecx,%esi
 111ab0d:	mov    %sil,0x908(%r14)
 111ab14:	inc    %rdi
 111ab17:	mov    %esi,%ecx
 111ab19:	cmp    %rdi,%rax
 111ab1c:	jne    111ab00 <zstd.finalizeSmallHuffmanLiteralPlan+0x60>
 111ab1e:	lea    0x608(%r14),%r13
 111ab25:	lea    0x8(%r14),%r12
 111ab29:	cmp    $0x40,%sil
 111ab2d:	jae    111af75 <zstd.finalizeSmallHuffmanLiteralPlan+0x4d5>
 111ab33:	mov    %r13,-0x30(%rbp)
 111ab37:	mov    %r14,-0x38(%rbp)
 111ab3b:	shl    $0x2,%sil
 111ab3f:	movzbl %sil,%edx
 111ab43:	lea    0x4(%rdx),%r13
 111ab47:	lea    (%rdx,%rbp,1),%rdi
 111ab4b:	add    $0xfffffffffffffd64,%rdi
 111ab52:	xor    $0xfc,%rdx
 111ab59:	xor    %r15d,%r15d
 111ab5c:	xor    %esi,%esi
 111ab5e:	call   119d440 <compiler_rt.memset>
 111ab63:	lea    -0x2a0(%rbp),%rdi
 111ab6a:	mov    %r12,%rsi
 111ab6d:	mov    %r13,%rdx
 111ab70:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111ab75:	movb   $0x0,-0x78(%rbp)
 111ab79:	movb   $0x0,-0x77(%rbp)
 111ab7d:	movb   $0x0,-0x76(%rbp)
 111ab81:	movb   $0x0,-0x75(%rbp)
 111ab85:	movb   $0x0,-0x74(%rbp)
 111ab89:	movb   $0x0,-0x73(%rbp)
 111ab8d:	movb   $0x0,-0x72(%rbp)
 111ab91:	movb   $0x0,-0x71(%rbp)
 111ab95:	movb   $0x0,-0x70(%rbp)
 111ab99:	movb   $0x0,-0x6f(%rbp)
 111ab9d:	movb   $0x0,-0x6e(%rbp)
 111aba1:	movb   $0x0,-0x6d(%rbp)
 111aba5:	movb   $0x0,-0x6c(%rbp)
 111aba9:	movb   $0x0,-0x6b(%rbp)
 111abad:	movb   $0x0,-0x6a(%rbp)
 111abb1:	movb   $0x0,-0x69(%rbp)
 111abb5:	movb   $0x0,-0x68(%rbp)
 111abb9:	movb   $0x0,-0x67(%rbp)
 111abbd:	movb   $0x0,-0x66(%rbp)
 111abc1:	movb   $0x0,-0x65(%rbp)
 111abc5:	movb   $0x0,-0x64(%rbp)
 111abc9:	movb   $0x0,-0x63(%rbp)
 111abcd:	movb   $0x0,-0x62(%rbp)
 111abd1:	movb   $0x0,-0x61(%rbp)
 111abd5:	movb   $0x0,-0x60(%rbp)
 111abd9:	movb   $0x0,-0x5f(%rbp)
 111abdd:	movb   $0x0,-0x5e(%rbp)
 111abe1:	movb   $0x0,-0x5d(%rbp)
 111abe5:	movb   $0x0,-0x5c(%rbp)
 111abe9:	movb   $0x0,-0x5b(%rbp)
 111abed:	movb   $0x0,-0x5a(%rbp)
 111abf1:	movb   $0x0,-0x59(%rbp)
 111abf5:	movb   $0x0,-0x58(%rbp)
 111abf9:	movb   $0x0,-0x57(%rbp)
 111abfd:	movb   $0x0,-0x56(%rbp)
 111ac01:	movb   $0x0,-0x55(%rbp)
 111ac05:	movb   $0x0,-0x54(%rbp)
 111ac09:	movb   $0x0,-0x53(%rbp)
 111ac0d:	movb   $0x0,-0x52(%rbp)
 111ac11:	movb   $0x0,-0x51(%rbp)
 111ac15:	movb   $0x0,-0x50(%rbp)
 111ac19:	movb   $0x0,-0x4f(%rbp)
 111ac1d:	movb   $0x0,-0x4e(%rbp)
 111ac21:	movb   $0x0,-0x4d(%rbp)
 111ac25:	movb   $0x0,-0x4c(%rbp)
 111ac29:	movb   $0x0,-0x4b(%rbp)
 111ac2d:	movb   $0x0,-0x4a(%rbp)
 111ac31:	movb   $0x0,-0x49(%rbp)
 111ac35:	movb   $0x0,-0x48(%rbp)
 111ac39:	movb   $0x0,-0x47(%rbp)
 111ac3d:	movb   $0x0,-0x46(%rbp)
 111ac41:	movb   $0x0,-0x45(%rbp)
 111ac45:	movb   $0x0,-0x44(%rbp)
 111ac49:	movb   $0x0,-0x43(%rbp)
 111ac4d:	movb   $0x0,-0x42(%rbp)
 111ac51:	movb   $0x0,-0x41(%rbp)
 111ac55:	movb   $0x0,-0x40(%rbp)
 111ac59:	movb   $0x0,-0x3f(%rbp)
 111ac5d:	movb   $0x0,-0x3e(%rbp)
 111ac61:	movb   $0x0,-0x3d(%rbp)
 111ac65:	movb   $0x0,-0x3c(%rbp)
 111ac69:	movb   $0x0,-0x3b(%rbp)
 111ac6d:	movb   $0x0,-0x3a(%rbp)
 111ac71:	movb   $0x0,-0x39(%rbp)
 111ac75:	vmovups -0x1c0(%rbp),%ymm0
 111ac7d:	vmovups %ymm0,-0x410(%rbp)
 111ac85:	vmovups -0x1e0(%rbp),%ymm0
 111ac8d:	vmovups %ymm0,-0x430(%rbp)
 111ac95:	vmovups -0x200(%rbp),%ymm0
 111ac9d:	vmovups %ymm0,-0x450(%rbp)
 111aca5:	vmovups -0x220(%rbp),%ymm0
 111acad:	vmovups %ymm0,-0x470(%rbp)
 111acb5:	vmovups -0x2a0(%rbp),%ymm0
 111acbd:	vmovups -0x260(%rbp),%ymm1
 111acc5:	vmovups -0x240(%rbp),%ymm2
 111accd:	vmovups %ymm2,-0x490(%rbp)
 111acd5:	vmovups %ymm1,-0x4b0(%rbp)
 111acdd:	vmovups -0x280(%rbp),%ymm1
 111ace5:	vmovups %ymm1,-0x4d0(%rbp)
 111aced:	vmovups %ymm0,-0x4f0(%rbp)
 111acf5:	mov    $0x7,%eax
 111acfa:	nopw   0x0(%rax,%rax,1)
 111ad00:	mov    %r15,%rcx
 111ad03:	mov    -0x50c(%rbp,%rax,4),%edi
 111ad0a:	mov    -0x508(%rbp,%rax,4),%esi
 111ad11:	cmp    $0x1,%edi
 111ad14:	sbb    $0xffffffffffffffff,%r15
 111ad18:	cmp    $0x1,%esi
 111ad1b:	sbb    $0xffffffffffffffff,%r15
 111ad1f:	mov    -0x504(%rbp,%rax,4),%r8d
 111ad27:	cmp    $0x1,%r8d
 111ad2b:	sbb    $0xffffffffffffffff,%r15
 111ad2f:	mov    -0x500(%rbp,%rax,4),%r9d
 111ad37:	cmp    $0x1,%r9d
 111ad3b:	sbb    $0xffffffffffffffff,%r15
 111ad3f:	mov    -0x4fc(%rbp,%rax,4),%r13d
 111ad47:	cmp    $0x1,%r13d
 111ad4b:	sbb    $0xffffffffffffffff,%r15
 111ad4f:	mov    -0x4f8(%rbp,%rax,4),%r14d
 111ad57:	cmp    $0x1,%r14d
 111ad5b:	sbb    $0xffffffffffffffff,%r15
 111ad5f:	mov    -0x4f4(%rbp,%rax,4),%r12d
 111ad67:	cmp    $0x1,%r12d
 111ad6b:	sbb    $0xffffffffffffffff,%r15
 111ad6f:	mov    -0x4f0(%rbp,%rax,4),%ebx
 111ad76:	cmp    $0x1,%ebx
 111ad79:	sbb    $0xffffffffffffffff,%r15
 111ad7d:	add    $0x8,%rax
 111ad81:	cmp    $0x47,%rax
 111ad85:	jne    111ad00 <zstd.finalizeSmallHuffmanLiteralPlan+0x260>
 111ad8b:	cmp    $0x1,%r15
 111ad8f:	je     111af96 <zstd.finalizeSmallHuffmanLiteralPlan+0x4f6>
 111ad95:	test   %r15,%r15
 111ad98:	jne    111afb4 <zstd.finalizeSmallHuffmanLiteralPlan+0x514>
 111ad9e:	vxorps %xmm0,%xmm0,%xmm0
 111ada2:	vmovups %ymm0,-0x180(%rbp)
 111adaa:	vmovups %ymm0,-0x1a0(%rbp)
 111adb2:	lea    -0x1a0(%rbp),%r12
 111adb9:	jmp    111b414 <zstd.finalizeSmallHuffmanLiteralPlan+0x974>
 111adbe:	mov    %r15d,%esi
 111adc1:	and    $0x1f8,%esi
 111adc7:	xor    %edi,%edi
 111adc9:	xor    %edx,%edx
 111adcb:	jmp    111ade6 <zstd.finalizeSmallHuffmanLiteralPlan+0x346>
 111adcd:	nopl   (%rax)
 111add0:	mov    %cl,0x908(%r14)
 111add7:	add    $0x8,%rdx
 111addb:	mov    %ecx,%edi
 111addd:	cmp    %rdx,%rsi
 111ade0:	je     111aaec <zstd.finalizeSmallHuffmanLiteralPlan+0x4c>
 111ade6:	mov    0x608(%r14,%rdx,1),%ecx
 111adee:	cmp    %cl,%dil
 111adf1:	ja     111aeb0 <zstd.finalizeSmallHuffmanLiteralPlan+0x410>
 111adf7:	mov    %cl,0x908(%r14)
 111adfe:	movzbl 0x609(%r14,%rdx,1),%edi
 111ae07:	cmp    %dil,%cl
 111ae0a:	jbe    111aecd <zstd.finalizeSmallHuffmanLiteralPlan+0x42d>
 111ae10:	mov    %cl,0x908(%r14)
 111ae17:	movzbl 0x60a(%r14,%rdx,1),%edi
 111ae20:	cmp    %dil,%cl
 111ae23:	jbe    111aee8 <zstd.finalizeSmallHuffmanLiteralPlan+0x448>
 111ae29:	mov    %cl,0x908(%r14)
 111ae30:	movzbl 0x60b(%r14,%rdx,1),%edi
 111ae39:	cmp    %dil,%cl
 111ae3c:	jbe    111af03 <zstd.finalizeSmallHuffmanLiteralPlan+0x463>
 111ae42:	mov    %cl,0x908(%r14)
 111ae49:	mov    0x60c(%r14,%rdx,1),%edi
 111ae51:	cmp    %dil,%cl
 111ae54:	jbe    111af1d <zstd.finalizeSmallHuffmanLiteralPlan+0x47d>
 111ae5a:	mov    %cl,0x908(%r14)
 111ae61:	movzbl 0x60d(%r14,%rdx,1),%edi
 111ae6a:	cmp    %dil,%cl
 111ae6d:	jbe    111af38 <zstd.finalizeSmallHuffmanLiteralPlan+0x498>
 111ae73:	mov    %cl,0x908(%r14)
 111ae7a:	movzbl 0x60e(%r14,%rdx,1),%edi
 111ae83:	cmp    %dil,%cl
 111ae86:	jbe    111af53 <zstd.finalizeSmallHuffmanLiteralPlan+0x4b3>
 111ae8c:	mov    %cl,0x908(%r14)
 111ae93:	movzbl 0x60f(%r14,%rdx,1),%edi
 111ae9c:	cmp    %dil,%cl
 111ae9f:	ja     111add0 <zstd.finalizeSmallHuffmanLiteralPlan+0x330>
 111aea5:	jmp    111af6e <zstd.finalizeSmallHuffmanLiteralPlan+0x4ce>
 111aeaa:	nopw   0x0(%rax,%rax,1)
 111aeb0:	movzbl %dil,%ecx
 111aeb4:	mov    %cl,0x908(%r14)
 111aebb:	movzbl 0x609(%r14,%rdx,1),%edi
 111aec4:	cmp    %dil,%cl
 111aec7:	ja     111ae10 <zstd.finalizeSmallHuffmanLiteralPlan+0x370>
 111aecd:	mov    %edi,%ecx
 111aecf:	mov    %cl,0x908(%r14)
 111aed6:	movzbl 0x60a(%r14,%rdx,1),%edi
 111aedf:	cmp    %dil,%cl
 111aee2:	ja     111ae29 <zstd.finalizeSmallHuffmanLiteralPlan+0x389>
 111aee8:	mov    %edi,%ecx
 111aeea:	mov    %cl,0x908(%r14)
 111aef1:	movzbl 0x60b(%r14,%rdx,1),%edi
 111aefa:	cmp    %dil,%cl
 111aefd:	ja     111ae42 <zstd.finalizeSmallHuffmanLiteralPlan+0x3a2>
 111af03:	mov    %edi,%ecx
 111af05:	mov    %cl,0x908(%r14)
 111af0c:	mov    0x60c(%r14,%rdx,1),%edi
 111af14:	cmp    %dil,%cl
 111af17:	ja     111ae5a <zstd.finalizeSmallHuffmanLiteralPlan+0x3ba>
 111af1d:	mov    %edi,%ecx
 111af1f:	mov    %cl,0x908(%r14)
 111af26:	movzbl 0x60d(%r14,%rdx,1),%edi
 111af2f:	cmp    %dil,%cl
 111af32:	ja     111ae73 <zstd.finalizeSmallHuffmanLiteralPlan+0x3d3>
 111af38:	mov    %edi,%ecx
 111af3a:	mov    %cl,0x908(%r14)
 111af41:	movzbl 0x60e(%r14,%rdx,1),%edi
 111af4a:	cmp    %dil,%cl
 111af4d:	ja     111ae8c <zstd.finalizeSmallHuffmanLiteralPlan+0x3ec>
 111af53:	mov    %edi,%ecx
 111af55:	mov    %cl,0x908(%r14)
 111af5c:	movzbl 0x60f(%r14,%rdx,1),%edi
 111af65:	cmp    %dil,%cl
 111af68:	ja     111add0 <zstd.finalizeSmallHuffmanLiteralPlan+0x330>
 111af6e:	mov    %edi,%ecx
 111af70:	jmp    111add0 <zstd.finalizeSmallHuffmanLiteralPlan+0x330>
 111af75:	lea    -0x5f0(%rbp),%rdi
 111af7c:	mov    %r12,%rsi
 111af7f:	mov    %r13,%rdx
 111af82:	mov    %r15,%rcx
 111af85:	call   111c260 <huffman.treeCodeLengthsKnownActive__anon_38967>
 111af8a:	movb   $0x0,-0x300(%rbp)
 111af91:	jmp    111b76b <zstd.finalizeSmallHuffmanLiteralPlan+0xccb>
 111af96:	cmpl   $0x0,-0x2a0(%rbp)
 111af9d:	je     111b240 <zstd.finalizeSmallHuffmanLiteralPlan+0x7a0>
 111afa3:	lea    -0x78(%rbp),%rax
 111afa7:	mov    -0x38(%rbp),%r14
 111afab:	mov    -0x30(%rbp),%r13
 111afaf:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>
 111afb4:	cmp    $0x21,%r15
 111afb8:	jae    111b100 <zstd.finalizeSmallHuffmanLiteralPlan+0x660>
 111afbe:	mov    %rcx,-0xa0(%rbp)
 111afc5:	vxorps %xmm0,%xmm0,%xmm0
 111afc9:	vmovups %ymm0,-0x350(%rbp)
 111afd1:	vmovups %ymm0,-0x370(%rbp)
 111afd9:	vmovups %ymm0,-0x390(%rbp)
 111afe1:	vmovups %ymm0,-0x3b0(%rbp)
 111afe9:	vmovups -0x2a0(%rbp),%ymm0
 111aff1:	vmovups -0x280(%rbp),%ymm1
 111aff9:	vmovups -0x260(%rbp),%ymm2
 111b001:	vmovups %ymm0,-0x1a0(%rbp)
 111b009:	vmovups %ymm1,-0x180(%rbp)
 111b011:	vmovups %ymm2,-0x160(%rbp)
 111b019:	vmovups -0x240(%rbp),%ymm0
 111b021:	vmovups %ymm0,-0x140(%rbp)
 111b029:	vmovups -0x220(%rbp),%ymm0
 111b031:	vmovups %ymm0,-0x120(%rbp)
 111b039:	vmovups -0x200(%rbp),%ymm0
 111b041:	vmovups %ymm0,-0x100(%rbp)
 111b049:	vmovups -0x1e0(%rbp),%ymm0
 111b051:	vmovups %ymm0,-0xe0(%rbp)
 111b059:	vmovups -0x1c0(%rbp),%ymm0
 111b061:	vmovups %ymm0,-0xc0(%rbp)
 111b069:	xor    %eax,%eax
 111b06b:	xor    %ecx,%ecx
 111b06d:	jmp    111b07e <zstd.finalizeSmallHuffmanLiteralPlan+0x5de>
 111b06f:	nop
 111b070:	add    $0x4,%rcx
 111b074:	cmp    $0x40,%rcx
 111b078:	je     111b121 <zstd.finalizeSmallHuffmanLiteralPlan+0x681>
 111b07e:	mov    -0x1a0(%rbp,%rcx,4),%edx
 111b085:	test   %edx,%edx
 111b087:	je     111b09b <zstd.finalizeSmallHuffmanLiteralPlan+0x5fb>
 111b089:	mov    %edx,-0x3b0(%rbp,%rax,4)
 111b090:	mov    %cx,-0x3f0(%rbp,%rax,2)
 111b098:	inc    %rax
 111b09b:	mov    -0x19c(%rbp,%rcx,4),%edx
 111b0a2:	test   %edx,%edx
 111b0a4:	je     111b0bb <zstd.finalizeSmallHuffmanLiteralPlan+0x61b>
 111b0a6:	mov    %edx,-0x3b0(%rbp,%rax,4)
 111b0ad:	lea    0x1(%rcx),%edx
 111b0b0:	mov    %dx,-0x3f0(%rbp,%rax,2)
 111b0b8:	inc    %rax
 111b0bb:	mov    -0x198(%rbp,%rcx,4),%edx
 111b0c2:	test   %edx,%edx
 111b0c4:	je     111b0db <zstd.finalizeSmallHuffmanLiteralPlan+0x63b>
 111b0c6:	mov    %edx,-0x3b0(%rbp,%rax,4)
 111b0cd:	lea    0x2(%rcx),%edx
 111b0d0:	mov    %dx,-0x3f0(%rbp,%rax,2)
 111b0d8:	inc    %rax
 111b0db:	mov    -0x194(%rbp,%rcx,4),%edx
 111b0e2:	test   %edx,%edx
 111b0e4:	je     111b070 <zstd.finalizeSmallHuffmanLiteralPlan+0x5d0>
 111b0e6:	mov    %edx,-0x3b0(%rbp,%rax,4)
 111b0ed:	lea    0x3(%rcx),%edx
 111b0f0:	mov    %dx,-0x3f0(%rbp,%rax,2)
 111b0f8:	inc    %rax
 111b0fb:	jmp    111b070 <zstd.finalizeSmallHuffmanLiteralPlan+0x5d0>
 111b100:	lea    -0x1a0(%rbp),%r12
 111b107:	lea    -0x2a0(%rbp),%rsi
 111b10e:	mov    %r12,%rdi
 111b111:	mov    %r15,%rdx
 111b114:	vzeroupper 
 111b117:	call   111d4e0 <huffman.packageMergeCodeLengths__anon_39019>
 111b11c:	jmp    111b414 <zstd.finalizeSmallHuffmanLiteralPlan+0x974>
 111b121:	xor    %eax,%eax
 111b123:	test   %ebx,%ebx
 111b125:	setne  %al
 111b128:	mov    %rax,-0x328(%rbp)
 111b12f:	xor    %eax,%eax
 111b131:	test   %r12d,%r12d
 111b134:	setne  %al
 111b137:	mov    %rax,-0x330(%rbp)
 111b13e:	xor    %eax,%eax
 111b140:	test   %r14d,%r14d
 111b143:	setne  %al
 111b146:	mov    %rax,-0x320(%rbp)
 111b14d:	xor    %eax,%eax
 111b14f:	test   %r13d,%r13d
 111b152:	setne  %al
 111b155:	mov    %rax,-0x318(%rbp)
 111b15c:	xor    %eax,%eax
 111b15e:	mov    %r9d,-0x84(%rbp)
 111b165:	test   %r9d,%r9d
 111b168:	setne  %al
 111b16b:	mov    %rax,-0x98(%rbp)
 111b172:	xor    %eax,%eax
 111b174:	mov    %r8d,-0x88(%rbp)
 111b17b:	test   %r8d,%r8d
 111b17e:	setne  %al
 111b181:	mov    %rax,-0x310(%rbp)
 111b188:	xor    %eax,%eax
 111b18a:	mov    %esi,-0x80(%rbp)
 111b18d:	test   %esi,%esi
 111b18f:	setne  %al
 111b192:	mov    %rax,-0x308(%rbp)
 111b199:	xor    %eax,%eax
 111b19b:	mov    %edi,-0x7c(%rbp)
 111b19e:	test   %edi,%edi
 111b1a0:	setne  %al
 111b1a3:	mov    %rax,-0x90(%rbp)
 111b1aa:	lea    -0x2c0(%rbp),%rdi
 111b1b1:	lea    -0x3b0(%rbp),%rsi
 111b1b8:	mov    %r15,%rdx
 111b1bb:	vzeroupper 
 111b1be:	call   1130280 <huffman.packageMergeCodeLengths__anon_39186>
 111b1c3:	mov    -0x308(%rbp),%r11
 111b1ca:	mov    -0x98(%rbp),%rdi
 111b1d1:	mov    -0x310(%rbp),%r9
 111b1d8:	mov    -0x318(%rbp),%rsi
 111b1df:	mov    -0x320(%rbp),%rdx
 111b1e6:	mov    -0x328(%rbp),%r8
 111b1ed:	vxorps %xmm0,%xmm0,%xmm0
 111b1f1:	vmovups %ymm0,-0x2e0(%rbp)
 111b1f9:	vmovups %ymm0,-0x300(%rbp)
 111b201:	mov    -0xa0(%rbp),%r10
 111b208:	mov    -0x90(%rbp),%rax
 111b20f:	add    %r10,%rax
 111b212:	lea    (%r11,%r9,1),%rcx
 111b216:	add    %rax,%rcx
 111b219:	lea    (%rdi,%rsi,1),%rax
 111b21d:	add    %rdx,%rax
 111b220:	add    %rcx,%rax
 111b223:	mov    -0x330(%rbp),%rcx
 111b22a:	add    %rcx,%rax
 111b22d:	add    %r8,%rax
 111b230:	dec    %rax
 111b233:	cmp    $0x7,%rax
 111b237:	jae    111b25e <zstd.finalizeSmallHuffmanLiteralPlan+0x7be>
 111b239:	xor    %eax,%eax
 111b23b:	jmp    111b36f <zstd.finalizeSmallHuffmanLiteralPlan+0x8cf>
 111b240:	cmpl   $0x0,-0x29c(%rbp)
 111b247:	mov    -0x38(%rbp),%r14
 111b24b:	mov    -0x30(%rbp),%r13
 111b24f:	je     111b421 <zstd.finalizeSmallHuffmanLiteralPlan+0x981>
 111b255:	lea    -0x77(%rbp),%rax
 111b259:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>
 111b25e:	mov    -0x90(%rbp),%rdi
 111b265:	add    %r10d,%edi
 111b268:	add    %r11d,%r9d
 111b26b:	add    %edi,%r9d
 111b26e:	add    -0x98(%rbp),%esi
 111b274:	add    %esi,%edx
 111b276:	add    %r9d,%edx
 111b279:	add    %ecx,%r8d
 111b27c:	add    %edx,%r8d
 111b27f:	and    $0x38,%r8d
 111b283:	xor    %eax,%eax
 111b285:	data16 cs nopw 0x0(%rax,%rax,1)
 111b290:	movzwl -0x3f0(%rbp,%rax,2),%ecx
 111b298:	movzbl -0x2c0(%rbp,%rax,1),%edx
 111b2a0:	movzbl -0x2bf(%rbp,%rax,1),%esi
 111b2a8:	and    $0xf,%dl
 111b2ab:	mov    %dl,-0x300(%rbp,%rcx,1)
 111b2b2:	movzwl -0x3ee(%rbp,%rax,2),%ecx
 111b2ba:	and    $0xf,%sil
 111b2be:	mov    %sil,-0x300(%rbp,%rcx,1)
 111b2c6:	movzwl -0x3ec(%rbp,%rax,2),%ecx
 111b2ce:	movzbl -0x2be(%rbp,%rax,1),%edx
 111b2d6:	and    $0xf,%dl
 111b2d9:	mov    %dl,-0x300(%rbp,%rcx,1)
 111b2e0:	movzwl -0x3ea(%rbp,%rax,2),%ecx
 111b2e8:	movzbl -0x2bd(%rbp,%rax,1),%edx
 111b2f0:	and    $0xf,%dl
 111b2f3:	mov    %dl,-0x300(%rbp,%rcx,1)
 111b2fa:	movzwl -0x3e8(%rbp,%rax,2),%ecx
 111b302:	movzbl -0x2bc(%rbp,%rax,1),%edx
 111b30a:	and    $0xf,%dl
 111b30d:	mov    %dl,-0x300(%rbp,%rcx,1)
 111b314:	movzwl -0x3e6(%rbp,%rax,2),%ecx
 111b31c:	movzbl -0x2bb(%rbp,%rax,1),%edx
 111b324:	and    $0xf,%dl
 111b327:	mov    %dl,-0x300(%rbp,%rcx,1)
 111b32e:	movzwl -0x3e4(%rbp,%rax,2),%ecx
 111b336:	movzbl -0x2ba(%rbp,%rax,1),%edx
 111b33e:	and    $0xf,%dl
 111b341:	mov    %dl,-0x300(%rbp,%rcx,1)
 111b348:	movzwl -0x3e2(%rbp,%rax,2),%ecx
 111b350:	movzbl -0x2b9(%rbp,%rax,1),%edx
 111b358:	and    $0xf,%dl
 111b35b:	mov    %dl,-0x300(%rbp,%rcx,1)
 111b362:	add    $0x8,%rax
 111b366:	cmp    %rax,%r8
 111b369:	jne    111b290 <zstd.finalizeSmallHuffmanLiteralPlan+0x7f0>
 111b36f:	test   $0x7,%r15b
 111b373:	mov    -0x88(%rbp),%esi
 111b379:	mov    -0x84(%rbp),%r8d
 111b380:	je     111b40d <zstd.finalizeSmallHuffmanLiteralPlan+0x96d>
 111b386:	cmpl   $0x0,-0x7c(%rbp)
 111b38a:	setne  %dl
 111b38d:	lea    (%rax,%rbp,1),%rcx
 111b391:	add    $0xfffffffffffffd40,%rcx
 111b398:	lea    -0x3f0(,%rax,2),%rax
 111b3a0:	add    %rbp,%rax
 111b3a3:	cmpl   $0x1,-0x80(%rbp)
 111b3a7:	sbb    $0xff,%dl
 111b3aa:	cmp    $0x1,%esi
 111b3ad:	sbb    $0xff,%dl
 111b3b0:	cmp    $0x1,%r8d
 111b3b4:	sbb    $0xff,%dl
 111b3b7:	cmp    $0x1,%r13d
 111b3bb:	sbb    $0xff,%dl
 111b3be:	cmp    $0x1,%r14d
 111b3c2:	sbb    $0xff,%dl
 111b3c5:	cmp    $0x1,%r12d
 111b3c9:	sbb    $0xff,%dl
 111b3cc:	cmp    $0x1,%ebx
 111b3cf:	sbb    $0xff,%dl
 111b3d2:	mov    -0xa0(%rbp),%rsi
 111b3d9:	add    %dl,%sil
 111b3dc:	movzbl %sil,%edx
 111b3e0:	and    $0x7,%edx
 111b3e3:	xor    %esi,%esi
 111b3e5:	data16 cs nopw 0x0(%rax,%rax,1)
 111b3f0:	movzwl (%rax,%rsi,2),%edi
 111b3f4:	movzbl (%rcx,%rsi,1),%r8d
 111b3f9:	and    $0xf,%r8b
 111b3fd:	mov    %r8b,-0x300(%rbp,%rdi,1)
 111b405:	inc    %rsi
 111b408:	cmp    %rsi,%rdx
 111b40b:	jne    111b3f0 <zstd.finalizeSmallHuffmanLiteralPlan+0x950>
 111b40d:	lea    -0x300(%rbp),%r12
 111b414:	mov    -0x38(%rbp),%r14
 111b418:	mov    -0x30(%rbp),%r13
 111b41c:	jmp    111b707 <zstd.finalizeSmallHuffmanLiteralPlan+0xc67>
 111b421:	cmpl   $0x0,-0x298(%rbp)
 111b428:	je     111b430 <zstd.finalizeSmallHuffmanLiteralPlan+0x990>
 111b42a:	lea    -0x76(%rbp),%rax
 111b42e:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>
 111b430:	cmpl   $0x0,-0x294(%rbp)
 111b437:	je     111b43f <zstd.finalizeSmallHuffmanLiteralPlan+0x99f>
 111b439:	lea    -0x75(%rbp),%rax
 111b43d:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>
 111b43f:	cmpl   $0x0,-0x290(%rbp)
 111b446:	je     111b44e <zstd.finalizeSmallHuffmanLiteralPlan+0x9ae>
 111b448:	lea    -0x74(%rbp),%rax
 111b44c:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>
 111b44e:	cmpl   $0x0,-0x28c(%rbp)
 111b455:	je     111b45d <zstd.finalizeSmallHuffmanLiteralPlan+0x9bd>
 111b457:	lea    -0x73(%rbp),%rax
 111b45b:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>
 111b45d:	cmpl   $0x0,-0x288(%rbp)
 111b464:	je     111b46c <zstd.finalizeSmallHuffmanLiteralPlan+0x9cc>
 111b466:	lea    -0x72(%rbp),%rax
 111b46a:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>
 111b46c:	cmpl   $0x0,-0x284(%rbp)
 111b473:	je     111be55 <zstd.finalizeSmallHuffmanLiteralPlan+0x13b5>
 111b479:	lea    -0x71(%rbp),%rax
 111b47d:	movb   $0x1,(%rax)
 111b480:	movzbl -0x78(%rbp),%eax
 111b484:	mov    %al,-0x1a0(%rbp)
 111b48a:	movzbl -0x77(%rbp),%eax
 111b48e:	mov    %al,-0x19f(%rbp)
 111b494:	movzbl -0x76(%rbp),%eax
 111b498:	mov    %al,-0x19e(%rbp)
 111b49e:	movzbl -0x75(%rbp),%eax
 111b4a2:	mov    %al,-0x19d(%rbp)
 111b4a8:	movzbl -0x74(%rbp),%eax
 111b4ac:	mov    %al,-0x19c(%rbp)
 111b4b2:	movzbl -0x73(%rbp),%eax
 111b4b6:	mov    %al,-0x19b(%rbp)
 111b4bc:	movzbl -0x72(%rbp),%eax
 111b4c0:	mov    %al,-0x19a(%rbp)
 111b4c6:	movzbl -0x71(%rbp),%eax
 111b4ca:	mov    %al,-0x199(%rbp)
 111b4d0:	movzbl -0x70(%rbp),%eax
 111b4d4:	mov    %al,-0x198(%rbp)
 111b4da:	movzbl -0x6f(%rbp),%eax
 111b4de:	mov    %al,-0x197(%rbp)
 111b4e4:	movzbl -0x6e(%rbp),%eax
 111b4e8:	mov    %al,-0x196(%rbp)
 111b4ee:	movzbl -0x6d(%rbp),%eax
 111b4f2:	mov    %al,-0x195(%rbp)
 111b4f8:	movzbl -0x6c(%rbp),%eax
 111b4fc:	mov    %al,-0x194(%rbp)
 111b502:	movzbl -0x6b(%rbp),%eax
 111b506:	mov    %al,-0x193(%rbp)
 111b50c:	movzbl -0x6a(%rbp),%eax
 111b510:	mov    %al,-0x192(%rbp)
 111b516:	movzbl -0x69(%rbp),%eax
 111b51a:	mov    %al,-0x191(%rbp)
 111b520:	movzbl -0x68(%rbp),%eax
 111b524:	mov    %al,-0x190(%rbp)
 111b52a:	movzbl -0x67(%rbp),%eax
 111b52e:	mov    %al,-0x18f(%rbp)
 111b534:	movzbl -0x66(%rbp),%eax
 111b538:	mov    %al,-0x18e(%rbp)
 111b53e:	movzbl -0x65(%rbp),%eax
 111b542:	mov    %al,-0x18d(%rbp)
 111b548:	movzbl -0x64(%rbp),%eax
 111b54c:	mov    %al,-0x18c(%rbp)
 111b552:	movzbl -0x63(%rbp),%eax
 111b556:	mov    %al,-0x18b(%rbp)
 111b55c:	movzbl -0x62(%rbp),%eax
 111b560:	mov    %al,-0x18a(%rbp)
 111b566:	movzbl -0x61(%rbp),%eax
 111b56a:	mov    %al,-0x189(%rbp)
 111b570:	movzbl -0x60(%rbp),%eax
 111b574:	mov    %al,-0x188(%rbp)
 111b57a:	movzbl -0x5f(%rbp),%eax
 111b57e:	mov    %al,-0x187(%rbp)
 111b584:	movzbl -0x5e(%rbp),%eax
 111b588:	mov    %al,-0x186(%rbp)
 111b58e:	movzbl -0x5d(%rbp),%eax
 111b592:	mov    %al,-0x185(%rbp)
 111b598:	movzbl -0x5c(%rbp),%eax
 111b59c:	mov    %al,-0x184(%rbp)
 111b5a2:	movzbl -0x5b(%rbp),%eax
 111b5a6:	mov    %al,-0x183(%rbp)
 111b5ac:	movzbl -0x5a(%rbp),%eax
 111b5b0:	mov    %al,-0x182(%rbp)
 111b5b6:	movzbl -0x59(%rbp),%eax
 111b5ba:	mov    %al,-0x181(%rbp)
 111b5c0:	movzbl -0x58(%rbp),%eax
 111b5c4:	mov    %al,-0x180(%rbp)
 111b5ca:	movzbl -0x57(%rbp),%eax
 111b5ce:	mov    %al,-0x17f(%rbp)
 111b5d4:	movzbl -0x56(%rbp),%eax
 111b5d8:	mov    %al,-0x17e(%rbp)
 111b5de:	movzbl -0x55(%rbp),%eax
 111b5e2:	mov    %al,-0x17d(%rbp)
 111b5e8:	movzbl -0x54(%rbp),%eax
 111b5ec:	mov    %al,-0x17c(%rbp)
 111b5f2:	movzbl -0x53(%rbp),%eax
 111b5f6:	mov    %al,-0x17b(%rbp)
 111b5fc:	movzbl -0x52(%rbp),%eax
 111b600:	mov    %al,-0x17a(%rbp)
 111b606:	movzbl -0x51(%rbp),%eax
 111b60a:	mov    %al,-0x179(%rbp)
 111b610:	movzbl -0x50(%rbp),%eax
 111b614:	mov    %al,-0x178(%rbp)
 111b61a:	movzbl -0x4f(%rbp),%eax
 111b61e:	mov    %al,-0x177(%rbp)
 111b624:	movzbl -0x4e(%rbp),%eax
 111b628:	mov    %al,-0x176(%rbp)
 111b62e:	movzbl -0x4d(%rbp),%eax
 111b632:	mov    %al,-0x175(%rbp)
 111b638:	movzbl -0x4c(%rbp),%eax
 111b63c:	mov    %al,-0x174(%rbp)
 111b642:	movzbl -0x4b(%rbp),%eax
 111b646:	mov    %al,-0x173(%rbp)
 111b64c:	movzbl -0x4a(%rbp),%eax
 111b650:	mov    %al,-0x172(%rbp)
 111b656:	movzbl -0x49(%rbp),%eax
 111b65a:	mov    %al,-0x171(%rbp)
 111b660:	movzbl -0x48(%rbp),%eax
 111b664:	mov    %al,-0x170(%rbp)
 111b66a:	movzbl -0x47(%rbp),%eax
 111b66e:	mov    %al,-0x16f(%rbp)
 111b674:	movzbl -0x46(%rbp),%eax
 111b678:	mov    %al,-0x16e(%rbp)
 111b67e:	movzbl -0x45(%rbp),%eax
 111b682:	mov    %al,-0x16d(%rbp)
 111b688:	movzbl -0x44(%rbp),%eax
 111b68c:	mov    %al,-0x16c(%rbp)
 111b692:	movzbl -0x43(%rbp),%eax
 111b696:	mov    %al,-0x16b(%rbp)
 111b69c:	movzbl -0x42(%rbp),%eax
 111b6a0:	mov    %al,-0x16a(%rbp)
 111b6a6:	movzbl -0x41(%rbp),%eax
 111b6aa:	mov    %al,-0x169(%rbp)
 111b6b0:	movzbl -0x40(%rbp),%eax
 111b6b4:	mov    %al,-0x168(%rbp)
 111b6ba:	movzbl -0x3f(%rbp),%eax
 111b6be:	mov    %al,-0x167(%rbp)
 111b6c4:	movzbl -0x3e(%rbp),%eax
 111b6c8:	mov    %al,-0x166(%rbp)
 111b6ce:	movzbl -0x3d(%rbp),%eax
 111b6d2:	mov    %al,-0x165(%rbp)
 111b6d8:	movzbl -0x3c(%rbp),%eax
 111b6dc:	mov    %al,-0x164(%rbp)
 111b6e2:	movzbl -0x3b(%rbp),%eax
 111b6e6:	mov    %al,-0x163(%rbp)
 111b6ec:	movzbl -0x3a(%rbp),%eax
 111b6f0:	mov    %al,-0x162(%rbp)
 111b6f6:	movzbl -0x39(%rbp),%eax
 111b6fa:	mov    %al,-0x161(%rbp)
 111b700:	lea    -0x1a0(%rbp),%r12
 111b707:	vmovups (%r12),%ymm0
 111b70d:	vmovups 0x20(%r12),%ymm1
 111b714:	vmovups %ymm1,-0x5d0(%rbp)
 111b71c:	vmovups %ymm0,-0x5f0(%rbp)
 111b724:	vxorps %xmm0,%xmm0,%xmm0
 111b728:	vmovups %ymm0,-0x510(%rbp)
 111b730:	vmovups %ymm0,-0x530(%rbp)
 111b738:	vmovups %ymm0,-0x550(%rbp)
 111b740:	vmovups %ymm0,-0x570(%rbp)
 111b748:	vmovups %ymm0,-0x590(%rbp)
 111b750:	vmovups %ymm0,-0x5b0(%rbp)
 111b758:	mov    (%r14),%r15
 111b75b:	movb   $0x0,-0x300(%rbp)
 111b762:	test   %r15,%r15
 111b765:	je     111b8c1 <zstd.finalizeSmallHuffmanLiteralPlan+0xe21>
 111b76b:	xor    %eax,%eax
 111b76d:	nopl   (%rax)
 111b770:	movzbl 0x0(%r13,%rax,1),%edx
 111b776:	movzbl -0x5f0(%rbp,%rdx,1),%ecx
 111b77e:	test   $0xf,%cl
 111b781:	je     111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111b787:	and    $0xf,%cl
 111b78a:	mov    %cl,0x808(%r14,%rdx,1)
 111b792:	movzbl -0x300(%rbp),%edx
 111b799:	and    $0xf,%dl
 111b79c:	movzbl %cl,%ecx
 111b79f:	movzbl %dl,%edx
 111b7a2:	cmp    %cl,%dl
 111b7a4:	cmova  %edx,%ecx
 111b7a7:	mov    %cl,-0x300(%rbp)
 111b7ad:	inc    %rax
 111b7b0:	cmp    %rax,%r15
 111b7b3:	jne    111b770 <zstd.finalizeSmallHuffmanLiteralPlan+0xcd0>
 111b7b5:	movzbl -0x300(%rbp),%eax
 111b7bc:	and    $0xf,%al
 111b7be:	mov    %al,0x909(%r14)
 111b7c5:	vxorps %xmm0,%xmm0,%xmm0
 111b7c9:	vmovaps %xmm0,-0x3b0(%rbp)
 111b7d1:	movq   $0x0,-0x3a0(%rbp)
 111b7dc:	lea    -0x1(%r15),%rdx
 111b7e0:	mov    %r15d,%ecx
 111b7e3:	and    $0x3,%ecx
 111b7e6:	cmp    $0x3,%rdx
 111b7ea:	jae    111b7f3 <zstd.finalizeSmallHuffmanLiteralPlan+0xd53>
 111b7ec:	xor    %edx,%edx
 111b7ee:	jmp    111b86d <zstd.finalizeSmallHuffmanLiteralPlan+0xdcd>
 111b7f3:	mov    %r15,%rsi
 111b7f6:	and    $0xfffffffffffffffc,%rsi
 111b7fa:	xor    %edx,%edx
 111b7fc:	nopl   0x0(%rax)
 111b800:	movzbl 0x0(%r13,%rdx,1),%edi
 111b806:	movzbl -0x5f0(%rbp,%rdi,1),%edi
 111b80e:	and    $0xf,%edi
 111b811:	incw   -0x3b0(%rbp,%rdi,2)
 111b819:	movzbl 0x1(%r13,%rdx,1),%edi
 111b81f:	movzbl -0x5f0(%rbp,%rdi,1),%edi
 111b827:	and    $0xf,%edi
 111b82a:	incw   -0x3b0(%rbp,%rdi,2)
 111b832:	movzbl 0x2(%r13,%rdx,1),%edi
 111b838:	movzbl -0x5f0(%rbp,%rdi,1),%edi
 111b840:	and    $0xf,%edi
 111b843:	incw   -0x3b0(%rbp,%rdi,2)
 111b84b:	movzbl 0x3(%r13,%rdx,1),%edi
 111b851:	movzbl -0x5f0(%rbp,%rdi,1),%edi
 111b859:	and    $0xf,%edi
 111b85c:	incw   -0x3b0(%rbp,%rdi,2)
 111b864:	add    $0x4,%rdx
 111b868:	cmp    %rdx,%rsi
 111b86b:	jne    111b800 <zstd.finalizeSmallHuffmanLiteralPlan+0xd60>
 111b86d:	test   %rcx,%rcx
 111b870:	je     111b89f <zstd.finalizeSmallHuffmanLiteralPlan+0xdff>
 111b872:	add    %r14,%rdx
 111b875:	add    $0x608,%rdx
 111b87c:	xor    %esi,%esi
 111b87e:	xchg   %ax,%ax
 111b880:	movzbl (%rdx,%rsi,1),%edi
 111b884:	movzbl -0x5f0(%rbp,%rdi,1),%edi
 111b88c:	and    $0xf,%edi
 111b88f:	incw   -0x3b0(%rbp,%rdi,2)
 111b897:	inc    %rsi
 111b89a:	cmp    %rsi,%rcx
 111b89d:	jne    111b880 <zstd.finalizeSmallHuffmanLiteralPlan+0xde0>
 111b89f:	lea    0x909(%r14),%r12
 111b8a6:	vxorps %xmm0,%xmm0,%xmm0
 111b8aa:	vmovaps %xmm0,-0x4f0(%rbp)
 111b8b2:	movq   $0x0,-0x4e0(%rbp)
 111b8bd:	xor    %ecx,%ecx
 111b8bf:	jmp    111b90f <zstd.finalizeSmallHuffmanLiteralPlan+0xe6f>
 111b8c1:	movzbl -0x300(%rbp),%eax
 111b8c8:	and    $0xf,%al
 111b8ca:	mov    %al,0x909(%r14)
 111b8d1:	vxorps %xmm0,%xmm0,%xmm0
 111b8d5:	vmovaps %xmm0,-0x3b0(%rbp)
 111b8dd:	movq   $0x0,-0x3a0(%rbp)
 111b8e8:	vmovaps %xmm0,-0x4f0(%rbp)
 111b8f0:	movq   $0x0,-0x4e0(%rbp)
 111b8fb:	xor    %r15d,%r15d
 111b8fe:	test   $0xf,%al
 111b900:	je     111b9f6 <zstd.finalizeSmallHuffmanLiteralPlan+0xf56>
 111b906:	lea    0x909(%r14),%r12
 111b90d:	mov    $0x1,%cl
 111b90f:	and    $0xf,%al
 111b911:	movzbl %al,%esi
 111b914:	mov    %esi,%eax
 111b916:	and    $0x7,%eax
 111b919:	mov    %esi,%edx
 111b91b:	dec    %dl
 111b91d:	cmp    $0x7,%dl
 111b920:	jae    111b929 <zstd.finalizeSmallHuffmanLiteralPlan+0xe89>
 111b922:	xor    %edx,%edx
 111b924:	jmp    111b9be <zstd.finalizeSmallHuffmanLiteralPlan+0xf1e>
 111b929:	mov    %esi,%edi
 111b92b:	and    $0xfffffff8,%edi
 111b92e:	xor    %edx,%edx
 111b930:	mov    %dx,-0x4f0(%rbp,%rsi,2)
 111b938:	add    -0x3b0(%rbp,%rsi,2),%dx
 111b940:	mov    %dx,-0x4f2(%rbp,%rsi,2)
 111b948:	add    -0x3b2(%rbp,%rsi,2),%dx
 111b950:	mov    %dx,-0x4f4(%rbp,%rsi,2)
 111b958:	add    -0x3b4(%rbp,%rsi,2),%dx
 111b960:	mov    %dx,-0x4f6(%rbp,%rsi,2)
 111b968:	add    -0x3b6(%rbp,%rsi,2),%dx
 111b970:	mov    %dx,-0x4f8(%rbp,%rsi,2)
 111b978:	add    -0x3b8(%rbp,%rsi,2),%dx
 111b980:	mov    %dx,-0x4fa(%rbp,%rsi,2)
 111b988:	add    -0x3ba(%rbp,%rsi,2),%dx
 111b990:	mov    %dx,-0x4fc(%rbp,%rsi,2)
 111b998:	add    -0x3bc(%rbp,%rsi,2),%dx
 111b9a0:	mov    %dx,-0x4fe(%rbp,%rsi,2)
 111b9a8:	add    -0x3be(%rbp,%rsi,2),%dx
 111b9b0:	add    $0xfffffffffffffff8,%rsi
 111b9b4:	add    $0xfffffffffffffff8,%rdi
 111b9b8:	jne    111b930 <zstd.finalizeSmallHuffmanLiteralPlan+0xe90>
 111b9be:	test   %rax,%rax
 111b9c1:	je     111b9f2 <zstd.finalizeSmallHuffmanLiteralPlan+0xf52>
 111b9c3:	lea    -0x3b0(,%rsi,2),%rdi
 111b9cb:	add    %rbp,%rdi
 111b9ce:	lea    -0x4f0(,%rsi,2),%rsi
 111b9d6:	add    %rbp,%rsi
 111b9d9:	neg    %rax
 111b9dc:	xor    %r8d,%r8d
 111b9df:	nop
 111b9e0:	mov    %dx,(%rsi,%r8,2)
 111b9e5:	add    (%rdi,%r8,2),%dx
 111b9ea:	dec    %r8
 111b9ed:	cmp    %r8,%rax
 111b9f0:	jne    111b9e0 <zstd.finalizeSmallHuffmanLiteralPlan+0xf40>
 111b9f2:	test   %cl,%cl
 111b9f4:	je     111ba10 <zstd.finalizeSmallHuffmanLiteralPlan+0xf70>
 111b9f6:	lea    -0x1a0(%rbp),%rsi
 111b9fd:	mov    %r13,%rdi
 111ba00:	mov    %r15,%rdx
 111ba03:	vzeroupper 
 111ba06:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111ba0b:	jmp    111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111ba10:	lea    -0x1(%r15),%rbx
 111ba14:	mov    %r15d,%eax
 111ba17:	and    $0x3,%eax
 111ba1a:	cmp    $0x3,%rbx
 111ba1e:	jae    111ba27 <zstd.finalizeSmallHuffmanLiteralPlan+0xf87>
 111ba20:	xor    %ecx,%ecx
 111ba22:	jmp    111baf5 <zstd.finalizeSmallHuffmanLiteralPlan+0x1055>
 111ba27:	mov    %r15,%rdx
 111ba2a:	and    $0xfffffffffffffffc,%rdx
 111ba2e:	xor    %ecx,%ecx
 111ba30:	movzbl 0x0(%r13,%rcx,1),%esi
 111ba36:	movzbl -0x5f0(%rbp,%rsi,1),%edi
 111ba3e:	and    $0xf,%edi
 111ba41:	movzwl -0x4f0(%rbp,%rdi,2),%r8d
 111ba4a:	mov    %sil,-0x1a0(%rbp,%r8,1)
 111ba52:	lea    0x1(%r8),%esi
 111ba56:	mov    %si,-0x4f0(%rbp,%rdi,2)
 111ba5e:	movzbl 0x1(%r13,%rcx,1),%esi
 111ba64:	movzbl -0x5f0(%rbp,%rsi,1),%edi
 111ba6c:	and    $0xf,%edi
 111ba6f:	movzwl -0x4f0(%rbp,%rdi,2),%r8d
 111ba78:	mov    %sil,-0x1a0(%rbp,%r8,1)
 111ba80:	lea    0x1(%r8),%esi
 111ba84:	mov    %si,-0x4f0(%rbp,%rdi,2)
 111ba8c:	movzbl 0x2(%r13,%rcx,1),%esi
 111ba92:	movzbl -0x5f0(%rbp,%rsi,1),%edi
 111ba9a:	and    $0xf,%edi
 111ba9d:	movzwl -0x4f0(%rbp,%rdi,2),%r8d
 111baa6:	mov    %sil,-0x1a0(%rbp,%r8,1)
 111baae:	lea    0x1(%r8),%esi
 111bab2:	mov    %si,-0x4f0(%rbp,%rdi,2)
 111baba:	movzbl 0x3(%r13,%rcx,1),%esi
 111bac0:	movzbl -0x5f0(%rbp,%rsi,1),%edi
 111bac8:	and    $0xf,%edi
 111bacb:	movzwl -0x4f0(%rbp,%rdi,2),%r8d
 111bad4:	mov    %sil,-0x1a0(%rbp,%r8,1)
 111badc:	lea    0x1(%r8),%esi
 111bae0:	mov    %si,-0x4f0(%rbp,%rdi,2)
 111bae8:	add    $0x4,%rcx
 111baec:	cmp    %rcx,%rdx
 111baef:	jne    111ba30 <zstd.finalizeSmallHuffmanLiteralPlan+0xf90>
 111baf5:	test   %rax,%rax
 111baf8:	je     111bb44 <zstd.finalizeSmallHuffmanLiteralPlan+0x10a4>
 111bafa:	add    %r14,%rcx
 111bafd:	add    $0x608,%rcx
 111bb04:	xor    %edx,%edx
 111bb06:	cs nopw 0x0(%rax,%rax,1)
 111bb10:	movzbl (%rcx,%rdx,1),%esi
 111bb14:	movzbl -0x5f0(%rbp,%rsi,1),%edi
 111bb1c:	and    $0xf,%edi
 111bb1f:	movzwl -0x4f0(%rbp,%rdi,2),%r8d
 111bb28:	mov    %sil,-0x1a0(%rbp,%r8,1)
 111bb30:	lea    0x1(%r8),%esi
 111bb34:	mov    %si,-0x4f0(%rbp,%rdi,2)
 111bb3c:	inc    %rdx
 111bb3f:	cmp    %rdx,%rax
 111bb42:	jne    111bb10 <zstd.finalizeSmallHuffmanLiteralPlan+0x1070>
 111bb44:	lea    -0x1a0(%rbp),%rsi
 111bb4b:	mov    %r13,%rdi
 111bb4e:	mov    %r15,%rdx
 111bb51:	vzeroupper 
 111bb54:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111bb59:	movzbl 0x909(%r14),%eax
 111bb61:	movzbl 0x608(%r14),%ecx
 111bb69:	sub    -0x5f0(%rbp,%rcx,1),%al
 111bb70:	inc    %al
 111bb72:	and    $0xf,%al
 111bb74:	mov    %al,0x708(%r14)
 111bb7b:	movw   $0x0,0x408(%r14,%rcx,2)
 111bb86:	mov    %al,-0x1a0(%rbp)
 111bb8c:	cmp    $0x1,%r15
 111bb90:	je     111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111bb96:	cmp    $0x2,%r15
 111bb9a:	jne    111bba8 <zstd.finalizeSmallHuffmanLiteralPlan+0x1108>
 111bb9c:	mov    $0x1,%eax
 111bba1:	xor    %ecx,%ecx
 111bba3:	jmp    111bc68 <zstd.finalizeSmallHuffmanLiteralPlan+0x11c8>
 111bba8:	mov    %rbx,%rdx
 111bbab:	and    $0xfffffffffffffffe,%rdx
 111bbaf:	xor    %ecx,%ecx
 111bbb1:	xor    %eax,%eax
 111bbb3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111bbc0:	movzbl 0x609(%r14,%rax,1),%esi
 111bbc9:	movzbl 0x909(%r14),%edi
 111bbd1:	sub    -0x5f0(%rbp,%rsi,1),%dil
 111bbd9:	inc    %dil
 111bbdc:	mov    %edi,%r8d
 111bbdf:	sub    -0x1a0(%rbp),%r8b
 111bbe6:	and    $0xf,%r8b
 111bbea:	shrx   %r8,%rcx,%rcx
 111bbef:	inc    %rcx
 111bbf2:	and    $0xf,%dil
 111bbf6:	mov    %dil,0x709(%r14,%rax,1)
 111bbfe:	mov    %cx,0x408(%r14,%rsi,2)
 111bc07:	mov    %dil,-0x1a0(%rbp)
 111bc0e:	movzbl 0x60a(%r14,%rax,1),%esi
 111bc17:	movzbl 0x909(%r14),%r8d
 111bc1f:	sub    -0x5f0(%rbp,%rsi,1),%r8b
 111bc27:	inc    %r8b
 111bc2a:	mov    %r8d,%r9d
 111bc2d:	sub    %dil,%r9b
 111bc30:	and    $0xf,%r9b
 111bc34:	shrx   %r9,%rcx,%rcx
 111bc39:	inc    %rcx
 111bc3c:	and    $0xf,%r8b
 111bc40:	mov    %r8b,0x70a(%r14,%rax,1)
 111bc48:	mov    %cx,0x408(%r14,%rsi,2)
 111bc51:	mov    %r8b,-0x1a0(%rbp)
 111bc58:	add    $0x2,%rax
 111bc5c:	cmp    %rax,%rdx
 111bc5f:	jne    111bbc0 <zstd.finalizeSmallHuffmanLiteralPlan+0x1120>
 111bc65:	inc    %rax
 111bc68:	test   $0x1,%bl
 111bc6b:	je     111bcb9 <zstd.finalizeSmallHuffmanLiteralPlan+0x1219>
 111bc6d:	movzbl 0x608(%r14,%rax,1),%edx
 111bc76:	movzbl 0x909(%r14),%esi
 111bc7e:	sub    -0x5f0(%rbp,%rdx,1),%sil
 111bc86:	inc    %sil
 111bc89:	mov    %esi,%edi
 111bc8b:	sub    -0x1a0(%rbp),%dil
 111bc92:	and    $0xf,%dil
 111bc96:	shrx   %rdi,%rcx,%rcx
 111bc9b:	and    $0xf,%sil
 111bc9f:	mov    %sil,0x708(%r14,%rax,1)
 111bca7:	inc    %ecx
 111bca9:	mov    %cx,0x408(%r14,%rdx,2)
 111bcb2:	mov    %sil,-0x1a0(%rbp)
 111bcb9:	mov    (%r14),%rsi
 111bcbc:	cmp    $0x2,%rsi
 111bcc0:	jb     111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111bcc6:	movzbl 0x908(%r14),%eax
 111bcce:	mov    %esi,%ecx
 111bcd0:	and    $0x3,%ecx
 111bcd3:	cmp    $0x4,%rsi
 111bcd7:	jae    111bd89 <zstd.finalizeSmallHuffmanLiteralPlan+0x12e9>
 111bcdd:	xor    %edi,%edi
 111bcdf:	xor    %edx,%edx
 111bce1:	test   %rcx,%rcx
 111bce4:	je     111bd27 <zstd.finalizeSmallHuffmanLiteralPlan+0x1287>
 111bce6:	lea    (%rdi,%r14,1),%rsi
 111bcea:	add    $0x708,%rsi
 111bcf1:	xor    %edi,%edi
 111bcf3:	mov    $0x1,%r8d
 111bcf9:	jmp    111bd08 <zstd.finalizeSmallHuffmanLiteralPlan+0x1268>
 111bcfb:	nopl   0x0(%rax,%rax,1)
 111bd00:	inc    %rdi
 111bd03:	cmp    %rdi,%rcx
 111bd06:	je     111bd27 <zstd.finalizeSmallHuffmanLiteralPlan+0x1287>
 111bd08:	cmp    %al,-0x100(%rsi,%rdi,1)
 111bd0f:	je     111bd00 <zstd.finalizeSmallHuffmanLiteralPlan+0x1260>
 111bd11:	movzbl (%rsi,%rdi,1),%r9d
 111bd16:	and    $0xf,%r9b
 111bd1a:	shlx   %r9d,%r8d,%r9d
 111bd1f:	shr    %r9d
 111bd22:	add    %r9,%rdx
 111bd25:	jmp    111bd00 <zstd.finalizeSmallHuffmanLiteralPlan+0x1260>
 111bd27:	test   %rdx,%rdx
 111bd2a:	je     111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111bd2c:	movzbl (%r12),%ecx
 111bd31:	mov    %ecx,%esi
 111bd33:	and    $0xf,%sil
 111bd37:	mov    $0x1,%edi
 111bd3c:	shlx   %rsi,%rdi,%rsi
 111bd41:	sub    %rdx,%rsi
 111bd44:	jbe    111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111bd46:	blsr   %esi,%edx
 111bd4b:	jne    111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111bd4d:	movzbl 0x808(%r14,%rax,1),%eax
 111bd56:	test   %al,%al
 111bd58:	je     111bd72 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d2>
 111bd5a:	lzcnt  %rsi,%rdx
 111bd5f:	neg    %dl
 111bd61:	inc    %cl
 111bd63:	and    $0xf,%cl
 111bd66:	sub    %al,%cl
 111bd68:	and    $0x3f,%dl
 111bd6b:	cmp    %dl,%cl
 111bd6d:	sete   %al
 111bd70:	jmp    111bd74 <zstd.finalizeSmallHuffmanLiteralPlan+0x12d4>
 111bd72:	xor    %eax,%eax
 111bd74:	add    $0x5c8,%rsp
 111bd7b:	pop    %rbx
 111bd7c:	pop    %r12
 111bd7e:	pop    %r13
 111bd80:	pop    %r14
 111bd82:	pop    %r15
 111bd84:	pop    %rbp
 111bd85:	vzeroupper 
 111bd88:	ret    
 111bd89:	and    $0xfffffffffffffffc,%rsi
 111bd8d:	xor    %edi,%edi
 111bd8f:	mov    $0x1,%r8d
 111bd95:	xor    %edx,%edx
 111bd97:	jmp    111bdad <zstd.finalizeSmallHuffmanLiteralPlan+0x130d>
 111bd99:	nopl   0x0(%rax)
 111bda0:	add    $0x4,%rdi
 111bda4:	cmp    %rdi,%rsi
 111bda7:	je     111bce1 <zstd.finalizeSmallHuffmanLiteralPlan+0x1241>
 111bdad:	cmp    %al,0x608(%r14,%rdi,1)
 111bdb5:	je     111bdcf <zstd.finalizeSmallHuffmanLiteralPlan+0x132f>
 111bdb7:	movzbl 0x708(%r14,%rdi,1),%r9d
 111bdc0:	and    $0xf,%r9b
 111bdc4:	shlx   %r9d,%r8d,%r9d
 111bdc9:	shr    %r9d
 111bdcc:	add    %r9,%rdx
 111bdcf:	cmp    %al,0x609(%r14,%rdi,1)
 111bdd7:	jne    111bdf0 <zstd.finalizeSmallHuffmanLiteralPlan+0x1350>
 111bdd9:	cmp    %al,0x60a(%r14,%rdi,1)
 111bde1:	jne    111be12 <zstd.finalizeSmallHuffmanLiteralPlan+0x1372>
 111bde3:	cmp    %al,0x60b(%r14,%rdi,1)
 111bdeb:	je     111bda0 <zstd.finalizeSmallHuffmanLiteralPlan+0x1300>
 111bded:	jmp    111be38 <zstd.finalizeSmallHuffmanLiteralPlan+0x1398>
 111bdef:	nop
 111bdf0:	movzbl 0x709(%r14,%rdi,1),%r9d
 111bdf9:	and    $0xf,%r9b
 111bdfd:	shlx   %r9d,%r8d,%r9d
 111be02:	shr    %r9d
 111be05:	add    %r9,%rdx
 111be08:	cmp    %al,0x60a(%r14,%rdi,1)
 111be10:	je     111bde3 <zstd.finalizeSmallHuffmanLiteralPlan+0x1343>
 111be12:	movzbl 0x70a(%r14,%rdi,1),%r9d
 111be1b:	and    $0xf,%r9b
 111be1f:	shlx   %r9d,%r8d,%r9d
 111be24:	shr    %r9d
 111be27:	add    %r9,%rdx
 111be2a:	cmp    %al,0x60b(%r14,%rdi,1)
 111be32:	je     111bda0 <zstd.finalizeSmallHuffmanLiteralPlan+0x1300>
 111be38:	movzbl 0x70b(%r14,%rdi,1),%r9d
 111be41:	and    $0xf,%r9b
 111be45:	shlx   %r9d,%r8d,%r9d
 111be4a:	shr    %r9d
 111be4d:	add    %r9,%rdx
 111be50:	jmp    111bda0 <zstd.finalizeSmallHuffmanLiteralPlan+0x1300>
 111be55:	cmpl   $0x0,-0x280(%rbp)
 111be5c:	je     111be67 <zstd.finalizeSmallHuffmanLiteralPlan+0x13c7>
 111be5e:	lea    -0x70(%rbp),%rax
 111be62:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111be67:	cmpl   $0x0,-0x27c(%rbp)
 111be6e:	je     111be79 <zstd.finalizeSmallHuffmanLiteralPlan+0x13d9>
 111be70:	lea    -0x6f(%rbp),%rax
 111be74:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111be79:	cmpl   $0x0,-0x278(%rbp)
 111be80:	je     111be8b <zstd.finalizeSmallHuffmanLiteralPlan+0x13eb>
 111be82:	lea    -0x6e(%rbp),%rax
 111be86:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111be8b:	cmpl   $0x0,-0x274(%rbp)
 111be92:	je     111be9d <zstd.finalizeSmallHuffmanLiteralPlan+0x13fd>
 111be94:	lea    -0x6d(%rbp),%rax
 111be98:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111be9d:	cmpl   $0x0,-0x270(%rbp)
 111bea4:	je     111beaf <zstd.finalizeSmallHuffmanLiteralPlan+0x140f>
 111bea6:	lea    -0x6c(%rbp),%rax
 111beaa:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111beaf:	cmpl   $0x0,-0x26c(%rbp)
 111beb6:	je     111bec1 <zstd.finalizeSmallHuffmanLiteralPlan+0x1421>
 111beb8:	lea    -0x6b(%rbp),%rax
 111bebc:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bec1:	cmpl   $0x0,-0x268(%rbp)
 111bec8:	je     111bed3 <zstd.finalizeSmallHuffmanLiteralPlan+0x1433>
 111beca:	lea    -0x6a(%rbp),%rax
 111bece:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bed3:	cmpl   $0x0,-0x264(%rbp)
 111beda:	je     111bee5 <zstd.finalizeSmallHuffmanLiteralPlan+0x1445>
 111bedc:	lea    -0x69(%rbp),%rax
 111bee0:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bee5:	cmpl   $0x0,-0x260(%rbp)
 111beec:	je     111bef7 <zstd.finalizeSmallHuffmanLiteralPlan+0x1457>
 111beee:	lea    -0x68(%rbp),%rax
 111bef2:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bef7:	cmpl   $0x0,-0x25c(%rbp)
 111befe:	je     111bf09 <zstd.finalizeSmallHuffmanLiteralPlan+0x1469>
 111bf00:	lea    -0x67(%rbp),%rax
 111bf04:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf09:	cmpl   $0x0,-0x258(%rbp)
 111bf10:	je     111bf1b <zstd.finalizeSmallHuffmanLiteralPlan+0x147b>
 111bf12:	lea    -0x66(%rbp),%rax
 111bf16:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf1b:	cmpl   $0x0,-0x254(%rbp)
 111bf22:	je     111bf2d <zstd.finalizeSmallHuffmanLiteralPlan+0x148d>
 111bf24:	lea    -0x65(%rbp),%rax
 111bf28:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf2d:	cmpl   $0x0,-0x250(%rbp)
 111bf34:	je     111bf3f <zstd.finalizeSmallHuffmanLiteralPlan+0x149f>
 111bf36:	lea    -0x64(%rbp),%rax
 111bf3a:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf3f:	cmpl   $0x0,-0x24c(%rbp)
 111bf46:	je     111bf51 <zstd.finalizeSmallHuffmanLiteralPlan+0x14b1>
 111bf48:	lea    -0x63(%rbp),%rax
 111bf4c:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf51:	cmpl   $0x0,-0x248(%rbp)
 111bf58:	je     111bf63 <zstd.finalizeSmallHuffmanLiteralPlan+0x14c3>
 111bf5a:	lea    -0x62(%rbp),%rax
 111bf5e:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf63:	cmpl   $0x0,-0x244(%rbp)
 111bf6a:	je     111bf75 <zstd.finalizeSmallHuffmanLiteralPlan+0x14d5>
 111bf6c:	lea    -0x61(%rbp),%rax
 111bf70:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf75:	cmpl   $0x0,-0x240(%rbp)
 111bf7c:	je     111bf87 <zstd.finalizeSmallHuffmanLiteralPlan+0x14e7>
 111bf7e:	lea    -0x60(%rbp),%rax
 111bf82:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf87:	cmpl   $0x0,-0x23c(%rbp)
 111bf8e:	je     111bf99 <zstd.finalizeSmallHuffmanLiteralPlan+0x14f9>
 111bf90:	lea    -0x5f(%rbp),%rax
 111bf94:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bf99:	cmpl   $0x0,-0x238(%rbp)
 111bfa0:	je     111bfab <zstd.finalizeSmallHuffmanLiteralPlan+0x150b>
 111bfa2:	lea    -0x5e(%rbp),%rax
 111bfa6:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bfab:	cmpl   $0x0,-0x234(%rbp)
 111bfb2:	je     111bfbd <zstd.finalizeSmallHuffmanLiteralPlan+0x151d>
 111bfb4:	lea    -0x5d(%rbp),%rax
 111bfb8:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bfbd:	cmpl   $0x0,-0x230(%rbp)
 111bfc4:	je     111bfcf <zstd.finalizeSmallHuffmanLiteralPlan+0x152f>
 111bfc6:	lea    -0x5c(%rbp),%rax
 111bfca:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bfcf:	cmpl   $0x0,-0x22c(%rbp)
 111bfd6:	je     111bfe1 <zstd.finalizeSmallHuffmanLiteralPlan+0x1541>
 111bfd8:	lea    -0x5b(%rbp),%rax
 111bfdc:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bfe1:	cmpl   $0x0,-0x228(%rbp)
 111bfe8:	je     111bff3 <zstd.finalizeSmallHuffmanLiteralPlan+0x1553>
 111bfea:	lea    -0x5a(%rbp),%rax
 111bfee:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111bff3:	cmpl   $0x0,-0x224(%rbp)
 111bffa:	je     111c005 <zstd.finalizeSmallHuffmanLiteralPlan+0x1565>
 111bffc:	lea    -0x59(%rbp),%rax
 111c000:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c005:	cmpl   $0x0,-0x220(%rbp)
 111c00c:	je     111c017 <zstd.finalizeSmallHuffmanLiteralPlan+0x1577>
 111c00e:	lea    -0x58(%rbp),%rax
 111c012:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c017:	cmpl   $0x0,-0x21c(%rbp)
 111c01e:	je     111c029 <zstd.finalizeSmallHuffmanLiteralPlan+0x1589>
 111c020:	lea    -0x57(%rbp),%rax
 111c024:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c029:	cmpl   $0x0,-0x218(%rbp)
 111c030:	je     111c03b <zstd.finalizeSmallHuffmanLiteralPlan+0x159b>
 111c032:	lea    -0x56(%rbp),%rax
 111c036:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c03b:	cmpl   $0x0,-0x214(%rbp)
 111c042:	je     111c04d <zstd.finalizeSmallHuffmanLiteralPlan+0x15ad>
 111c044:	lea    -0x55(%rbp),%rax
 111c048:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c04d:	cmpl   $0x0,-0x210(%rbp)
 111c054:	je     111c05f <zstd.finalizeSmallHuffmanLiteralPlan+0x15bf>
 111c056:	lea    -0x54(%rbp),%rax
 111c05a:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c05f:	cmpl   $0x0,-0x20c(%rbp)
 111c066:	je     111c071 <zstd.finalizeSmallHuffmanLiteralPlan+0x15d1>
 111c068:	lea    -0x53(%rbp),%rax
 111c06c:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c071:	cmpl   $0x0,-0x208(%rbp)
 111c078:	je     111c083 <zstd.finalizeSmallHuffmanLiteralPlan+0x15e3>
 111c07a:	lea    -0x52(%rbp),%rax
 111c07e:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c083:	cmpl   $0x0,-0x204(%rbp)
 111c08a:	je     111c095 <zstd.finalizeSmallHuffmanLiteralPlan+0x15f5>
 111c08c:	lea    -0x51(%rbp),%rax
 111c090:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c095:	cmpl   $0x0,-0x200(%rbp)
 111c09c:	je     111c0a7 <zstd.finalizeSmallHuffmanLiteralPlan+0x1607>
 111c09e:	lea    -0x50(%rbp),%rax
 111c0a2:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c0a7:	cmpl   $0x0,-0x1fc(%rbp)
 111c0ae:	je     111c0b9 <zstd.finalizeSmallHuffmanLiteralPlan+0x1619>
 111c0b0:	lea    -0x4f(%rbp),%rax
 111c0b4:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c0b9:	cmpl   $0x0,-0x1f8(%rbp)
 111c0c0:	je     111c0cb <zstd.finalizeSmallHuffmanLiteralPlan+0x162b>
 111c0c2:	lea    -0x4e(%rbp),%rax
 111c0c6:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c0cb:	cmpl   $0x0,-0x1f4(%rbp)
 111c0d2:	je     111c0dd <zstd.finalizeSmallHuffmanLiteralPlan+0x163d>
 111c0d4:	lea    -0x4d(%rbp),%rax
 111c0d8:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c0dd:	cmpl   $0x0,-0x1f0(%rbp)
 111c0e4:	je     111c0ef <zstd.finalizeSmallHuffmanLiteralPlan+0x164f>
 111c0e6:	lea    -0x4c(%rbp),%rax
 111c0ea:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c0ef:	cmpl   $0x0,-0x1ec(%rbp)
 111c0f6:	je     111c101 <zstd.finalizeSmallHuffmanLiteralPlan+0x1661>
 111c0f8:	lea    -0x4b(%rbp),%rax
 111c0fc:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c101:	cmpl   $0x0,-0x1e8(%rbp)
 111c108:	je     111c113 <zstd.finalizeSmallHuffmanLiteralPlan+0x1673>
 111c10a:	lea    -0x4a(%rbp),%rax
 111c10e:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c113:	cmpl   $0x0,-0x1e4(%rbp)
 111c11a:	je     111c125 <zstd.finalizeSmallHuffmanLiteralPlan+0x1685>
 111c11c:	lea    -0x49(%rbp),%rax
 111c120:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c125:	cmpl   $0x0,-0x1e0(%rbp)
 111c12c:	je     111c137 <zstd.finalizeSmallHuffmanLiteralPlan+0x1697>
 111c12e:	lea    -0x48(%rbp),%rax
 111c132:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c137:	cmpl   $0x0,-0x1dc(%rbp)
 111c13e:	je     111c149 <zstd.finalizeSmallHuffmanLiteralPlan+0x16a9>
 111c140:	lea    -0x47(%rbp),%rax
 111c144:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c149:	cmpl   $0x0,-0x1d8(%rbp)
 111c150:	je     111c15b <zstd.finalizeSmallHuffmanLiteralPlan+0x16bb>
 111c152:	lea    -0x46(%rbp),%rax
 111c156:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c15b:	cmpl   $0x0,-0x1d4(%rbp)
 111c162:	je     111c16d <zstd.finalizeSmallHuffmanLiteralPlan+0x16cd>
 111c164:	lea    -0x45(%rbp),%rax
 111c168:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c16d:	cmpl   $0x0,-0x1d0(%rbp)
 111c174:	je     111c17f <zstd.finalizeSmallHuffmanLiteralPlan+0x16df>
 111c176:	lea    -0x44(%rbp),%rax
 111c17a:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c17f:	cmpl   $0x0,-0x1cc(%rbp)
 111c186:	je     111c191 <zstd.finalizeSmallHuffmanLiteralPlan+0x16f1>
 111c188:	lea    -0x43(%rbp),%rax
 111c18c:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c191:	cmpl   $0x0,-0x1c8(%rbp)
 111c198:	je     111c1a3 <zstd.finalizeSmallHuffmanLiteralPlan+0x1703>
 111c19a:	lea    -0x42(%rbp),%rax
 111c19e:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c1a3:	cmpl   $0x0,-0x1c4(%rbp)
 111c1aa:	je     111c1b5 <zstd.finalizeSmallHuffmanLiteralPlan+0x1715>
 111c1ac:	lea    -0x41(%rbp),%rax
 111c1b0:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c1b5:	cmpl   $0x0,-0x1c0(%rbp)
 111c1bc:	je     111c1c7 <zstd.finalizeSmallHuffmanLiteralPlan+0x1727>
 111c1be:	lea    -0x40(%rbp),%rax
 111c1c2:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c1c7:	cmpl   $0x0,-0x1bc(%rbp)
 111c1ce:	je     111c1d9 <zstd.finalizeSmallHuffmanLiteralPlan+0x1739>
 111c1d0:	lea    -0x3f(%rbp),%rax
 111c1d4:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c1d9:	cmpl   $0x0,-0x1b8(%rbp)
 111c1e0:	je     111c1eb <zstd.finalizeSmallHuffmanLiteralPlan+0x174b>
 111c1e2:	lea    -0x3e(%rbp),%rax
 111c1e6:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c1eb:	cmpl   $0x0,-0x1b4(%rbp)
 111c1f2:	je     111c1fd <zstd.finalizeSmallHuffmanLiteralPlan+0x175d>
 111c1f4:	lea    -0x3d(%rbp),%rax
 111c1f8:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c1fd:	cmpl   $0x0,-0x1b0(%rbp)
 111c204:	je     111c20f <zstd.finalizeSmallHuffmanLiteralPlan+0x176f>
 111c206:	lea    -0x3c(%rbp),%rax
 111c20a:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c20f:	cmpl   $0x0,-0x1ac(%rbp)
 111c216:	je     111c221 <zstd.finalizeSmallHuffmanLiteralPlan+0x1781>
 111c218:	lea    -0x3b(%rbp),%rax
 111c21c:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c221:	cmpl   $0x0,-0x1a8(%rbp)
 111c228:	je     111c233 <zstd.finalizeSmallHuffmanLiteralPlan+0x1793>
 111c22a:	lea    -0x3a(%rbp),%rax
 111c22e:	jmp    111afa7 <zstd.finalizeSmallHuffmanLiteralPlan+0x507>
 111c233:	cmpl   $0x0,-0x1a4(%rbp)
 111c23a:	mov    -0x38(%rbp),%r14
 111c23e:	mov    -0x30(%rbp),%r13
 111c242:	je     111b480 <zstd.finalizeSmallHuffmanLiteralPlan+0x9e0>
 111c248:	lea    -0x39(%rbp),%rax
 111c24c:	jmp    111b47d <zstd.finalizeSmallHuffmanLiteralPlan+0x9dd>

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
