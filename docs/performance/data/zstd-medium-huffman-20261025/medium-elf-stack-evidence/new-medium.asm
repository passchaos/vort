
/home/passchaos/project-z/vort-zstd-duplicate-profile/.zig-cache/o/e896d85b31c33819f34a4488826cd334/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001141640 <huffman.treeCodeLengthsMediumKnownActive__anon_38997>:
 1141640:	push   %rbp
 1141641:	mov    %rsp,%rbp
 1141644:	push   %r15
 1141646:	push   %r14
 1141648:	push   %r13
 114164a:	push   %r12
 114164c:	push   %rbx
 114164d:	sub    $0x8c28,%rsp
 1141654:	mov    %rcx,%r14
 1141657:	mov    %rdi,-0x40(%rbp)
 114165b:	mov    %r14d,%eax
 114165e:	and    $0x3,%eax
 1141661:	mov    %r14d,%r8d
 1141664:	and    $0x7c,%r8d
 1141668:	lea    -0x8c12(%rbp),%rcx
 114166f:	xor    %edi,%edi
 1141671:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1141680:	movzbl (%rdx,%rdi,1),%r9d
 1141685:	movzwl %r9w,%r9d
 1141689:	mov    (%rsi,%r9,4),%r10d
 114168d:	mov    %r10,-0x3e(%rcx)
 1141691:	mov    %r9w,-0x32(%rcx)
 1141696:	mov    %di,-0x30(%rcx)
 114169a:	movl   $0xffffffff,-0x36(%rcx)
 11416a1:	mov    %di,-0x450(%rbp,%rdi,2)
 11416a9:	movzbl 0x1(%rdx,%rdi,1),%r9d
 11416af:	movzwl %r9w,%r9d
 11416b3:	mov    (%rsi,%r9,4),%r10d
 11416b7:	mov    %r10,-0x2e(%rcx)
 11416bb:	mov    %r9w,-0x22(%rcx)
 11416c0:	lea    0x1(%rdi),%r9d
 11416c4:	mov    %r9w,-0x20(%rcx)
 11416c9:	movl   $0xffffffff,-0x26(%rcx)
 11416d0:	mov    %r9w,-0x44e(%rbp,%rdi,2)
 11416d9:	movzbl 0x2(%rdx,%rdi,1),%r9d
 11416df:	movzwl %r9w,%r9d
 11416e3:	mov    (%rsi,%r9,4),%r10d
 11416e7:	mov    %r10,-0x1e(%rcx)
 11416eb:	mov    %r9w,-0x12(%rcx)
 11416f0:	lea    0x2(%rdi),%r9d
 11416f4:	mov    %r9w,-0x10(%rcx)
 11416f9:	movl   $0xffffffff,-0x16(%rcx)
 1141700:	mov    %r9w,-0x44c(%rbp,%rdi,2)
 1141709:	movzbl 0x3(%rdx,%rdi,1),%r9d
 114170f:	movzwl %r9w,%r9d
 1141713:	mov    (%rsi,%r9,4),%r10d
 1141717:	mov    %r10,-0xe(%rcx)
 114171b:	mov    %r9w,-0x2(%rcx)
 1141720:	lea    0x3(%rdi),%r9d
 1141724:	mov    %r9w,(%rcx)
 1141728:	movl   $0xffffffff,-0x6(%rcx)
 114172f:	mov    %r9w,-0x44a(%rbp,%rdi,2)
 1141738:	add    $0x4,%rdi
 114173c:	add    $0x40,%rcx
 1141740:	cmp    %r8,%rdi
 1141743:	jne    1141680 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x40>
 1141749:	test   %rax,%rax
 114174c:	je     1141794 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x154>
 114174e:	add    $0xffffffffffffffd0,%rcx
 1141752:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1141760:	movzbl (%rdx,%rdi,1),%r8d
 1141765:	movzwl %r8w,%r8d
 1141769:	mov    (%rsi,%r8,4),%r9d
 114176d:	mov    %r9,-0xe(%rcx)
 1141771:	mov    %r8w,-0x2(%rcx)
 1141776:	mov    %di,(%rcx)
 1141779:	movl   $0xffffffff,-0x6(%rcx)
 1141780:	mov    %di,-0x450(%rbp,%rdi,2)
 1141788:	inc    %rdi
 114178b:	add    $0x10,%rcx
 114178f:	dec    %rax
 1141792:	jne    1141760 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x120>
 1141794:	lea    -0x8c50(%rbp),%rax
 114179b:	mov    %rax,-0x50(%rbp)
 114179f:	mov    %r14,-0x48(%rbp)
 11417a3:	lea    -0x450(%rbp),%r13
 11417aa:	lea    -0x50(%rbp),%rdx
 11417ae:	mov    %r13,%rdi
 11417b1:	mov    %r14,%rsi
 11417b4:	call   111d340 <sort.block.block__anon_39129>
 11417b9:	lea    (%r14,%r14,1),%rbx
 11417bd:	lea    -0x350(%rbp),%r12
 11417c4:	mov    %r12,%rdi
 11417c7:	mov    %r13,%rsi
 11417ca:	mov    %rbx,%rdx
 11417cd:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 11417d2:	movb   $0x1,-0x29(%rbp)
 11417d6:	mov    $0x1,%al
 11417d8:	mov    %rbx,-0x38(%rbp)
 11417dc:	mov    %rbx,%rdx
 11417df:	mov    %r14,%r13
 11417e2:	cmp    $0xa,%al
 11417e4:	ja     1141ab0 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x470>
 11417ea:	mov    %r14,%r13
 11417ed:	mov    %r14,%rsi
 11417f0:	jmp    114180f <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x1cf>
 11417f2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1141800:	inc    %al
 1141802:	and    $0xf,%al
 1141804:	mov    %al,-0x29(%rbp)
 1141807:	cmp    $0xb,%al
 1141809:	jae    1141aa8 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x468>
 114180f:	cmp    $0x2,%rsi
 1141813:	jb     1141840 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x200>
 1141815:	add    $0xfffffffffffffffe,%rsi
 1141819:	mov    %rsi,%rdx
 114181c:	shr    %rdx
 114181f:	inc    %rdx
 1141822:	cmp    $0x2,%rsi
 1141826:	jae    1141850 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x210>
 1141828:	xor    %edi,%edi
 114182a:	xor    %r8d,%r8d
 114182d:	test   $0x2,%sil
 1141831:	je     114193d <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x2fd>
 1141837:	jmp    11419ae <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x36e>
 114183c:	nopl   0x0(%rax)
 1141840:	xor    %edx,%edx
 1141842:	jmp    11419ae <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x36e>
 1141847:	nopw   0x0(%rax,%rax,1)
 1141850:	mov    %r13,%r9
 1141853:	shl    $0x4,%r9
 1141857:	lea    -0x8c32(%rbp),%rcx
 114185e:	add    %rcx,%r9
 1141861:	mov    %rdx,%r10
 1141864:	and    $0xfffffffffffffffe,%r10
 1141868:	neg    %r10
 114186b:	xor    %edi,%edi
 114186d:	xor    %r8d,%r8d
 1141870:	movzwl -0x350(%rbp,%r8,2),%ecx
 1141879:	movzwl -0x34e(%rbp,%r8,2),%r11d
 1141882:	mov    %ecx,%ebx
 1141884:	shl    $0x4,%ebx
 1141887:	mov    %r11d,%r15d
 114188a:	shl    $0x4,%r15d
 114188e:	mov    -0x8c50(%rbp,%r15,1),%r15
 1141896:	add    -0x8c50(%rbp,%rbx,1),%r15
 114189e:	mov    %r15,-0x1e(%r9,%r8,8)
 11418a3:	mov    %cx,-0x16(%r9,%r8,8)
 11418a9:	mov    %r11w,-0x14(%r9,%r8,8)
 11418af:	mov    %r13w,-0x10(%r9,%r8,8)
 11418b5:	movw   $0xffff,-0x12(%r9,%r8,8)
 11418bd:	movzwl -0x34c(%rbp,%r8,2),%ecx
 11418c6:	movzwl -0x34a(%rbp,%r8,2),%r11d
 11418cf:	mov    %ecx,%ebx
 11418d1:	shl    $0x4,%ebx
 11418d4:	mov    %r11d,%r15d
 11418d7:	shl    $0x4,%r15d
 11418db:	mov    -0x8c50(%rbp,%r15,1),%r15
 11418e3:	add    -0x8c50(%rbp,%rbx,1),%r15
 11418eb:	mov    %r13w,-0x550(%rbp,%r8,1)
 11418f4:	mov    %r15,-0xe(%r9,%r8,8)
 11418f9:	mov    %cx,-0x6(%r9,%r8,8)
 11418ff:	mov    %r11w,-0x4(%r9,%r8,8)
 1141905:	lea    0x1(%r13),%ecx
 1141909:	mov    %cx,(%r9,%r8,8)
 114190e:	movw   $0xffff,-0x2(%r9,%r8,8)
 1141916:	add    $0x2,%r13
 114191a:	mov    %cx,-0x54e(%rbp,%r8,1)
 1141923:	add    $0x4,%r8
 1141927:	add    $0xfffffffffffffffe,%rdi
 114192b:	cmp    %rdi,%r10
 114192e:	jne    1141870 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x230>
 1141934:	neg    %rdi
 1141937:	test   $0x2,%sil
 114193b:	jne    11419ae <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x36e>
 114193d:	movzwl -0x350(%rbp,%r8,2),%ecx
 1141946:	movzwl -0x34e(%rbp,%r8,2),%esi
 114194f:	mov    %r13,%r8
 1141952:	shl    $0x4,%r8
 1141956:	mov    %ecx,%r9d
 1141959:	shl    $0x4,%r9d
 114195d:	mov    %esi,%r10d
 1141960:	shl    $0x4,%r10d
 1141964:	mov    -0x8c50(%rbp,%r10,1),%r10
 114196c:	add    -0x8c50(%rbp,%r9,1),%r10
 1141974:	mov    %r10,-0x8c50(%rbp,%r8,1)
 114197c:	mov    %cx,-0x8c48(%rbp,%r8,1)
 1141985:	mov    %si,-0x8c46(%rbp,%r8,1)
 114198e:	mov    %r13w,-0x8c42(%rbp,%r8,1)
 1141997:	movw   $0xffff,-0x8c44(%rbp,%r8,1)
 11419a2:	mov    %r13w,-0x550(%rbp,%rdi,2)
 11419ab:	inc    %r13
 11419ae:	test   %rdx,%rdx
 11419b1:	setne  %r10b
 11419b5:	mov    $0x1,%r11b
 11419b8:	mov    %r12,%rdi
 11419bb:	xor    %r8d,%r8d
 11419be:	xor    %r9d,%r9d
 11419c1:	xor    %esi,%esi
 11419c3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11419d0:	test   $0x1,%r10b
 11419d4:	je     1141a40 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x400>
 11419d6:	test   $0x1,%r11b
 11419da:	je     1141a60 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x420>
 11419e0:	movzwl -0x450(%rbp,%r9,2),%r10d
 11419e9:	movzwl -0x550(%rbp,%r8,2),%r11d
 11419f2:	mov    %r10d,%ebx
 11419f5:	shl    $0x4,%ebx
 11419f8:	mov    %r11d,%ecx
 11419fb:	shl    $0x4,%ecx
 11419fe:	mov    -0x8c50(%rbp,%rcx,1),%r15
 1141a06:	cmp    %r15,-0x8c50(%rbp,%rbx,1)
 1141a0e:	jne    1141a98 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x458>
 1141a14:	add    %rbp,%rbx
 1141a17:	add    $0xffffffffffff73b0,%rbx
 1141a1e:	add    %rbp,%rcx
 1141a21:	add    $0xffffffffffff73b0,%rcx
 1141a28:	movzwl 0xe(%rbx),%r15d
 1141a2d:	mov    %rdi,%rbx
 1141a30:	cmp    0xe(%rcx),%r15w
 1141a35:	jb     1141aa2 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x462>
 1141a37:	mov    %r11w,(%rbx)
 1141a3b:	jmp    1141a6c <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x42c>
 1141a3d:	nopl   (%rax)
 1141a40:	movzwl -0x450(%rbp,%r9,2),%ecx
 1141a49:	mov    %cx,(%rdi)
 1141a4c:	inc    %r9
 1141a4f:	jmp    1141a6f <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x42f>
 1141a51:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1141a60:	movzwl -0x550(%rbp,%r8,2),%ecx
 1141a69:	mov    %cx,(%rdi)
 1141a6c:	inc    %r8
 1141a6f:	inc    %rsi
 1141a72:	cmp    %rdx,%r8
 1141a75:	setb   %r10b
 1141a79:	add    $0x2,%rdi
 1141a7d:	cmp    %r14,%r9
 1141a80:	setb   %r11b
 1141a84:	jb     11419d0 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x390>
 1141a8a:	cmp    %rdx,%r8
 1141a8d:	jb     11419d0 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x390>
 1141a93:	jmp    1141800 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x1c0>
 1141a98:	lea    -0x350(%rbp,%rsi,2),%rbx
 1141aa0:	jae    1141a37 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x3f7>
 1141aa2:	mov    %r10w,(%rbx)
 1141aa6:	jmp    1141a4c <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x40c>
 1141aa8:	lea    0x0(,%r13,2),%rdx
 1141ab0:	mov    -0x38(%rbp),%r15
 1141ab4:	lea    -0x2(%r15),%r12
 1141ab8:	vxorps %xmm0,%xmm0,%xmm0
 1141abc:	vmovups %ymm0,-0x70(%rbp)
 1141ac1:	vmovups %ymm0,-0x90(%rbp)
 1141ac9:	vmovups %ymm0,-0xb0(%rbp)
 1141ad1:	vmovups %ymm0,-0xd0(%rbp)
 1141ad9:	vmovups %ymm0,-0xf0(%rbp)
 1141ae1:	vmovups %ymm0,-0x110(%rbp)
 1141ae9:	vmovups %ymm0,-0x130(%rbp)
 1141af1:	vmovups %ymm0,-0x150(%rbp)
 1141af9:	lea    -0x1450(%rbp),%rdi
 1141b00:	xor    %ebx,%ebx
 1141b02:	xor    %esi,%esi
 1141b04:	vzeroupper 
 1141b07:	call   119d4a0 <compiler_rt.memset>
 1141b0c:	add    $0xfffffffffffffffd,%r15
 1141b10:	mov    %r12d,%eax
 1141b13:	and    $0x6,%eax
 1141b16:	cmp    $0x7,%r15
 1141b1a:	jb     1141bbd <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x57d>
 1141b20:	and    $0xf8,%r12d
 1141b27:	xor    %ebx,%ebx
 1141b29:	nopl   0x0(%rax)
 1141b30:	movzwl -0x350(%rbp,%rbx,2),%ecx
 1141b38:	incw   -0x1450(%rbp,%rcx,2)
 1141b40:	movzwl -0x34e(%rbp,%rbx,2),%ecx
 1141b48:	incw   -0x1450(%rbp,%rcx,2)
 1141b50:	movzwl -0x34c(%rbp,%rbx,2),%ecx
 1141b58:	incw   -0x1450(%rbp,%rcx,2)
 1141b60:	movzwl -0x34a(%rbp,%rbx,2),%ecx
 1141b68:	incw   -0x1450(%rbp,%rcx,2)
 1141b70:	movzwl -0x348(%rbp,%rbx,2),%ecx
 1141b78:	incw   -0x1450(%rbp,%rcx,2)
 1141b80:	movzwl -0x346(%rbp,%rbx,2),%ecx
 1141b88:	incw   -0x1450(%rbp,%rcx,2)
 1141b90:	movzwl -0x344(%rbp,%rbx,2),%ecx
 1141b98:	incw   -0x1450(%rbp,%rcx,2)
 1141ba0:	movzwl -0x342(%rbp,%rbx,2),%ecx
 1141ba8:	incw   -0x1450(%rbp,%rcx,2)
 1141bb0:	add    $0x8,%rbx
 1141bb4:	cmp    %rbx,%r12
 1141bb7:	jne    1141b30 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x4f0>
 1141bbd:	test   %rax,%rax
 1141bc0:	je     1141be4 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x5a4>
 1141bc2:	lea    -0x350(,%rbx,2),%rcx
 1141bca:	add    %rbp,%rcx
 1141bcd:	xor    %edx,%edx
 1141bcf:	nop
 1141bd0:	movzwl (%rcx,%rdx,2),%esi
 1141bd4:	incw   -0x1450(%rbp,%rsi,2)
 1141bdc:	inc    %rdx
 1141bdf:	cmp    %rdx,%rax
 1141be2:	jne    1141bd0 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x590>
 1141be4:	cmp    %r14,%r13
 1141be7:	jbe    1141c3d <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x5fd>
 1141be9:	mov    %r13d,%edx
 1141bec:	sub    %r14d,%edx
 1141bef:	lea    0x1(%r14),%rcx
 1141bf3:	mov    %r13,%rax
 1141bf6:	test   $0x1,%dl
 1141bf9:	je     1141c34 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x5f4>
 1141bfb:	lea    -0x1(%r13),%rax
 1141bff:	movzwl -0x1452(%rbp,%r13,2),%edx
 1141c08:	test   %dx,%dx
 1141c0b:	je     1141c34 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x5f4>
 1141c0d:	mov    %rax,%rsi
 1141c10:	shl    $0x4,%rsi
 1141c14:	movzwl -0x8c48(%rbp,%rsi,1),%edi
 1141c1c:	movzwl -0x8c46(%rbp,%rsi,1),%esi
 1141c24:	add    %dx,-0x1450(%rbp,%rdi,2)
 1141c2c:	add    %dx,-0x1450(%rbp,%rsi,2)
 1141c34:	cmp    %rcx,%r13
 1141c37:	jne    1141dfe <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x7be>
 1141c3d:	mov    %r14d,%eax
 1141c40:	and    $0x7,%eax
 1141c43:	add    %r14,%r14
 1141c46:	and    $0xfffffffffffffff0,%r14
 1141c4a:	xor    %ecx,%ecx
 1141c4c:	nopl   0x0(%rax)
 1141c50:	movzwl -0x8c44(%rbp,%rcx,8),%edx
 1141c58:	movzbl -0x1450(%rbp,%rcx,1),%esi
 1141c60:	movzbl -0x144e(%rbp,%rcx,1),%edi
 1141c68:	and    $0xf,%sil
 1141c6c:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141c74:	movzwl -0x8c34(%rbp,%rcx,8),%edx
 1141c7c:	and    $0xf,%dil
 1141c80:	mov    %dil,-0x150(%rbp,%rdx,1)
 1141c88:	movzwl -0x8c24(%rbp,%rcx,8),%edx
 1141c90:	movzbl -0x144c(%rbp,%rcx,1),%esi
 1141c98:	and    $0xf,%sil
 1141c9c:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141ca4:	movzwl -0x8c14(%rbp,%rcx,8),%edx
 1141cac:	movzbl -0x144a(%rbp,%rcx,1),%esi
 1141cb4:	and    $0xf,%sil
 1141cb8:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141cc0:	movzwl -0x8c04(%rbp,%rcx,8),%edx
 1141cc8:	movzbl -0x1448(%rbp,%rcx,1),%esi
 1141cd0:	and    $0xf,%sil
 1141cd4:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141cdc:	movzwl -0x8bf4(%rbp,%rcx,8),%edx
 1141ce4:	movzbl -0x1446(%rbp,%rcx,1),%esi
 1141cec:	and    $0xf,%sil
 1141cf0:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141cf8:	movzwl -0x8be4(%rbp,%rcx,8),%edx
 1141d00:	movzbl -0x1444(%rbp,%rcx,1),%esi
 1141d08:	and    $0xf,%sil
 1141d0c:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141d14:	movzwl -0x8bd4(%rbp,%rcx,8),%edx
 1141d1c:	movzbl -0x1442(%rbp,%rcx,1),%esi
 1141d24:	and    $0xf,%sil
 1141d28:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141d30:	add    $0x10,%rcx
 1141d34:	cmp    %rcx,%r14
 1141d37:	jne    1141c50 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x610>
 1141d3d:	test   %rax,%rax
 1141d40:	je     1141d75 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x735>
 1141d42:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1141d50:	movzwl -0x8c44(%rbp,%rcx,8),%edx
 1141d58:	movzbl -0x1450(%rbp,%rcx,1),%esi
 1141d60:	and    $0xf,%sil
 1141d64:	mov    %sil,-0x150(%rbp,%rdx,1)
 1141d6c:	add    $0x2,%rcx
 1141d70:	dec    %rax
 1141d73:	jne    1141d50 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x710>
 1141d75:	vmovups -0x70(%rbp),%ymm0
 1141d7a:	mov    -0x40(%rbp),%rax
 1141d7e:	vmovups %ymm0,0xe0(%rax)
 1141d86:	vmovups -0x90(%rbp),%ymm0
 1141d8e:	vmovups %ymm0,0xc0(%rax)
 1141d96:	vmovups -0xb0(%rbp),%ymm0
 1141d9e:	vmovups %ymm0,0xa0(%rax)
 1141da6:	vmovups -0xd0(%rbp),%ymm0
 1141dae:	vmovups %ymm0,0x80(%rax)
 1141db6:	vmovups -0x150(%rbp),%ymm0
 1141dbe:	vmovups -0x130(%rbp),%ymm1
 1141dc6:	vmovups -0x110(%rbp),%ymm2
 1141dce:	vmovups -0xf0(%rbp),%ymm3
 1141dd6:	vmovups %ymm3,0x60(%rax)
 1141ddb:	vmovups %ymm2,0x40(%rax)
 1141de0:	vmovups %ymm1,0x20(%rax)
 1141de5:	vmovups %ymm0,(%rax)
 1141de9:	add    $0x8c28,%rsp
 1141df0:	pop    %rbx
 1141df1:	pop    %r12
 1141df3:	pop    %r13
 1141df5:	pop    %r14
 1141df7:	pop    %r15
 1141df9:	pop    %rbp
 1141dfa:	vzeroupper 
 1141dfd:	ret    
 1141dfe:	mov    %rax,%rcx
 1141e01:	shl    $0x4,%rcx
 1141e05:	lea    -0x8c50(%rbp),%rdx
 1141e0c:	add    %rdx,%rcx
 1141e0f:	add    $0xfffffffffffffffa,%rcx
 1141e13:	jmp    1141e31 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x7f1>
 1141e15:	data16 cs nopw 0x0(%rax,%rax,1)
 1141e20:	add    $0xfffffffffffffffe,%rax
 1141e24:	add    $0xffffffffffffffe0,%rcx
 1141e28:	cmp    %r14,%rax
 1141e2b:	jbe    1141c3d <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x5fd>
 1141e31:	movzwl -0x1452(%rbp,%rax,2),%edx
 1141e39:	test   %dx,%dx
 1141e3c:	je     1141e55 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x815>
 1141e3e:	movzwl -0x2(%rcx),%esi
 1141e42:	movzwl (%rcx),%edi
 1141e45:	add    %dx,-0x1450(%rbp,%rsi,2)
 1141e4d:	add    %dx,-0x1450(%rbp,%rdi,2)
 1141e55:	movzwl -0x1454(%rbp,%rax,2),%edx
 1141e5d:	test   %dx,%dx
 1141e60:	je     1141e20 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x7e0>
 1141e62:	movzwl -0x12(%rcx),%esi
 1141e66:	movzwl -0x10(%rcx),%edi
 1141e6a:	add    %dx,-0x1450(%rbp,%rsi,2)
 1141e72:	add    %dx,-0x1450(%rbp,%rdi,2)
 1141e7a:	jmp    1141e20 <huffman.treeCodeLengthsMediumKnownActive__anon_38997+0x7e0>

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
