
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000118aa40 <huffman.treeCodeLengths__anon_40857>:
 118aa40:	55                   	push   %rbp
 118aa41:	48 89 e5             	mov    %rsp,%rbp
 118aa44:	41 57                	push   %r15
 118aa46:	41 56                	push   %r14
 118aa48:	41 55                	push   %r13
 118aa4a:	41 54                	push   %r12
 118aa4c:	53                   	push   %rbx
 118aa4d:	48 81 ec 78 26 01 00 	sub    $0x12678,%rsp
 118aa54:	89 55 a8             	mov    %edx,-0x58(%rbp)
 118aa57:	48 89 fb             	mov    %rdi,%rbx
 118aa5a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 118aa5e:	c5 fc 11 85 40 fc ff 	vmovups %ymm0,-0x3c0(%rbp)
 118aa65:	ff 
 118aa66:	c5 fc 11 85 20 fc ff 	vmovups %ymm0,-0x3e0(%rbp)
 118aa6d:	ff 
 118aa6e:	c5 fc 11 85 00 fc ff 	vmovups %ymm0,-0x400(%rbp)
 118aa75:	ff 
 118aa76:	c5 fc 11 85 e0 fb ff 	vmovups %ymm0,-0x420(%rbp)
 118aa7d:	ff 
 118aa7e:	c5 fc 11 85 c0 fb ff 	vmovups %ymm0,-0x440(%rbp)
 118aa85:	ff 
 118aa86:	c5 fc 11 85 a0 fb ff 	vmovups %ymm0,-0x460(%rbp)
 118aa8d:	ff 
 118aa8e:	c5 fc 11 85 80 fb ff 	vmovups %ymm0,-0x480(%rbp)
 118aa95:	ff 
 118aa96:	c5 fc 11 85 60 fb ff 	vmovups %ymm0,-0x4a0(%rbp)
 118aa9d:	ff 
 118aa9e:	48 8d bd 60 eb ff ff 	lea    -0x14a0(%rbp),%rdi
 118aaa5:	ba 00 04 00 00       	mov    $0x400,%edx
 118aaaa:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 118aaae:	c5 f8 77             	vzeroupper 
 118aab1:	e8 ea d1 10 00       	call   1297ca0 <compiler_rt.memcpy.memcpyFast>
 118aab6:	45 31 f6             	xor    %r14d,%r14d
 118aab9:	31 c0                	xor    %eax,%eax
 118aabb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 118aac0:	4c 89 f1             	mov    %r14,%rcx
 118aac3:	44 8b ac 85 60 eb ff 	mov    -0x14a0(%rbp,%rax,4),%r13d
 118aaca:	ff 
 118aacb:	44 8b a4 85 64 eb ff 	mov    -0x149c(%rbp,%rax,4),%r12d
 118aad2:	ff 
 118aad3:	41 83 fd 01          	cmp    $0x1,%r13d
 118aad7:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118aadb:	41 83 fc 01          	cmp    $0x1,%r12d
 118aadf:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118aae3:	44 8b 8c 85 68 eb ff 	mov    -0x1498(%rbp,%rax,4),%r9d
 118aaea:	ff 
 118aaeb:	41 83 f9 01          	cmp    $0x1,%r9d
 118aaef:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118aaf3:	44 8b 84 85 6c eb ff 	mov    -0x1494(%rbp,%rax,4),%r8d
 118aafa:	ff 
 118aafb:	41 83 f8 01          	cmp    $0x1,%r8d
 118aaff:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118ab03:	8b bc 85 70 eb ff ff 	mov    -0x1490(%rbp,%rax,4),%edi
 118ab0a:	83 ff 01             	cmp    $0x1,%edi
 118ab0d:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118ab11:	8b b4 85 74 eb ff ff 	mov    -0x148c(%rbp,%rax,4),%esi
 118ab18:	83 fe 01             	cmp    $0x1,%esi
 118ab1b:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118ab1f:	44 8b bc 85 78 eb ff 	mov    -0x1488(%rbp,%rax,4),%r15d
 118ab26:	ff 
 118ab27:	41 83 ff 01          	cmp    $0x1,%r15d
 118ab2b:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118ab2f:	8b 94 85 7c eb ff ff 	mov    -0x1484(%rbp,%rax,4),%edx
 118ab36:	83 fa 01             	cmp    $0x1,%edx
 118ab39:	49 83 de ff          	sbb    $0xffffffffffffffff,%r14
 118ab3d:	48 83 c0 08          	add    $0x8,%rax
 118ab41:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 118ab47:	0f 85 73 ff ff ff    	jne    118aac0 <huffman.treeCodeLengths__anon_40857+0x80>
 118ab4d:	4d 85 f6             	test   %r14,%r14
 118ab50:	0f 84 a5 00 00 00    	je     118abfb <huffman.treeCodeLengths__anon_40857+0x1bb>
 118ab56:	49 83 fe 01          	cmp    $0x1,%r14
 118ab5a:	0f 85 d3 00 00 00    	jne    118ac33 <huffman.treeCodeLengths__anon_40857+0x1f3>
 118ab60:	48 8d bd 60 e7 ff ff 	lea    -0x18a0(%rbp),%rdi
 118ab67:	ba 00 04 00 00       	mov    $0x400,%edx
 118ab6c:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 118ab70:	e8 2b d1 10 00       	call   1297ca0 <compiler_rt.memcpy.memcpyFast>
 118ab75:	b8 07 00 00 00       	mov    $0x7,%eax
 118ab7a:	83 bc 85 44 e7 ff ff 	cmpl   $0x0,-0x18bc(%rbp,%rax,4)
 118ab81:	00 
 118ab82:	0f 85 e0 0a 00 00    	jne    118b668 <huffman.treeCodeLengths__anon_40857+0xc28>
 118ab88:	83 bc 85 48 e7 ff ff 	cmpl   $0x0,-0x18b8(%rbp,%rax,4)
 118ab8f:	00 
 118ab90:	0f 85 18 11 00 00    	jne    118bcae <huffman.treeCodeLengths__anon_40857+0x126e>
 118ab96:	83 bc 85 4c e7 ff ff 	cmpl   $0x0,-0x18b4(%rbp,%rax,4)
 118ab9d:	00 
 118ab9e:	0f 85 10 11 00 00    	jne    118bcb4 <huffman.treeCodeLengths__anon_40857+0x1274>
 118aba4:	83 bc 85 50 e7 ff ff 	cmpl   $0x0,-0x18b0(%rbp,%rax,4)
 118abab:	00 
 118abac:	0f 85 08 11 00 00    	jne    118bcba <huffman.treeCodeLengths__anon_40857+0x127a>
 118abb2:	83 bc 85 54 e7 ff ff 	cmpl   $0x0,-0x18ac(%rbp,%rax,4)
 118abb9:	00 
 118abba:	0f 85 00 11 00 00    	jne    118bcc0 <huffman.treeCodeLengths__anon_40857+0x1280>
 118abc0:	83 bc 85 58 e7 ff ff 	cmpl   $0x0,-0x18a8(%rbp,%rax,4)
 118abc7:	00 
 118abc8:	0f 85 f8 10 00 00    	jne    118bcc6 <huffman.treeCodeLengths__anon_40857+0x1286>
 118abce:	83 bc 85 5c e7 ff ff 	cmpl   $0x0,-0x18a4(%rbp,%rax,4)
 118abd5:	00 
 118abd6:	0f 85 f0 10 00 00    	jne    118bccc <huffman.treeCodeLengths__anon_40857+0x128c>
 118abdc:	83 bc 85 60 e7 ff ff 	cmpl   $0x0,-0x18a0(%rbp,%rax,4)
 118abe3:	00 
 118abe4:	0f 85 e5 10 00 00    	jne    118bccf <huffman.treeCodeLengths__anon_40857+0x128f>
 118abea:	48 83 c0 08          	add    $0x8,%rax
 118abee:	48 3d 07 01 00 00    	cmp    $0x107,%rax
 118abf4:	75 84                	jne    118ab7a <huffman.treeCodeLengths__anon_40857+0x13a>
 118abf6:	e9 dc 10 00 00       	jmp    118bcd7 <huffman.treeCodeLengths__anon_40857+0x1297>
 118abfb:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 118abff:	c5 fc 11 83 e0 00 00 	vmovups %ymm0,0xe0(%rbx)
 118ac06:	00 
 118ac07:	c5 fc 11 83 c0 00 00 	vmovups %ymm0,0xc0(%rbx)
 118ac0e:	00 
 118ac0f:	c5 fc 11 83 a0 00 00 	vmovups %ymm0,0xa0(%rbx)
 118ac16:	00 
 118ac17:	c5 fc 11 83 80 00 00 	vmovups %ymm0,0x80(%rbx)
 118ac1e:	00 
 118ac1f:	c5 fc 11 43 60       	vmovups %ymm0,0x60(%rbx)
 118ac24:	c5 fc 11 43 40       	vmovups %ymm0,0x40(%rbx)
 118ac29:	c5 fc 11 43 20       	vmovups %ymm0,0x20(%rbx)
 118ac2e:	e9 13 11 00 00       	jmp    118bd46 <huffman.treeCodeLengths__anon_40857+0x1306>
 118ac33:	49 83 fe 21          	cmp    $0x21,%r14
 118ac37:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 118ac3b:	89 75 c8             	mov    %esi,-0x38(%rbp)
 118ac3e:	89 7d cc             	mov    %edi,-0x34(%rbp)
 118ac41:	44 89 45 d4          	mov    %r8d,-0x2c(%rbp)
 118ac45:	44 89 4d bc          	mov    %r9d,-0x44(%rbp)
 118ac49:	48 89 5d 98          	mov    %rbx,-0x68(%rbp)
 118ac4d:	89 55 c4             	mov    %edx,-0x3c(%rbp)
 118ac50:	44 89 7d c0          	mov    %r15d,-0x40(%rbp)
 118ac54:	0f 83 e9 00 00 00    	jae    118ad43 <huffman.treeCodeLengths__anon_40857+0x303>
 118ac5a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 118ac5e:	c5 fc 11 85 c0 c9 ff 	vmovups %ymm0,-0x3640(%rbp)
 118ac65:	ff 
 118ac66:	c5 fc 11 85 a0 c9 ff 	vmovups %ymm0,-0x3660(%rbp)
 118ac6d:	ff 
 118ac6e:	c5 fc 11 85 80 c9 ff 	vmovups %ymm0,-0x3680(%rbp)
 118ac75:	ff 
 118ac76:	c5 fc 11 85 60 c9 ff 	vmovups %ymm0,-0x36a0(%rbp)
 118ac7d:	ff 
 118ac7e:	48 8d bd 60 d9 fe ff 	lea    -0x126a0(%rbp),%rdi
 118ac85:	ba 00 04 00 00       	mov    $0x400,%edx
 118ac8a:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 118ac8e:	c5 f8 77             	vzeroupper 
 118ac91:	e8 0a d0 10 00       	call   1297ca0 <compiler_rt.memcpy.memcpyFast>
 118ac96:	44 8b 4d bc          	mov    -0x44(%rbp),%r9d
 118ac9a:	44 8b 45 d4          	mov    -0x2c(%rbp),%r8d
 118ac9e:	8b 7d cc             	mov    -0x34(%rbp),%edi
 118aca1:	8b 75 c8             	mov    -0x38(%rbp),%esi
 118aca4:	31 c0                	xor    %eax,%eax
 118aca6:	31 c9                	xor    %ecx,%ecx
 118aca8:	eb 17                	jmp    118acc1 <huffman.treeCodeLengths__anon_40857+0x281>
 118acaa:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 118acb0:	48 83 c1 04          	add    $0x4,%rcx
 118acb4:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 118acbb:	0f 84 92 01 00 00    	je     118ae53 <huffman.treeCodeLengths__anon_40857+0x413>
 118acc1:	8b 94 8d 60 d9 fe ff 	mov    -0x126a0(%rbp,%rcx,4),%edx
 118acc8:	85 d2                	test   %edx,%edx
 118acca:	74 12                	je     118acde <huffman.treeCodeLengths__anon_40857+0x29e>
 118accc:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118acd3:	66 89 8c 45 60 f7 ff 	mov    %cx,-0x8a0(%rbp,%rax,2)
 118acda:	ff 
 118acdb:	48 ff c0             	inc    %rax
 118acde:	8b 94 8d 64 d9 fe ff 	mov    -0x1269c(%rbp,%rcx,4),%edx
 118ace5:	85 d2                	test   %edx,%edx
 118ace7:	74 15                	je     118acfe <huffman.treeCodeLengths__anon_40857+0x2be>
 118ace9:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118acf0:	8d 51 01             	lea    0x1(%rcx),%edx
 118acf3:	66 89 94 45 60 f7 ff 	mov    %dx,-0x8a0(%rbp,%rax,2)
 118acfa:	ff 
 118acfb:	48 ff c0             	inc    %rax
 118acfe:	8b 94 8d 68 d9 fe ff 	mov    -0x12698(%rbp,%rcx,4),%edx
 118ad05:	85 d2                	test   %edx,%edx
 118ad07:	74 15                	je     118ad1e <huffman.treeCodeLengths__anon_40857+0x2de>
 118ad09:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118ad10:	8d 51 02             	lea    0x2(%rcx),%edx
 118ad13:	66 89 94 45 60 f7 ff 	mov    %dx,-0x8a0(%rbp,%rax,2)
 118ad1a:	ff 
 118ad1b:	48 ff c0             	inc    %rax
 118ad1e:	8b 94 8d 6c d9 fe ff 	mov    -0x12694(%rbp,%rcx,4),%edx
 118ad25:	85 d2                	test   %edx,%edx
 118ad27:	74 87                	je     118acb0 <huffman.treeCodeLengths__anon_40857+0x270>
 118ad29:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118ad30:	8d 51 03             	lea    0x3(%rcx),%edx
 118ad33:	66 89 94 45 60 f7 ff 	mov    %dx,-0x8a0(%rbp,%rax,2)
 118ad3a:	ff 
 118ad3b:	48 ff c0             	inc    %rax
 118ad3e:	e9 6d ff ff ff       	jmp    118acb0 <huffman.treeCodeLengths__anon_40857+0x270>
 118ad43:	49 83 fe 40          	cmp    $0x40,%r14
 118ad47:	0f 87 17 02 00 00    	ja     118af64 <huffman.treeCodeLengths__anon_40857+0x524>
 118ad4d:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 118ad51:	c5 fc 11 85 40 ca ff 	vmovups %ymm0,-0x35c0(%rbp)
 118ad58:	ff 
 118ad59:	c5 fc 11 85 20 ca ff 	vmovups %ymm0,-0x35e0(%rbp)
 118ad60:	ff 
 118ad61:	c5 fc 11 85 00 ca ff 	vmovups %ymm0,-0x3600(%rbp)
 118ad68:	ff 
 118ad69:	c5 fc 11 85 e0 c9 ff 	vmovups %ymm0,-0x3620(%rbp)
 118ad70:	ff 
 118ad71:	c5 fc 11 85 c0 c9 ff 	vmovups %ymm0,-0x3640(%rbp)
 118ad78:	ff 
 118ad79:	c5 fc 11 85 a0 c9 ff 	vmovups %ymm0,-0x3660(%rbp)
 118ad80:	ff 
 118ad81:	c5 fc 11 85 80 c9 ff 	vmovups %ymm0,-0x3680(%rbp)
 118ad88:	ff 
 118ad89:	c5 fc 11 85 60 c9 ff 	vmovups %ymm0,-0x36a0(%rbp)
 118ad90:	ff 
 118ad91:	48 8d bd 60 d9 fe ff 	lea    -0x126a0(%rbp),%rdi
 118ad98:	ba 00 04 00 00       	mov    $0x400,%edx
 118ad9d:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 118ada1:	c5 f8 77             	vzeroupper 
 118ada4:	e8 f7 ce 10 00       	call   1297ca0 <compiler_rt.memcpy.memcpyFast>
 118ada9:	31 c0                	xor    %eax,%eax
 118adab:	31 c9                	xor    %ecx,%ecx
 118adad:	8b 75 c8             	mov    -0x38(%rbp),%esi
 118adb0:	8b 7d cc             	mov    -0x34(%rbp),%edi
 118adb3:	44 8b 45 d4          	mov    -0x2c(%rbp),%r8d
 118adb7:	44 8b 4d bc          	mov    -0x44(%rbp),%r9d
 118adbb:	eb 14                	jmp    118add1 <huffman.treeCodeLengths__anon_40857+0x391>
 118adbd:	0f 1f 00             	nopl   (%rax)
 118adc0:	48 83 c1 04          	add    $0x4,%rcx
 118adc4:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 118adcb:	0f 84 4a 02 00 00    	je     118b01b <huffman.treeCodeLengths__anon_40857+0x5db>
 118add1:	8b 94 8d 60 d9 fe ff 	mov    -0x126a0(%rbp,%rcx,4),%edx
 118add8:	85 d2                	test   %edx,%edx
 118adda:	74 12                	je     118adee <huffman.treeCodeLengths__anon_40857+0x3ae>
 118addc:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118ade3:	66 89 8c 45 60 f7 ff 	mov    %cx,-0x8a0(%rbp,%rax,2)
 118adea:	ff 
 118adeb:	48 ff c0             	inc    %rax
 118adee:	8b 94 8d 64 d9 fe ff 	mov    -0x1269c(%rbp,%rcx,4),%edx
 118adf5:	85 d2                	test   %edx,%edx
 118adf7:	74 15                	je     118ae0e <huffman.treeCodeLengths__anon_40857+0x3ce>
 118adf9:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118ae00:	8d 51 01             	lea    0x1(%rcx),%edx
 118ae03:	66 89 94 45 60 f7 ff 	mov    %dx,-0x8a0(%rbp,%rax,2)
 118ae0a:	ff 
 118ae0b:	48 ff c0             	inc    %rax
 118ae0e:	8b 94 8d 68 d9 fe ff 	mov    -0x12698(%rbp,%rcx,4),%edx
 118ae15:	85 d2                	test   %edx,%edx
 118ae17:	74 15                	je     118ae2e <huffman.treeCodeLengths__anon_40857+0x3ee>
 118ae19:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118ae20:	8d 51 02             	lea    0x2(%rcx),%edx
 118ae23:	66 89 94 45 60 f7 ff 	mov    %dx,-0x8a0(%rbp,%rax,2)
 118ae2a:	ff 
 118ae2b:	48 ff c0             	inc    %rax
 118ae2e:	8b 94 8d 6c d9 fe ff 	mov    -0x12694(%rbp,%rcx,4),%edx
 118ae35:	85 d2                	test   %edx,%edx
 118ae37:	74 87                	je     118adc0 <huffman.treeCodeLengths__anon_40857+0x380>
 118ae39:	89 94 85 60 c9 ff ff 	mov    %edx,-0x36a0(%rbp,%rax,4)
 118ae40:	8d 51 03             	lea    0x3(%rcx),%edx
 118ae43:	66 89 94 45 60 f7 ff 	mov    %dx,-0x8a0(%rbp,%rax,2)
 118ae4a:	ff 
 118ae4b:	48 ff c0             	inc    %rax
 118ae4e:	e9 6d ff ff ff       	jmp    118adc0 <huffman.treeCodeLengths__anon_40857+0x380>
 118ae53:	45 31 ff             	xor    %r15d,%r15d
 118ae56:	83 7d c4 00          	cmpl   $0x0,-0x3c(%rbp)
 118ae5a:	41 0f 95 c7          	setne  %r15b
 118ae5e:	31 c0                	xor    %eax,%eax
 118ae60:	83 7d c0 00          	cmpl   $0x0,-0x40(%rbp)
 118ae64:	0f 95 c0             	setne  %al
 118ae67:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 118ae6b:	31 c0                	xor    %eax,%eax
 118ae6d:	85 f6                	test   %esi,%esi
 118ae6f:	0f 95 c0             	setne  %al
 118ae72:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 118ae76:	31 c0                	xor    %eax,%eax
 118ae78:	85 ff                	test   %edi,%edi
 118ae7a:	0f 95 c0             	setne  %al
 118ae7d:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 118ae84:	31 c0                	xor    %eax,%eax
 118ae86:	45 85 c0             	test   %r8d,%r8d
 118ae89:	0f 95 c0             	setne  %al
 118ae8c:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 118ae93:	31 c0                	xor    %eax,%eax
 118ae95:	45 85 c9             	test   %r9d,%r9d
 118ae98:	0f 95 c0             	setne  %al
 118ae9b:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 118ae9f:	31 c0                	xor    %eax,%eax
 118aea1:	45 85 e4             	test   %r12d,%r12d
 118aea4:	0f 95 c0             	setne  %al
 118aea7:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 118aeab:	31 db                	xor    %ebx,%ebx
 118aead:	45 85 ed             	test   %r13d,%r13d
 118aeb0:	0f 95 c3             	setne  %bl
 118aeb3:	0f b6 55 a8          	movzbl -0x58(%rbp),%edx
 118aeb7:	48 8d bd 60 f3 ff ff 	lea    -0xca0(%rbp),%rdi
 118aebe:	48 8d b5 60 c9 ff ff 	lea    -0x36a0(%rbp),%rsi
 118aec5:	4c 89 f1             	mov    %r14,%rcx
 118aec8:	e8 f3 5b 01 00       	call   11a0ac0 <huffman.packageMergeCodeLengths__anon_41113>
 118aecd:	49 89 db             	mov    %rbx,%r11
 118aed0:	4c 8b 55 88          	mov    -0x78(%rbp),%r10
 118aed4:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 118aedb:	4c 8b 45 80          	mov    -0x80(%rbp),%r8
 118aedf:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 118aee6:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 118aeea:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 118aeee:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 118aef5:	ff 
 118aef6:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 118aefd:	ff 
 118aefe:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 118af05:	ff 
 118af06:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 118af0d:	ff 
 118af0e:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 118af15:	ff 
 118af16:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 118af1d:	ff 
 118af1e:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 118af25:	ff 
 118af26:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 118af2d:	ff 
 118af2e:	48 8b 7d 90          	mov    -0x70(%rbp),%rdi
 118af32:	4b 8d 0c 02          	lea    (%r10,%r8,1),%rcx
 118af36:	48 01 f9             	add    %rdi,%rcx
 118af39:	48 01 d9             	add    %rbx,%rcx
 118af3c:	49 8d 04 31          	lea    (%r9,%rsi,1),%rax
 118af40:	48 01 d0             	add    %rdx,%rax
 118af43:	48 01 c8             	add    %rcx,%rax
 118af46:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 118af4a:	48 01 d8             	add    %rbx,%rax
 118af4d:	4c 01 f8             	add    %r15,%rax
 118af50:	48 ff c8             	dec    %rax
 118af53:	48 83 f8 07          	cmp    $0x7,%rax
 118af57:	0f 83 cf 01 00 00    	jae    118b12c <huffman.treeCodeLengths__anon_40857+0x6ec>
 118af5d:	31 c0                	xor    %eax,%eax
 118af5f:	e9 cb 02 00 00       	jmp    118b22f <huffman.treeCodeLengths__anon_40857+0x7ef>
 118af64:	48 8d bd 60 f3 ff ff 	lea    -0xca0(%rbp),%rdi
 118af6b:	ba 00 04 00 00       	mov    $0x400,%edx
 118af70:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 118af74:	e8 27 cd 10 00       	call   1297ca0 <compiler_rt.memcpy.memcpyFast>
 118af79:	31 c0                	xor    %eax,%eax
 118af7b:	31 c9                	xor    %ecx,%ecx
 118af7d:	eb 12                	jmp    118af91 <huffman.treeCodeLengths__anon_40857+0x551>
 118af7f:	90                   	nop
 118af80:	48 83 c1 02          	add    $0x2,%rcx
 118af84:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 118af8b:	0f 84 95 03 00 00    	je     118b326 <huffman.treeCodeLengths__anon_40857+0x8e6>
 118af91:	8b 94 8d 60 f3 ff ff 	mov    -0xca0(%rbp,%rcx,4),%edx
 118af98:	48 85 d2             	test   %rdx,%rdx
 118af9b:	74 35                	je     118afd2 <huffman.treeCodeLengths__anon_40857+0x592>
 118af9d:	48 89 c6             	mov    %rax,%rsi
 118afa0:	48 c1 e6 04          	shl    $0x4,%rsi
 118afa4:	48 89 94 35 60 d9 fe 	mov    %rdx,-0x126a0(%rbp,%rsi,1)
 118afab:	ff 
 118afac:	66 89 8c 35 6c d9 fe 	mov    %cx,-0x12694(%rbp,%rsi,1)
 118afb3:	ff 
 118afb4:	66 89 84 35 6e d9 fe 	mov    %ax,-0x12692(%rbp,%rsi,1)
 118afbb:	ff 
 118afbc:	c7 84 35 68 d9 fe ff 	movl   $0xffffffff,-0x12698(%rbp,%rsi,1)
 118afc3:	ff ff ff ff 
 118afc7:	66 89 84 45 60 f1 ff 	mov    %ax,-0xea0(%rbp,%rax,2)
 118afce:	ff 
 118afcf:	48 ff c0             	inc    %rax
 118afd2:	8b 94 8d 64 f3 ff ff 	mov    -0xc9c(%rbp,%rcx,4),%edx
 118afd9:	48 85 d2             	test   %rdx,%rdx
 118afdc:	74 a2                	je     118af80 <huffman.treeCodeLengths__anon_40857+0x540>
 118afde:	48 89 c6             	mov    %rax,%rsi
 118afe1:	48 c1 e6 04          	shl    $0x4,%rsi
 118afe5:	48 89 94 35 60 d9 fe 	mov    %rdx,-0x126a0(%rbp,%rsi,1)
 118afec:	ff 
 118afed:	8d 51 01             	lea    0x1(%rcx),%edx
 118aff0:	66 89 94 35 6c d9 fe 	mov    %dx,-0x12694(%rbp,%rsi,1)
 118aff7:	ff 
 118aff8:	66 89 84 35 6e d9 fe 	mov    %ax,-0x12692(%rbp,%rsi,1)
 118afff:	ff 
 118b000:	c7 84 35 68 d9 fe ff 	movl   $0xffffffff,-0x12698(%rbp,%rsi,1)
 118b007:	ff ff ff ff 
 118b00b:	66 89 84 45 60 f1 ff 	mov    %ax,-0xea0(%rbp,%rax,2)
 118b012:	ff 
 118b013:	48 ff c0             	inc    %rax
 118b016:	e9 65 ff ff ff       	jmp    118af80 <huffman.treeCodeLengths__anon_40857+0x540>
 118b01b:	45 31 ff             	xor    %r15d,%r15d
 118b01e:	83 7d c4 00          	cmpl   $0x0,-0x3c(%rbp)
 118b022:	41 0f 95 c7          	setne  %r15b
 118b026:	31 c0                	xor    %eax,%eax
 118b028:	83 7d c0 00          	cmpl   $0x0,-0x40(%rbp)
 118b02c:	0f 95 c0             	setne  %al
 118b02f:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 118b033:	31 c0                	xor    %eax,%eax
 118b035:	85 f6                	test   %esi,%esi
 118b037:	0f 95 c0             	setne  %al
 118b03a:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 118b03e:	31 c0                	xor    %eax,%eax
 118b040:	85 ff                	test   %edi,%edi
 118b042:	0f 95 c0             	setne  %al
 118b045:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 118b04c:	31 c0                	xor    %eax,%eax
 118b04e:	45 85 c0             	test   %r8d,%r8d
 118b051:	0f 95 c0             	setne  %al
 118b054:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 118b05b:	31 c0                	xor    %eax,%eax
 118b05d:	45 85 c9             	test   %r9d,%r9d
 118b060:	0f 95 c0             	setne  %al
 118b063:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 118b067:	31 c0                	xor    %eax,%eax
 118b069:	45 85 e4             	test   %r12d,%r12d
 118b06c:	0f 95 c0             	setne  %al
 118b06f:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 118b073:	31 db                	xor    %ebx,%ebx
 118b075:	45 85 ed             	test   %r13d,%r13d
 118b078:	0f 95 c3             	setne  %bl
 118b07b:	0f b6 55 a8          	movzbl -0x58(%rbp),%edx
 118b07f:	48 8d bd 60 f3 ff ff 	lea    -0xca0(%rbp),%rdi
 118b086:	48 8d b5 60 c9 ff ff 	lea    -0x36a0(%rbp),%rsi
 118b08d:	4c 89 f1             	mov    %r14,%rcx
 118b090:	e8 9b bd 00 00       	call   1196e30 <huffman.packageMergeCodeLengths__anon_40950>
 118b095:	49 89 db             	mov    %rbx,%r11
 118b098:	4c 8b 55 88          	mov    -0x78(%rbp),%r10
 118b09c:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 118b0a3:	4c 8b 45 80          	mov    -0x80(%rbp),%r8
 118b0a7:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 118b0ae:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 118b0b2:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 118b0b6:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 118b0bd:	ff 
 118b0be:	c5 fc 11 85 20 fe ff 	vmovups %ymm0,-0x1e0(%rbp)
 118b0c5:	ff 
 118b0c6:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 118b0cd:	ff 
 118b0ce:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 118b0d5:	ff 
 118b0d6:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 118b0dd:	ff 
 118b0de:	c5 fc 11 85 a0 fd ff 	vmovups %ymm0,-0x260(%rbp)
 118b0e5:	ff 
 118b0e6:	c5 fc 11 85 80 fd ff 	vmovups %ymm0,-0x280(%rbp)
 118b0ed:	ff 
 118b0ee:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 118b0f5:	ff 
 118b0f6:	48 8b 7d 90          	mov    -0x70(%rbp),%rdi
 118b0fa:	4b 8d 0c 02          	lea    (%r10,%r8,1),%rcx
 118b0fe:	48 01 f9             	add    %rdi,%rcx
 118b101:	48 01 d9             	add    %rbx,%rcx
 118b104:	49 8d 04 31          	lea    (%r9,%rsi,1),%rax
 118b108:	48 01 d0             	add    %rdx,%rax
 118b10b:	48 01 c8             	add    %rcx,%rax
 118b10e:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 118b112:	48 01 d8             	add    %rbx,%rax
 118b115:	4c 01 f8             	add    %r15,%rax
 118b118:	48 ff c8             	dec    %rax
 118b11b:	48 83 f8 07          	cmp    $0x7,%rax
 118b11f:	0f 83 4c 05 00 00    	jae    118b671 <huffman.treeCodeLengths__anon_40857+0xc31>
 118b125:	31 c0                	xor    %eax,%eax
 118b127:	e9 43 06 00 00       	jmp    118b76f <huffman.treeCodeLengths__anon_40857+0xd2f>
 118b12c:	41 01 fb             	add    %edi,%r11d
 118b12f:	45 01 d0             	add    %r10d,%r8d
 118b132:	45 01 d8             	add    %r11d,%r8d
 118b135:	44 01 ce             	add    %r9d,%esi
 118b138:	01 f2                	add    %esi,%edx
 118b13a:	44 01 c2             	add    %r8d,%edx
 118b13d:	41 01 df             	add    %ebx,%r15d
 118b140:	41 01 d7             	add    %edx,%r15d
 118b143:	41 83 e7 38          	and    $0x38,%r15d
 118b147:	31 c0                	xor    %eax,%eax
 118b149:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 118b150:	0f b7 8c 45 60 f7 ff 	movzwl -0x8a0(%rbp,%rax,2),%ecx
 118b157:	ff 
 118b158:	0f b6 94 05 60 f3 ff 	movzbl -0xca0(%rbp,%rax,1),%edx
 118b15f:	ff 
 118b160:	0f b6 b4 05 61 f3 ff 	movzbl -0xc9f(%rbp,%rax,1),%esi
 118b167:	ff 
 118b168:	80 e2 0f             	and    $0xf,%dl
 118b16b:	88 94 0d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rcx,1)
 118b172:	0f b7 8c 45 62 f7 ff 	movzwl -0x89e(%rbp,%rax,2),%ecx
 118b179:	ff 
 118b17a:	40 80 e6 0f          	and    $0xf,%sil
 118b17e:	40 88 b4 0d 60 fe ff 	mov    %sil,-0x1a0(%rbp,%rcx,1)
 118b185:	ff 
 118b186:	0f b7 8c 45 64 f7 ff 	movzwl -0x89c(%rbp,%rax,2),%ecx
 118b18d:	ff 
 118b18e:	0f b6 94 05 62 f3 ff 	movzbl -0xc9e(%rbp,%rax,1),%edx
 118b195:	ff 
 118b196:	80 e2 0f             	and    $0xf,%dl
 118b199:	88 94 0d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rcx,1)
 118b1a0:	0f b7 8c 45 66 f7 ff 	movzwl -0x89a(%rbp,%rax,2),%ecx
 118b1a7:	ff 
 118b1a8:	0f b6 94 05 63 f3 ff 	movzbl -0xc9d(%rbp,%rax,1),%edx
 118b1af:	ff 
 118b1b0:	80 e2 0f             	and    $0xf,%dl
 118b1b3:	88 94 0d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rcx,1)
 118b1ba:	0f b7 8c 45 68 f7 ff 	movzwl -0x898(%rbp,%rax,2),%ecx
 118b1c1:	ff 
 118b1c2:	0f b6 94 05 64 f3 ff 	movzbl -0xc9c(%rbp,%rax,1),%edx
 118b1c9:	ff 
 118b1ca:	80 e2 0f             	and    $0xf,%dl
 118b1cd:	88 94 0d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rcx,1)
 118b1d4:	0f b7 8c 45 6a f7 ff 	movzwl -0x896(%rbp,%rax,2),%ecx
 118b1db:	ff 
 118b1dc:	0f b6 94 05 65 f3 ff 	movzbl -0xc9b(%rbp,%rax,1),%edx
 118b1e3:	ff 
 118b1e4:	80 e2 0f             	and    $0xf,%dl
 118b1e7:	88 94 0d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rcx,1)
 118b1ee:	0f b7 8c 45 6c f7 ff 	movzwl -0x894(%rbp,%rax,2),%ecx
 118b1f5:	ff 
 118b1f6:	0f b6 94 05 66 f3 ff 	movzbl -0xc9a(%rbp,%rax,1),%edx
 118b1fd:	ff 
 118b1fe:	80 e2 0f             	and    $0xf,%dl
 118b201:	88 94 0d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rcx,1)
 118b208:	0f b7 8c 45 6e f7 ff 	movzwl -0x892(%rbp,%rax,2),%ecx
 118b20f:	ff 
 118b210:	0f b6 94 05 67 f3 ff 	movzbl -0xc99(%rbp,%rax,1),%edx
 118b217:	ff 
 118b218:	80 e2 0f             	and    $0xf,%dl
 118b21b:	88 94 0d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rcx,1)
 118b222:	48 83 c0 08          	add    $0x8,%rax
 118b226:	49 39 c7             	cmp    %rax,%r15
 118b229:	0f 85 21 ff ff ff    	jne    118b150 <huffman.treeCodeLengths__anon_40857+0x710>
 118b22f:	41 f6 c6 07          	test   $0x7,%r14b
 118b233:	8b 75 d4             	mov    -0x2c(%rbp),%esi
 118b236:	44 8b 45 bc          	mov    -0x44(%rbp),%r8d
 118b23a:	0f 84 7d 00 00 00    	je     118b2bd <huffman.treeCodeLengths__anon_40857+0x87d>
 118b240:	45 85 ed             	test   %r13d,%r13d
 118b243:	0f 95 c2             	setne  %dl
 118b246:	48 8d 0c 28          	lea    (%rax,%rbp,1),%rcx
 118b24a:	48 81 c1 60 f3 ff ff 	add    $0xfffffffffffff360,%rcx
 118b251:	48 8d 04 45 60 f7 ff 	lea    -0x8a0(,%rax,2),%rax
 118b258:	ff 
 118b259:	48 01 e8             	add    %rbp,%rax
 118b25c:	41 83 fc 01          	cmp    $0x1,%r12d
 118b260:	80 da ff             	sbb    $0xff,%dl
 118b263:	41 83 f8 01          	cmp    $0x1,%r8d
 118b267:	80 da ff             	sbb    $0xff,%dl
 118b26a:	83 fe 01             	cmp    $0x1,%esi
 118b26d:	80 da ff             	sbb    $0xff,%dl
 118b270:	83 7d cc 01          	cmpl   $0x1,-0x34(%rbp)
 118b274:	80 da ff             	sbb    $0xff,%dl
 118b277:	83 7d c8 01          	cmpl   $0x1,-0x38(%rbp)
 118b27b:	80 da ff             	sbb    $0xff,%dl
 118b27e:	83 7d c0 01          	cmpl   $0x1,-0x40(%rbp)
 118b282:	80 da ff             	sbb    $0xff,%dl
 118b285:	83 7d c4 01          	cmpl   $0x1,-0x3c(%rbp)
 118b289:	80 da ff             	sbb    $0xff,%dl
 118b28c:	40 00 d7             	add    %dl,%dil
 118b28f:	40 0f b6 d7          	movzbl %dil,%edx
 118b293:	83 e2 07             	and    $0x7,%edx
 118b296:	31 f6                	xor    %esi,%esi
 118b298:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 118b29f:	00 
 118b2a0:	0f b7 3c 70          	movzwl (%rax,%rsi,2),%edi
 118b2a4:	44 0f b6 04 31       	movzbl (%rcx,%rsi,1),%r8d
 118b2a9:	41 80 e0 0f          	and    $0xf,%r8b
 118b2ad:	44 88 84 3d 60 fe ff 	mov    %r8b,-0x1a0(%rbp,%rdi,1)
 118b2b4:	ff 
 118b2b5:	48 ff c6             	inc    %rsi
 118b2b8:	48 39 f2             	cmp    %rsi,%rdx
 118b2bb:	75 e3                	jne    118b2a0 <huffman.treeCodeLengths__anon_40857+0x860>
 118b2bd:	c5 fc 10 85 40 ff ff 	vmovups -0xc0(%rbp),%ymm0
 118b2c4:	ff 
 118b2c5:	48 8b 5d 98          	mov    -0x68(%rbp),%rbx
 118b2c9:	c5 fc 11 83 e0 00 00 	vmovups %ymm0,0xe0(%rbx)
 118b2d0:	00 
 118b2d1:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 118b2d8:	ff 
 118b2d9:	c5 fc 11 83 c0 00 00 	vmovups %ymm0,0xc0(%rbx)
 118b2e0:	00 
 118b2e1:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 118b2e8:	ff 
 118b2e9:	c5 fc 11 83 a0 00 00 	vmovups %ymm0,0xa0(%rbx)
 118b2f0:	00 
 118b2f1:	c5 fc 10 85 e0 fe ff 	vmovups -0x120(%rbp),%ymm0
 118b2f8:	ff 
 118b2f9:	c5 fc 11 83 80 00 00 	vmovups %ymm0,0x80(%rbx)
 118b300:	00 
 118b301:	c5 fc 10 85 60 fe ff 	vmovups -0x1a0(%rbp),%ymm0
 118b308:	ff 
 118b309:	c5 fc 10 8d 80 fe ff 	vmovups -0x180(%rbp),%ymm1
 118b310:	ff 
 118b311:	c5 fc 10 95 a0 fe ff 	vmovups -0x160(%rbp),%ymm2
 118b318:	ff 
 118b319:	c5 fc 10 9d c0 fe ff 	vmovups -0x140(%rbp),%ymm3
 118b320:	ff 
 118b321:	e9 11 0a 00 00       	jmp    118bd37 <huffman.treeCodeLengths__anon_40857+0x12f7>
 118b326:	48 8d 85 60 d9 fe ff 	lea    -0x126a0(%rbp),%rax
 118b32d:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 118b334:	4c 89 b5 68 ff ff ff 	mov    %r14,-0x98(%rbp)
 118b33b:	4c 8d bd 60 f1 ff ff 	lea    -0xea0(%rbp),%r15
 118b342:	48 8d 95 60 ff ff ff 	lea    -0xa0(%rbp),%rdx
 118b349:	4c 89 ff             	mov    %r15,%rdi
 118b34c:	4c 89 f6             	mov    %r14,%rsi
 118b34f:	e8 8c 0a 00 00       	call   118bde0 <sort.block.block__anon_40944>
 118b354:	4b 8d 1c 36          	lea    (%r14,%r14,1),%rbx
 118b358:	48 8d bd 60 f7 ff ff 	lea    -0x8a0(%rbp),%rdi
 118b35f:	4c 89 fe             	mov    %r15,%rsi
 118b362:	48 89 da             	mov    %rbx,%rdx
 118b365:	e8 36 c9 10 00       	call   1297ca0 <compiler_rt.memcpy.memcpyFast>
 118b36a:	c6 45 d3 01          	movb   $0x1,-0x2d(%rbp)
 118b36e:	8b 45 a8             	mov    -0x58(%rbp),%eax
 118b371:	24 0f                	and    $0xf,%al
 118b373:	48 89 5d a0          	mov    %rbx,-0x60(%rbp)
 118b377:	48 89 da             	mov    %rbx,%rdx
 118b37a:	4d 89 f7             	mov    %r14,%r15
 118b37d:	89 45 a8             	mov    %eax,-0x58(%rbp)
 118b380:	3c 01                	cmp    $0x1,%al
 118b382:	0f 86 e2 04 00 00    	jbe    118b86a <huffman.treeCodeLengths__anon_40857+0xe2a>
 118b388:	b0 01                	mov    $0x1,%al
 118b38a:	4d 89 f7             	mov    %r14,%r15
 118b38d:	4c 89 f6             	mov    %r14,%rsi
 118b390:	eb 22                	jmp    118b3b4 <huffman.treeCodeLengths__anon_40857+0x974>
 118b392:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 118b399:	1f 84 00 00 00 00 00 
 118b3a0:	0f b6 45 b0          	movzbl -0x50(%rbp),%eax
 118b3a4:	fe c0                	inc    %al
 118b3a6:	24 0f                	and    $0xf,%al
 118b3a8:	88 45 d3             	mov    %al,-0x2d(%rbp)
 118b3ab:	38 45 a8             	cmp    %al,-0x58(%rbp)
 118b3ae:	0f 86 b2 04 00 00    	jbe    118b866 <huffman.treeCodeLengths__anon_40857+0xe26>
 118b3b4:	88 45 b0             	mov    %al,-0x50(%rbp)
 118b3b7:	48 83 fe 02          	cmp    $0x2,%rsi
 118b3bb:	72 33                	jb     118b3f0 <huffman.treeCodeLengths__anon_40857+0x9b0>
 118b3bd:	48 83 c6 fe          	add    $0xfffffffffffffffe,%rsi
 118b3c1:	48 89 f2             	mov    %rsi,%rdx
 118b3c4:	48 d1 ea             	shr    %rdx
 118b3c7:	48 83 fe 02          	cmp    $0x2,%rsi
 118b3cb:	73 33                	jae    118b400 <huffman.treeCodeLengths__anon_40857+0x9c0>
 118b3cd:	31 ff                	xor    %edi,%edi
 118b3cf:	45 31 c0             	xor    %r8d,%r8d
 118b3d2:	40 f6 c6 02          	test   $0x2,%sil
 118b3d6:	0f 84 20 01 00 00    	je     118b4fc <huffman.treeCodeLengths__anon_40857+0xabc>
 118b3dc:	e9 89 01 00 00       	jmp    118b56a <huffman.treeCodeLengths__anon_40857+0xb2a>
 118b3e1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 118b3e8:	0f 1f 84 00 00 00 00 
 118b3ef:	00 
 118b3f0:	31 d2                	xor    %edx,%edx
 118b3f2:	e9 76 01 00 00       	jmp    118b56d <huffman.treeCodeLengths__anon_40857+0xb2d>
 118b3f7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 118b3fe:	00 00 
 118b400:	4c 8d 4a 01          	lea    0x1(%rdx),%r9
 118b404:	4d 89 fa             	mov    %r15,%r10
 118b407:	49 c1 e2 04          	shl    $0x4,%r10
 118b40b:	48 8d 85 7e d9 fe ff 	lea    -0x12682(%rbp),%rax
 118b412:	49 01 c2             	add    %rax,%r10
 118b415:	49 83 e1 fe          	and    $0xfffffffffffffffe,%r9
 118b419:	49 f7 d9             	neg    %r9
 118b41c:	31 ff                	xor    %edi,%edi
 118b41e:	45 31 c0             	xor    %r8d,%r8d
 118b421:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 118b428:	0f 1f 84 00 00 00 00 
 118b42f:	00 
 118b430:	42 0f b7 8c 45 60 f7 	movzwl -0x8a0(%rbp,%r8,2),%ecx
 118b437:	ff ff 
 118b439:	46 0f b7 9c 45 62 f7 	movzwl -0x89e(%rbp,%r8,2),%r11d
 118b440:	ff ff 
 118b442:	89 cb                	mov    %ecx,%ebx
 118b444:	c1 e3 04             	shl    $0x4,%ebx
 118b447:	44 89 d8             	mov    %r11d,%eax
 118b44a:	c1 e0 04             	shl    $0x4,%eax
 118b44d:	48 8b 84 05 60 d9 fe 	mov    -0x126a0(%rbp,%rax,1),%rax
 118b454:	ff 
 118b455:	48 03 84 1d 60 d9 fe 	add    -0x126a0(%rbp,%rbx,1),%rax
 118b45c:	ff 
 118b45d:	4b 89 44 c2 e2       	mov    %rax,-0x1e(%r10,%r8,8)
 118b462:	66 43 89 4c c2 ea    	mov    %cx,-0x16(%r10,%r8,8)
 118b468:	66 47 89 5c c2 ec    	mov    %r11w,-0x14(%r10,%r8,8)
 118b46e:	66 47 89 7c c2 f0    	mov    %r15w,-0x10(%r10,%r8,8)
 118b474:	66 43 c7 44 c2 ee ff 	movw   $0xffff,-0x12(%r10,%r8,8)
 118b47b:	ff 
 118b47c:	42 0f b7 84 45 64 f7 	movzwl -0x89c(%rbp,%r8,2),%eax
 118b483:	ff ff 
 118b485:	42 0f b7 8c 45 66 f7 	movzwl -0x89a(%rbp,%r8,2),%ecx
 118b48c:	ff ff 
 118b48e:	41 89 c3             	mov    %eax,%r11d
 118b491:	41 c1 e3 04          	shl    $0x4,%r11d
 118b495:	89 cb                	mov    %ecx,%ebx
 118b497:	c1 e3 04             	shl    $0x4,%ebx
 118b49a:	48 8b 9c 1d 60 d9 fe 	mov    -0x126a0(%rbp,%rbx,1),%rbx
 118b4a1:	ff 
 118b4a2:	4a 03 9c 1d 60 d9 fe 	add    -0x126a0(%rbp,%r11,1),%rbx
 118b4a9:	ff 
 118b4aa:	66 46 89 bc 05 60 ef 	mov    %r15w,-0x10a0(%rbp,%r8,1)
 118b4b1:	ff ff 
 118b4b3:	4b 89 5c c2 f2       	mov    %rbx,-0xe(%r10,%r8,8)
 118b4b8:	66 43 89 44 c2 fa    	mov    %ax,-0x6(%r10,%r8,8)
 118b4be:	66 43 89 4c c2 fc    	mov    %cx,-0x4(%r10,%r8,8)
 118b4c4:	41 8d 47 01          	lea    0x1(%r15),%eax
 118b4c8:	66 43 89 04 c2       	mov    %ax,(%r10,%r8,8)
 118b4cd:	66 43 c7 44 c2 fe ff 	movw   $0xffff,-0x2(%r10,%r8,8)
 118b4d4:	ff 
 118b4d5:	49 83 c7 02          	add    $0x2,%r15
 118b4d9:	66 42 89 84 05 62 ef 	mov    %ax,-0x109e(%rbp,%r8,1)
 118b4e0:	ff ff 
 118b4e2:	49 83 c0 04          	add    $0x4,%r8
 118b4e6:	48 83 c7 fe          	add    $0xfffffffffffffffe,%rdi
 118b4ea:	49 39 f9             	cmp    %rdi,%r9
 118b4ed:	0f 85 3d ff ff ff    	jne    118b430 <huffman.treeCodeLengths__anon_40857+0x9f0>
 118b4f3:	48 f7 df             	neg    %rdi
 118b4f6:	40 f6 c6 02          	test   $0x2,%sil
 118b4fa:	75 6e                	jne    118b56a <huffman.treeCodeLengths__anon_40857+0xb2a>
 118b4fc:	42 0f b7 84 45 60 f7 	movzwl -0x8a0(%rbp,%r8,2),%eax
 118b503:	ff ff 
 118b505:	42 0f b7 8c 45 62 f7 	movzwl -0x89e(%rbp,%r8,2),%ecx
 118b50c:	ff ff 
 118b50e:	4c 89 fe             	mov    %r15,%rsi
 118b511:	48 c1 e6 04          	shl    $0x4,%rsi
 118b515:	41 89 c0             	mov    %eax,%r8d
 118b518:	41 c1 e0 04          	shl    $0x4,%r8d
 118b51c:	41 89 c9             	mov    %ecx,%r9d
 118b51f:	41 c1 e1 04          	shl    $0x4,%r9d
 118b523:	4e 8b 8c 0d 60 d9 fe 	mov    -0x126a0(%rbp,%r9,1),%r9
 118b52a:	ff 
 118b52b:	4e 03 8c 05 60 d9 fe 	add    -0x126a0(%rbp,%r8,1),%r9
 118b532:	ff 
 118b533:	4c 89 8c 35 60 d9 fe 	mov    %r9,-0x126a0(%rbp,%rsi,1)
 118b53a:	ff 
 118b53b:	66 89 84 35 68 d9 fe 	mov    %ax,-0x12698(%rbp,%rsi,1)
 118b542:	ff 
 118b543:	66 89 8c 35 6a d9 fe 	mov    %cx,-0x12696(%rbp,%rsi,1)
 118b54a:	ff 
 118b54b:	66 44 89 bc 35 6e d9 	mov    %r15w,-0x12692(%rbp,%rsi,1)
 118b552:	fe ff 
 118b554:	66 c7 84 35 6c d9 fe 	movw   $0xffff,-0x12694(%rbp,%rsi,1)
 118b55b:	ff ff ff 
 118b55e:	66 44 89 bc 7d 60 ef 	mov    %r15w,-0x10a0(%rbp,%rdi,2)
 118b565:	ff ff 
 118b567:	49 ff c7             	inc    %r15
 118b56a:	48 ff c2             	inc    %rdx
 118b56d:	48 85 d2             	test   %rdx,%rdx
 118b570:	41 0f 95 c2          	setne  %r10b
 118b574:	41 b3 01             	mov    $0x1,%r11b
 118b577:	48 8d bd 60 f7 ff ff 	lea    -0x8a0(%rbp),%rdi
 118b57e:	45 31 c0             	xor    %r8d,%r8d
 118b581:	45 31 c9             	xor    %r9d,%r9d
 118b584:	31 f6                	xor    %esi,%esi
 118b586:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 118b58d:	00 00 00 
 118b590:	41 f6 c2 01          	test   $0x1,%r10b
 118b594:	74 6a                	je     118b600 <huffman.treeCodeLengths__anon_40857+0xbc0>
 118b596:	41 f6 c3 01          	test   $0x1,%r11b
 118b59a:	0f 84 80 00 00 00    	je     118b620 <huffman.treeCodeLengths__anon_40857+0xbe0>
 118b5a0:	46 0f b7 94 4d 60 f1 	movzwl -0xea0(%rbp,%r9,2),%r10d
 118b5a7:	ff ff 
 118b5a9:	46 0f b7 9c 45 60 ef 	movzwl -0x10a0(%rbp,%r8,2),%r11d
 118b5b0:	ff ff 
 118b5b2:	44 89 d3             	mov    %r10d,%ebx
 118b5b5:	c1 e3 04             	shl    $0x4,%ebx
 118b5b8:	44 89 d9             	mov    %r11d,%ecx
 118b5bb:	c1 e1 04             	shl    $0x4,%ecx
 118b5be:	48 8b 84 0d 60 d9 fe 	mov    -0x126a0(%rbp,%rcx,1),%rax
 118b5c5:	ff 
 118b5c6:	48 39 84 1d 60 d9 fe 	cmp    %rax,-0x126a0(%rbp,%rbx,1)
 118b5cd:	ff 
 118b5ce:	0f 85 84 00 00 00    	jne    118b658 <huffman.treeCodeLengths__anon_40857+0xc18>
 118b5d4:	48 8d 04 2b          	lea    (%rbx,%rbp,1),%rax
 118b5d8:	48 05 60 d9 fe ff    	add    $0xfffffffffffed960,%rax
 118b5de:	48 01 e9             	add    %rbp,%rcx
 118b5e1:	48 81 c1 60 d9 fe ff 	add    $0xfffffffffffed960,%rcx
 118b5e8:	0f b7 40 0e          	movzwl 0xe(%rax),%eax
 118b5ec:	48 89 fb             	mov    %rdi,%rbx
 118b5ef:	66 3b 41 0e          	cmp    0xe(%rcx),%ax
 118b5f3:	72 6d                	jb     118b662 <huffman.treeCodeLengths__anon_40857+0xc22>
 118b5f5:	66 44 89 1b          	mov    %r11w,(%rbx)
 118b5f9:	eb 31                	jmp    118b62c <huffman.treeCodeLengths__anon_40857+0xbec>
 118b5fb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 118b600:	42 0f b7 84 4d 60 f1 	movzwl -0xea0(%rbp,%r9,2),%eax
 118b607:	ff ff 
 118b609:	66 89 07             	mov    %ax,(%rdi)
 118b60c:	49 ff c1             	inc    %r9
 118b60f:	eb 1e                	jmp    118b62f <huffman.treeCodeLengths__anon_40857+0xbef>
 118b611:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 118b618:	0f 1f 84 00 00 00 00 
 118b61f:	00 
 118b620:	42 0f b7 84 45 60 ef 	movzwl -0x10a0(%rbp,%r8,2),%eax
 118b627:	ff ff 
 118b629:	66 89 07             	mov    %ax,(%rdi)
 118b62c:	49 ff c0             	inc    %r8
 118b62f:	48 ff c6             	inc    %rsi
 118b632:	49 39 d0             	cmp    %rdx,%r8
 118b635:	41 0f 92 c2          	setb   %r10b
 118b639:	48 83 c7 02          	add    $0x2,%rdi
 118b63d:	4d 39 f1             	cmp    %r14,%r9
 118b640:	41 0f 92 c3          	setb   %r11b
 118b644:	0f 82 46 ff ff ff    	jb     118b590 <huffman.treeCodeLengths__anon_40857+0xb50>
 118b64a:	49 39 d0             	cmp    %rdx,%r8
 118b64d:	0f 82 3d ff ff ff    	jb     118b590 <huffman.treeCodeLengths__anon_40857+0xb50>
 118b653:	e9 48 fd ff ff       	jmp    118b3a0 <huffman.treeCodeLengths__anon_40857+0x960>
 118b658:	48 8d 9c 75 60 f7 ff 	lea    -0x8a0(%rbp,%rsi,2),%rbx
 118b65f:	ff 
 118b660:	73 93                	jae    118b5f5 <huffman.treeCodeLengths__anon_40857+0xbb5>
 118b662:	66 44 89 13          	mov    %r10w,(%rbx)
 118b666:	eb a4                	jmp    118b60c <huffman.treeCodeLengths__anon_40857+0xbcc>
 118b668:	48 83 c0 f9          	add    $0xfffffffffffffff9,%rax
 118b66c:	e9 5e 06 00 00       	jmp    118bccf <huffman.treeCodeLengths__anon_40857+0x128f>
 118b671:	41 01 fb             	add    %edi,%r11d
 118b674:	45 01 d0             	add    %r10d,%r8d
 118b677:	45 01 d8             	add    %r11d,%r8d
 118b67a:	44 01 ce             	add    %r9d,%esi
 118b67d:	01 f2                	add    %esi,%edx
 118b67f:	44 01 c2             	add    %r8d,%edx
 118b682:	41 01 df             	add    %ebx,%r15d
 118b685:	41 01 d7             	add    %edx,%r15d
 118b688:	41 83 e7 78          	and    $0x78,%r15d
 118b68c:	31 c0                	xor    %eax,%eax
 118b68e:	66 90                	xchg   %ax,%ax
 118b690:	0f b7 8c 45 60 f7 ff 	movzwl -0x8a0(%rbp,%rax,2),%ecx
 118b697:	ff 
 118b698:	0f b6 94 05 60 f3 ff 	movzbl -0xca0(%rbp,%rax,1),%edx
 118b69f:	ff 
 118b6a0:	0f b6 b4 05 61 f3 ff 	movzbl -0xc9f(%rbp,%rax,1),%esi
 118b6a7:	ff 
 118b6a8:	80 e2 0f             	and    $0xf,%dl
 118b6ab:	88 94 0d 60 fd ff ff 	mov    %dl,-0x2a0(%rbp,%rcx,1)
 118b6b2:	0f b7 8c 45 62 f7 ff 	movzwl -0x89e(%rbp,%rax,2),%ecx
 118b6b9:	ff 
 118b6ba:	40 80 e6 0f          	and    $0xf,%sil
 118b6be:	40 88 b4 0d 60 fd ff 	mov    %sil,-0x2a0(%rbp,%rcx,1)
 118b6c5:	ff 
 118b6c6:	0f b7 8c 45 64 f7 ff 	movzwl -0x89c(%rbp,%rax,2),%ecx
 118b6cd:	ff 
 118b6ce:	0f b6 94 05 62 f3 ff 	movzbl -0xc9e(%rbp,%rax,1),%edx
 118b6d5:	ff 
 118b6d6:	80 e2 0f             	and    $0xf,%dl
 118b6d9:	88 94 0d 60 fd ff ff 	mov    %dl,-0x2a0(%rbp,%rcx,1)
 118b6e0:	0f b7 8c 45 66 f7 ff 	movzwl -0x89a(%rbp,%rax,2),%ecx
 118b6e7:	ff 
 118b6e8:	0f b6 94 05 63 f3 ff 	movzbl -0xc9d(%rbp,%rax,1),%edx
 118b6ef:	ff 
 118b6f0:	80 e2 0f             	and    $0xf,%dl
 118b6f3:	88 94 0d 60 fd ff ff 	mov    %dl,-0x2a0(%rbp,%rcx,1)
 118b6fa:	0f b7 8c 45 68 f7 ff 	movzwl -0x898(%rbp,%rax,2),%ecx
 118b701:	ff 
 118b702:	0f b6 94 05 64 f3 ff 	movzbl -0xc9c(%rbp,%rax,1),%edx
 118b709:	ff 
 118b70a:	80 e2 0f             	and    $0xf,%dl
 118b70d:	88 94 0d 60 fd ff ff 	mov    %dl,-0x2a0(%rbp,%rcx,1)
 118b714:	0f b7 8c 45 6a f7 ff 	movzwl -0x896(%rbp,%rax,2),%ecx
 118b71b:	ff 
 118b71c:	0f b6 94 05 65 f3 ff 	movzbl -0xc9b(%rbp,%rax,1),%edx
 118b723:	ff 
 118b724:	80 e2 0f             	and    $0xf,%dl
 118b727:	88 94 0d 60 fd ff ff 	mov    %dl,-0x2a0(%rbp,%rcx,1)
 118b72e:	0f b7 8c 45 6c f7 ff 	movzwl -0x894(%rbp,%rax,2),%ecx
 118b735:	ff 
 118b736:	0f b6 94 05 66 f3 ff 	movzbl -0xc9a(%rbp,%rax,1),%edx
 118b73d:	ff 
 118b73e:	80 e2 0f             	and    $0xf,%dl
 118b741:	88 94 0d 60 fd ff ff 	mov    %dl,-0x2a0(%rbp,%rcx,1)
 118b748:	0f b7 8c 45 6e f7 ff 	movzwl -0x892(%rbp,%rax,2),%ecx
 118b74f:	ff 
 118b750:	0f b6 94 05 67 f3 ff 	movzbl -0xc99(%rbp,%rax,1),%edx
 118b757:	ff 
 118b758:	80 e2 0f             	and    $0xf,%dl
 118b75b:	88 94 0d 60 fd ff ff 	mov    %dl,-0x2a0(%rbp,%rcx,1)
 118b762:	48 83 c0 08          	add    $0x8,%rax
 118b766:	49 39 c7             	cmp    %rax,%r15
 118b769:	0f 85 21 ff ff ff    	jne    118b690 <huffman.treeCodeLengths__anon_40857+0xc50>
 118b76f:	41 f6 c6 07          	test   $0x7,%r14b
 118b773:	8b 75 d4             	mov    -0x2c(%rbp),%esi
 118b776:	44 8b 45 bc          	mov    -0x44(%rbp),%r8d
 118b77a:	0f 84 7d 00 00 00    	je     118b7fd <huffman.treeCodeLengths__anon_40857+0xdbd>
 118b780:	45 85 ed             	test   %r13d,%r13d
 118b783:	0f 95 c2             	setne  %dl
 118b786:	48 8d 0c 28          	lea    (%rax,%rbp,1),%rcx
 118b78a:	48 81 c1 60 f3 ff ff 	add    $0xfffffffffffff360,%rcx
 118b791:	48 8d 04 45 60 f7 ff 	lea    -0x8a0(,%rax,2),%rax
 118b798:	ff 
 118b799:	48 01 e8             	add    %rbp,%rax
 118b79c:	41 83 fc 01          	cmp    $0x1,%r12d
 118b7a0:	80 da ff             	sbb    $0xff,%dl
 118b7a3:	41 83 f8 01          	cmp    $0x1,%r8d
 118b7a7:	80 da ff             	sbb    $0xff,%dl
 118b7aa:	83 fe 01             	cmp    $0x1,%esi
 118b7ad:	80 da ff             	sbb    $0xff,%dl
 118b7b0:	83 7d cc 01          	cmpl   $0x1,-0x34(%rbp)
 118b7b4:	80 da ff             	sbb    $0xff,%dl
 118b7b7:	83 7d c8 01          	cmpl   $0x1,-0x38(%rbp)
 118b7bb:	80 da ff             	sbb    $0xff,%dl
 118b7be:	83 7d c0 01          	cmpl   $0x1,-0x40(%rbp)
 118b7c2:	80 da ff             	sbb    $0xff,%dl
 118b7c5:	83 7d c4 01          	cmpl   $0x1,-0x3c(%rbp)
 118b7c9:	80 da ff             	sbb    $0xff,%dl
 118b7cc:	40 00 d7             	add    %dl,%dil
 118b7cf:	40 0f b6 d7          	movzbl %dil,%edx
 118b7d3:	83 e2 07             	and    $0x7,%edx
 118b7d6:	31 f6                	xor    %esi,%esi
 118b7d8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 118b7df:	00 
 118b7e0:	0f b7 3c 70          	movzwl (%rax,%rsi,2),%edi
 118b7e4:	44 0f b6 04 31       	movzbl (%rcx,%rsi,1),%r8d
 118b7e9:	41 80 e0 0f          	and    $0xf,%r8b
 118b7ed:	44 88 84 3d 60 fd ff 	mov    %r8b,-0x2a0(%rbp,%rdi,1)
 118b7f4:	ff 
 118b7f5:	48 ff c6             	inc    %rsi
 118b7f8:	48 39 f2             	cmp    %rsi,%rdx
 118b7fb:	75 e3                	jne    118b7e0 <huffman.treeCodeLengths__anon_40857+0xda0>
 118b7fd:	c5 fc 10 85 40 fe ff 	vmovups -0x1c0(%rbp),%ymm0
 118b804:	ff 
 118b805:	48 8b 5d 98          	mov    -0x68(%rbp),%rbx
 118b809:	c5 fc 11 83 e0 00 00 	vmovups %ymm0,0xe0(%rbx)
 118b810:	00 
 118b811:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 118b818:	ff 
 118b819:	c5 fc 11 83 c0 00 00 	vmovups %ymm0,0xc0(%rbx)
 118b820:	00 
 118b821:	c5 fc 10 85 00 fe ff 	vmovups -0x200(%rbp),%ymm0
 118b828:	ff 
 118b829:	c5 fc 11 83 a0 00 00 	vmovups %ymm0,0xa0(%rbx)
 118b830:	00 
 118b831:	c5 fc 10 85 e0 fd ff 	vmovups -0x220(%rbp),%ymm0
 118b838:	ff 
 118b839:	c5 fc 11 83 80 00 00 	vmovups %ymm0,0x80(%rbx)
 118b840:	00 
 118b841:	c5 fc 10 85 60 fd ff 	vmovups -0x2a0(%rbp),%ymm0
 118b848:	ff 
 118b849:	c5 fc 10 8d 80 fd ff 	vmovups -0x280(%rbp),%ymm1
 118b850:	ff 
 118b851:	c5 fc 10 95 a0 fd ff 	vmovups -0x260(%rbp),%ymm2
 118b858:	ff 
 118b859:	c5 fc 10 9d c0 fd ff 	vmovups -0x240(%rbp),%ymm3
 118b860:	ff 
 118b861:	e9 d1 04 00 00       	jmp    118bd37 <huffman.treeCodeLengths__anon_40857+0x12f7>
 118b866:	4b 8d 14 3f          	lea    (%r15,%r15,1),%rdx
 118b86a:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 118b86e:	48 83 c0 fe          	add    $0xfffffffffffffffe,%rax
 118b872:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 118b876:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 118b87a:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 118b881:	ff 
 118b882:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 118b889:	ff 
 118b88a:	c5 fc 11 85 00 fd ff 	vmovups %ymm0,-0x300(%rbp)
 118b891:	ff 
 118b892:	c5 fc 11 85 e0 fc ff 	vmovups %ymm0,-0x320(%rbp)
 118b899:	ff 
 118b89a:	c5 fc 11 85 c0 fc ff 	vmovups %ymm0,-0x340(%rbp)
 118b8a1:	ff 
 118b8a2:	c5 fc 11 85 a0 fc ff 	vmovups %ymm0,-0x360(%rbp)
 118b8a9:	ff 
 118b8aa:	c5 fc 11 85 80 fc ff 	vmovups %ymm0,-0x380(%rbp)
 118b8b1:	ff 
 118b8b2:	c5 fc 11 85 60 fc ff 	vmovups %ymm0,-0x3a0(%rbp)
 118b8b9:	ff 
 118b8ba:	48 8d bd 60 c9 ff ff 	lea    -0x36a0(%rbp),%rdi
 118b8c1:	31 db                	xor    %ebx,%ebx
 118b8c3:	31 f6                	xor    %esi,%esi
 118b8c5:	c5 f8 77             	vzeroupper 
 118b8c8:	e8 b3 bf 10 00       	call   1297880 <compiler_rt.memset>
 118b8cd:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 118b8d1:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 118b8d5:	48 83 c1 fd          	add    $0xfffffffffffffffd,%rcx
 118b8d9:	89 d0                	mov    %edx,%eax
 118b8db:	83 e0 06             	and    $0x6,%eax
 118b8de:	48 83 f9 07          	cmp    $0x7,%rcx
 118b8e2:	73 09                	jae    118b8ed <huffman.treeCodeLengths__anon_40857+0xead>
 118b8e4:	44 8b 45 d4          	mov    -0x2c(%rbp),%r8d
 118b8e8:	e9 a0 00 00 00       	jmp    118b98d <huffman.treeCodeLengths__anon_40857+0xf4d>
 118b8ed:	48 83 e2 f8          	and    $0xfffffffffffffff8,%rdx
 118b8f1:	31 db                	xor    %ebx,%ebx
 118b8f3:	44 8b 45 d4          	mov    -0x2c(%rbp),%r8d
 118b8f7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 118b8fe:	00 00 
 118b900:	0f b7 8c 5d 60 f7 ff 	movzwl -0x8a0(%rbp,%rbx,2),%ecx
 118b907:	ff 
 118b908:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b90f:	ff 
 118b910:	0f b7 8c 5d 62 f7 ff 	movzwl -0x89e(%rbp,%rbx,2),%ecx
 118b917:	ff 
 118b918:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b91f:	ff 
 118b920:	0f b7 8c 5d 64 f7 ff 	movzwl -0x89c(%rbp,%rbx,2),%ecx
 118b927:	ff 
 118b928:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b92f:	ff 
 118b930:	0f b7 8c 5d 66 f7 ff 	movzwl -0x89a(%rbp,%rbx,2),%ecx
 118b937:	ff 
 118b938:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b93f:	ff 
 118b940:	0f b7 8c 5d 68 f7 ff 	movzwl -0x898(%rbp,%rbx,2),%ecx
 118b947:	ff 
 118b948:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b94f:	ff 
 118b950:	0f b7 8c 5d 6a f7 ff 	movzwl -0x896(%rbp,%rbx,2),%ecx
 118b957:	ff 
 118b958:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b95f:	ff 
 118b960:	0f b7 8c 5d 6c f7 ff 	movzwl -0x894(%rbp,%rbx,2),%ecx
 118b967:	ff 
 118b968:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b96f:	ff 
 118b970:	0f b7 8c 5d 6e f7 ff 	movzwl -0x892(%rbp,%rbx,2),%ecx
 118b977:	ff 
 118b978:	66 ff 84 4d 60 c9 ff 	incw   -0x36a0(%rbp,%rcx,2)
 118b97f:	ff 
 118b980:	48 83 c3 08          	add    $0x8,%rbx
 118b984:	48 39 da             	cmp    %rbx,%rdx
 118b987:	0f 85 73 ff ff ff    	jne    118b900 <huffman.treeCodeLengths__anon_40857+0xec0>
 118b98d:	48 85 c0             	test   %rax,%rax
 118b990:	74 22                	je     118b9b4 <huffman.treeCodeLengths__anon_40857+0xf74>
 118b992:	48 8d 0c 5d 60 f7 ff 	lea    -0x8a0(,%rbx,2),%rcx
 118b999:	ff 
 118b99a:	48 01 e9             	add    %rbp,%rcx
 118b99d:	31 d2                	xor    %edx,%edx
 118b99f:	90                   	nop
 118b9a0:	0f b7 34 51          	movzwl (%rcx,%rdx,2),%esi
 118b9a4:	66 ff 84 75 60 c9 ff 	incw   -0x36a0(%rbp,%rsi,2)
 118b9ab:	ff 
 118b9ac:	48 ff c2             	inc    %rdx
 118b9af:	48 39 d0             	cmp    %rdx,%rax
 118b9b2:	75 ec                	jne    118b9a0 <huffman.treeCodeLengths__anon_40857+0xf60>
 118b9b4:	4d 39 f7             	cmp    %r14,%r15
 118b9b7:	76 54                	jbe    118ba0d <huffman.treeCodeLengths__anon_40857+0xfcd>
 118b9b9:	44 89 fa             	mov    %r15d,%edx
 118b9bc:	44 29 f2             	sub    %r14d,%edx
 118b9bf:	49 8d 4e 01          	lea    0x1(%r14),%rcx
 118b9c3:	4c 89 f8             	mov    %r15,%rax
 118b9c6:	f6 c2 01             	test   $0x1,%dl
 118b9c9:	74 39                	je     118ba04 <huffman.treeCodeLengths__anon_40857+0xfc4>
 118b9cb:	49 8d 47 ff          	lea    -0x1(%r15),%rax
 118b9cf:	42 0f b7 94 7d 5e c9 	movzwl -0x36a2(%rbp,%r15,2),%edx
 118b9d6:	ff ff 
 118b9d8:	66 85 d2             	test   %dx,%dx
 118b9db:	74 27                	je     118ba04 <huffman.treeCodeLengths__anon_40857+0xfc4>
 118b9dd:	48 89 c6             	mov    %rax,%rsi
 118b9e0:	48 c1 e6 04          	shl    $0x4,%rsi
 118b9e4:	0f b7 bc 35 68 d9 fe 	movzwl -0x12698(%rbp,%rsi,1),%edi
 118b9eb:	ff 
 118b9ec:	0f b7 b4 35 6a d9 fe 	movzwl -0x12696(%rbp,%rsi,1),%esi
 118b9f3:	ff 
 118b9f4:	66 01 94 7d 60 c9 ff 	add    %dx,-0x36a0(%rbp,%rdi,2)
 118b9fb:	ff 
 118b9fc:	66 01 94 75 60 c9 ff 	add    %dx,-0x36a0(%rbp,%rsi,2)
 118ba03:	ff 
 118ba04:	49 39 cf             	cmp    %rcx,%r15
 118ba07:	0f 85 52 03 00 00    	jne    118bd5f <huffman.treeCodeLengths__anon_40857+0x131f>
 118ba0d:	31 c0                	xor    %eax,%eax
 118ba0f:	83 7d c4 00          	cmpl   $0x0,-0x3c(%rbp)
 118ba13:	0f 95 c0             	setne  %al
 118ba16:	31 d2                	xor    %edx,%edx
 118ba18:	83 7d c0 00          	cmpl   $0x0,-0x40(%rbp)
 118ba1c:	0f 95 c2             	setne  %dl
 118ba1f:	31 f6                	xor    %esi,%esi
 118ba21:	83 7d c8 00          	cmpl   $0x0,-0x38(%rbp)
 118ba25:	40 0f 95 c6          	setne  %sil
 118ba29:	31 ff                	xor    %edi,%edi
 118ba2b:	83 7d cc 00          	cmpl   $0x0,-0x34(%rbp)
 118ba2f:	40 0f 95 c7          	setne  %dil
 118ba33:	45 31 c9             	xor    %r9d,%r9d
 118ba36:	45 85 c0             	test   %r8d,%r8d
 118ba39:	41 0f 95 c1          	setne  %r9b
 118ba3d:	45 31 c0             	xor    %r8d,%r8d
 118ba40:	83 7d bc 00          	cmpl   $0x0,-0x44(%rbp)
 118ba44:	41 0f 95 c0          	setne  %r8b
 118ba48:	45 31 d2             	xor    %r10d,%r10d
 118ba4b:	45 85 e4             	test   %r12d,%r12d
 118ba4e:	41 0f 95 c2          	setne  %r10b
 118ba52:	45 31 db             	xor    %r11d,%r11d
 118ba55:	45 85 ed             	test   %r13d,%r13d
 118ba58:	41 0f 95 c3          	setne  %r11b
 118ba5c:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 118ba60:	4b 8d 1c 02          	lea    (%r10,%r8,1),%rbx
 118ba64:	4c 01 fb             	add    %r15,%rbx
 118ba67:	4c 01 db             	add    %r11,%rbx
 118ba6a:	49 8d 0c 39          	lea    (%r9,%rdi,1),%rcx
 118ba6e:	48 01 f1             	add    %rsi,%rcx
 118ba71:	48 01 d9             	add    %rbx,%rcx
 118ba74:	48 01 d1             	add    %rdx,%rcx
 118ba77:	48 01 c1             	add    %rax,%rcx
 118ba7a:	48 ff c9             	dec    %rcx
 118ba7d:	48 83 f9 07          	cmp    $0x7,%rcx
 118ba81:	73 0b                	jae    118ba8e <huffman.treeCodeLengths__anon_40857+0x104e>
 118ba83:	31 d2                	xor    %edx,%edx
 118ba85:	4c 8b 4d 98          	mov    -0x68(%rbp),%r9
 118ba89:	e9 03 01 00 00       	jmp    118bb91 <huffman.treeCodeLengths__anon_40857+0x1151>
 118ba8e:	48 8d 8d dc d9 fe ff 	lea    -0x12624(%rbp),%rcx
 118ba95:	45 01 fb             	add    %r15d,%r11d
 118ba98:	45 01 d0             	add    %r10d,%r8d
 118ba9b:	45 01 d8             	add    %r11d,%r8d
 118ba9e:	44 01 cf             	add    %r9d,%edi
 118baa1:	01 fe                	add    %edi,%esi
 118baa3:	44 01 c6             	add    %r8d,%esi
 118baa6:	01 d0                	add    %edx,%eax
 118baa8:	01 f0                	add    %esi,%eax
 118baaa:	25 f8 01 00 00       	and    $0x1f8,%eax
 118baaf:	31 d2                	xor    %edx,%edx
 118bab1:	4c 8b 4d 98          	mov    -0x68(%rbp),%r9
 118bab5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 118babc:	00 00 00 00 
 118bac0:	0f b7 71 90          	movzwl -0x70(%rcx),%esi
 118bac4:	0f b6 bc 55 60 c9 ff 	movzbl -0x36a0(%rbp,%rdx,2),%edi
 118bacb:	ff 
 118bacc:	44 0f b6 84 55 62 c9 	movzbl -0x369e(%rbp,%rdx,2),%r8d
 118bad3:	ff ff 
 118bad5:	40 80 e7 0f          	and    $0xf,%dil
 118bad9:	40 88 bc 35 60 fc ff 	mov    %dil,-0x3a0(%rbp,%rsi,1)
 118bae0:	ff 
 118bae1:	0f b7 71 a0          	movzwl -0x60(%rcx),%esi
 118bae5:	41 80 e0 0f          	and    $0xf,%r8b
 118bae9:	44 88 84 35 60 fc ff 	mov    %r8b,-0x3a0(%rbp,%rsi,1)
 118baf0:	ff 
 118baf1:	0f b7 71 b0          	movzwl -0x50(%rcx),%esi
 118baf5:	0f b6 bc 55 64 c9 ff 	movzbl -0x369c(%rbp,%rdx,2),%edi
 118bafc:	ff 
 118bafd:	40 80 e7 0f          	and    $0xf,%dil
 118bb01:	40 88 bc 35 60 fc ff 	mov    %dil,-0x3a0(%rbp,%rsi,1)
 118bb08:	ff 
 118bb09:	0f b7 71 c0          	movzwl -0x40(%rcx),%esi
 118bb0d:	0f b6 bc 55 66 c9 ff 	movzbl -0x369a(%rbp,%rdx,2),%edi
 118bb14:	ff 
 118bb15:	40 80 e7 0f          	and    $0xf,%dil
 118bb19:	40 88 bc 35 60 fc ff 	mov    %dil,-0x3a0(%rbp,%rsi,1)
 118bb20:	ff 
 118bb21:	0f b7 71 d0          	movzwl -0x30(%rcx),%esi
 118bb25:	0f b6 bc 55 68 c9 ff 	movzbl -0x3698(%rbp,%rdx,2),%edi
 118bb2c:	ff 
 118bb2d:	40 80 e7 0f          	and    $0xf,%dil
 118bb31:	40 88 bc 35 60 fc ff 	mov    %dil,-0x3a0(%rbp,%rsi,1)
 118bb38:	ff 
 118bb39:	0f b7 71 e0          	movzwl -0x20(%rcx),%esi
 118bb3d:	0f b6 bc 55 6a c9 ff 	movzbl -0x3696(%rbp,%rdx,2),%edi
 118bb44:	ff 
 118bb45:	40 80 e7 0f          	and    $0xf,%dil
 118bb49:	40 88 bc 35 60 fc ff 	mov    %dil,-0x3a0(%rbp,%rsi,1)
 118bb50:	ff 
 118bb51:	0f b7 71 f0          	movzwl -0x10(%rcx),%esi
 118bb55:	0f b6 bc 55 6c c9 ff 	movzbl -0x3694(%rbp,%rdx,2),%edi
 118bb5c:	ff 
 118bb5d:	40 80 e7 0f          	and    $0xf,%dil
 118bb61:	40 88 bc 35 60 fc ff 	mov    %dil,-0x3a0(%rbp,%rsi,1)
 118bb68:	ff 
 118bb69:	0f b7 31             	movzwl (%rcx),%esi
 118bb6c:	0f b6 bc 55 6e c9 ff 	movzbl -0x3692(%rbp,%rdx,2),%edi
 118bb73:	ff 
 118bb74:	40 80 e7 0f          	and    $0xf,%dil
 118bb78:	40 88 bc 35 60 fc ff 	mov    %dil,-0x3a0(%rbp,%rsi,1)
 118bb7f:	ff 
 118bb80:	48 83 c2 08          	add    $0x8,%rdx
 118bb84:	48 83 e9 80          	sub    $0xffffffffffffff80,%rcx
 118bb88:	48 39 d0             	cmp    %rdx,%rax
 118bb8b:	0f 85 2f ff ff ff    	jne    118bac0 <huffman.treeCodeLengths__anon_40857+0x1080>
 118bb91:	41 f6 c6 07          	test   $0x7,%r14b
 118bb95:	8b 7d c0             	mov    -0x40(%rbp),%edi
 118bb98:	0f 84 90 00 00 00    	je     118bc2e <huffman.treeCodeLengths__anon_40857+0x11ee>
 118bb9e:	45 85 ed             	test   %r13d,%r13d
 118bba1:	40 0f 95 c6          	setne  %sil
 118bba5:	48 8d 04 55 60 c9 ff 	lea    -0x36a0(,%rdx,2),%rax
 118bbac:	ff 
 118bbad:	48 01 e8             	add    %rbp,%rax
 118bbb0:	48 c1 e2 04          	shl    $0x4,%rdx
 118bbb4:	48 8d 8d 60 d9 fe ff 	lea    -0x126a0(%rbp),%rcx
 118bbbb:	48 01 d1             	add    %rdx,%rcx
 118bbbe:	48 83 c1 0c          	add    $0xc,%rcx
 118bbc2:	41 83 fc 01          	cmp    $0x1,%r12d
 118bbc6:	40 80 de ff          	sbb    $0xff,%sil
 118bbca:	83 7d bc 01          	cmpl   $0x1,-0x44(%rbp)
 118bbce:	40 80 de ff          	sbb    $0xff,%sil
 118bbd2:	83 7d d4 01          	cmpl   $0x1,-0x2c(%rbp)
 118bbd6:	40 80 de ff          	sbb    $0xff,%sil
 118bbda:	83 7d cc 01          	cmpl   $0x1,-0x34(%rbp)
 118bbde:	40 80 de ff          	sbb    $0xff,%sil
 118bbe2:	83 7d c8 01          	cmpl   $0x1,-0x38(%rbp)
 118bbe6:	40 80 de ff          	sbb    $0xff,%sil
 118bbea:	83 ff 01             	cmp    $0x1,%edi
 118bbed:	40 80 de ff          	sbb    $0xff,%sil
 118bbf1:	83 7d c4 01          	cmpl   $0x1,-0x3c(%rbp)
 118bbf5:	40 80 de ff          	sbb    $0xff,%sil
 118bbf9:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 118bbfd:	40 00 f2             	add    %sil,%dl
 118bc00:	0f b6 d2             	movzbl %dl,%edx
 118bc03:	83 e2 07             	and    $0x7,%edx
 118bc06:	01 d2                	add    %edx,%edx
 118bc08:	31 f6                	xor    %esi,%esi
 118bc0a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 118bc10:	0f b7 3c f1          	movzwl (%rcx,%rsi,8),%edi
 118bc14:	44 0f b6 04 30       	movzbl (%rax,%rsi,1),%r8d
 118bc19:	41 80 e0 0f          	and    $0xf,%r8b
 118bc1d:	44 88 84 3d 60 fc ff 	mov    %r8b,-0x3a0(%rbp,%rdi,1)
 118bc24:	ff 
 118bc25:	48 83 c6 02          	add    $0x2,%rsi
 118bc29:	48 39 f2             	cmp    %rsi,%rdx
 118bc2c:	75 e2                	jne    118bc10 <huffman.treeCodeLengths__anon_40857+0x11d0>
 118bc2e:	c5 fc 10 85 40 fd ff 	vmovups -0x2c0(%rbp),%ymm0
 118bc35:	ff 
 118bc36:	c4 c1 7c 11 81 e0 00 	vmovups %ymm0,0xe0(%r9)
 118bc3d:	00 00 
 118bc3f:	c5 fc 10 85 20 fd ff 	vmovups -0x2e0(%rbp),%ymm0
 118bc46:	ff 
 118bc47:	c4 c1 7c 11 81 c0 00 	vmovups %ymm0,0xc0(%r9)
 118bc4e:	00 00 
 118bc50:	c5 fc 10 85 00 fd ff 	vmovups -0x300(%rbp),%ymm0
 118bc57:	ff 
 118bc58:	c4 c1 7c 11 81 a0 00 	vmovups %ymm0,0xa0(%r9)
 118bc5f:	00 00 
 118bc61:	c5 fc 10 85 e0 fc ff 	vmovups -0x320(%rbp),%ymm0
 118bc68:	ff 
 118bc69:	c4 c1 7c 11 81 80 00 	vmovups %ymm0,0x80(%r9)
 118bc70:	00 00 
 118bc72:	c5 fc 10 85 60 fc ff 	vmovups -0x3a0(%rbp),%ymm0
 118bc79:	ff 
 118bc7a:	c5 fc 10 8d 80 fc ff 	vmovups -0x380(%rbp),%ymm1
 118bc81:	ff 
 118bc82:	c5 fc 10 95 a0 fc ff 	vmovups -0x360(%rbp),%ymm2
 118bc89:	ff 
 118bc8a:	c5 fc 10 9d c0 fc ff 	vmovups -0x340(%rbp),%ymm3
 118bc91:	ff 
 118bc92:	c4 c1 7c 11 59 60    	vmovups %ymm3,0x60(%r9)
 118bc98:	c4 c1 7c 11 51 40    	vmovups %ymm2,0x40(%r9)
 118bc9e:	c4 c1 7c 11 49 20    	vmovups %ymm1,0x20(%r9)
 118bca4:	c4 c1 7c 11 01       	vmovups %ymm0,(%r9)
 118bca9:	e9 9c 00 00 00       	jmp    118bd4a <huffman.treeCodeLengths__anon_40857+0x130a>
 118bcae:	48 83 c0 fa          	add    $0xfffffffffffffffa,%rax
 118bcb2:	eb 1b                	jmp    118bccf <huffman.treeCodeLengths__anon_40857+0x128f>
 118bcb4:	48 83 c0 fb          	add    $0xfffffffffffffffb,%rax
 118bcb8:	eb 15                	jmp    118bccf <huffman.treeCodeLengths__anon_40857+0x128f>
 118bcba:	48 83 c0 fc          	add    $0xfffffffffffffffc,%rax
 118bcbe:	eb 0f                	jmp    118bccf <huffman.treeCodeLengths__anon_40857+0x128f>
 118bcc0:	48 83 c0 fd          	add    $0xfffffffffffffffd,%rax
 118bcc4:	eb 09                	jmp    118bccf <huffman.treeCodeLengths__anon_40857+0x128f>
 118bcc6:	48 83 c0 fe          	add    $0xfffffffffffffffe,%rax
 118bcca:	eb 03                	jmp    118bccf <huffman.treeCodeLengths__anon_40857+0x128f>
 118bccc:	48 ff c8             	dec    %rax
 118bccf:	c6 84 05 60 fb ff ff 	movb   $0x1,-0x4a0(%rbp,%rax,1)
 118bcd6:	01 
 118bcd7:	c5 fc 10 85 40 fc ff 	vmovups -0x3c0(%rbp),%ymm0
 118bcde:	ff 
 118bcdf:	c5 fc 11 83 e0 00 00 	vmovups %ymm0,0xe0(%rbx)
 118bce6:	00 
 118bce7:	c5 fc 10 85 20 fc ff 	vmovups -0x3e0(%rbp),%ymm0
 118bcee:	ff 
 118bcef:	c5 fc 11 83 c0 00 00 	vmovups %ymm0,0xc0(%rbx)
 118bcf6:	00 
 118bcf7:	c5 fc 10 85 00 fc ff 	vmovups -0x400(%rbp),%ymm0
 118bcfe:	ff 
 118bcff:	c5 fc 11 83 a0 00 00 	vmovups %ymm0,0xa0(%rbx)
 118bd06:	00 
 118bd07:	c5 fc 10 85 e0 fb ff 	vmovups -0x420(%rbp),%ymm0
 118bd0e:	ff 
 118bd0f:	c5 fc 11 83 80 00 00 	vmovups %ymm0,0x80(%rbx)
 118bd16:	00 
 118bd17:	c5 fc 10 85 60 fb ff 	vmovups -0x4a0(%rbp),%ymm0
 118bd1e:	ff 
 118bd1f:	c5 fc 10 8d 80 fb ff 	vmovups -0x480(%rbp),%ymm1
 118bd26:	ff 
 118bd27:	c5 fc 10 95 a0 fb ff 	vmovups -0x460(%rbp),%ymm2
 118bd2e:	ff 
 118bd2f:	c5 fc 10 9d c0 fb ff 	vmovups -0x440(%rbp),%ymm3
 118bd36:	ff 
 118bd37:	c5 fc 11 5b 60       	vmovups %ymm3,0x60(%rbx)
 118bd3c:	c5 fc 11 53 40       	vmovups %ymm2,0x40(%rbx)
 118bd41:	c5 fc 11 4b 20       	vmovups %ymm1,0x20(%rbx)
 118bd46:	c5 fc 11 03          	vmovups %ymm0,(%rbx)
 118bd4a:	48 81 c4 78 26 01 00 	add    $0x12678,%rsp
 118bd51:	5b                   	pop    %rbx
 118bd52:	41 5c                	pop    %r12
 118bd54:	41 5d                	pop    %r13
 118bd56:	41 5e                	pop    %r14
 118bd58:	41 5f                	pop    %r15
 118bd5a:	5d                   	pop    %rbp
 118bd5b:	c5 f8 77             	vzeroupper 
 118bd5e:	c3                   	ret    
 118bd5f:	48 89 c1             	mov    %rax,%rcx
 118bd62:	48 c1 e1 04          	shl    $0x4,%rcx
 118bd66:	48 8d 95 60 d9 fe ff 	lea    -0x126a0(%rbp),%rdx
 118bd6d:	48 01 d1             	add    %rdx,%rcx
 118bd70:	48 83 c1 fa          	add    $0xfffffffffffffffa,%rcx
 118bd74:	eb 1b                	jmp    118bd91 <huffman.treeCodeLengths__anon_40857+0x1351>
 118bd76:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 118bd7d:	00 00 00 
 118bd80:	48 83 c0 fe          	add    $0xfffffffffffffffe,%rax
 118bd84:	48 83 c1 e0          	add    $0xffffffffffffffe0,%rcx
 118bd88:	4c 39 f0             	cmp    %r14,%rax
 118bd8b:	0f 86 7c fc ff ff    	jbe    118ba0d <huffman.treeCodeLengths__anon_40857+0xfcd>
 118bd91:	0f b7 94 45 5e c9 ff 	movzwl -0x36a2(%rbp,%rax,2),%edx
 118bd98:	ff 
 118bd99:	66 85 d2             	test   %dx,%dx
 118bd9c:	74 17                	je     118bdb5 <huffman.treeCodeLengths__anon_40857+0x1375>
 118bd9e:	0f b7 71 fe          	movzwl -0x2(%rcx),%esi
 118bda2:	0f b7 39             	movzwl (%rcx),%edi
 118bda5:	66 01 94 75 60 c9 ff 	add    %dx,-0x36a0(%rbp,%rsi,2)
 118bdac:	ff 
 118bdad:	66 01 94 7d 60 c9 ff 	add    %dx,-0x36a0(%rbp,%rdi,2)
 118bdb4:	ff 
 118bdb5:	0f b7 94 45 5c c9 ff 	movzwl -0x36a4(%rbp,%rax,2),%edx
 118bdbc:	ff 
 118bdbd:	66 85 d2             	test   %dx,%dx
 118bdc0:	74 be                	je     118bd80 <huffman.treeCodeLengths__anon_40857+0x1340>
 118bdc2:	0f b7 71 ee          	movzwl -0x12(%rcx),%esi
 118bdc6:	0f b7 79 f0          	movzwl -0x10(%rcx),%edi
 118bdca:	66 01 94 75 60 c9 ff 	add    %dx,-0x36a0(%rbp,%rsi,2)
 118bdd1:	ff 
 118bdd2:	66 01 94 7d 60 c9 ff 	add    %dx,-0x36a0(%rbp,%rdi,2)
 118bdd9:	ff 
 118bdda:	eb a4                	jmp    118bd80 <huffman.treeCodeLengths__anon_40857+0x1340>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
