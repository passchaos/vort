
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>:
 1272b80:	55                   	push   %rbp
 1272b81:	48 89 e5             	mov    %rsp,%rbp
 1272b84:	41 57                	push   %r15
 1272b86:	41 56                	push   %r14
 1272b88:	41 55                	push   %r13
 1272b8a:	41 54                	push   %r12
 1272b8c:	53                   	push   %rbx
 1272b8d:	48 81 ec f8 0b 00 00 	sub    $0xbf8,%rsp
 1272b94:	4c 89 4d 80          	mov    %r9,-0x80(%rbp)
 1272b98:	4c 89 c3             	mov    %r8,%rbx
 1272b9b:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 1272b9f:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 1272ba6:	49 89 f5             	mov    %rsi,%r13
 1272ba9:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 1272bad:	48 8b 45 20          	mov    0x20(%rbp),%rax
 1272bb1:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 1272bb5:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 1272bbc:	ff 
 1272bbd:	48 8b 08             	mov    (%rax),%rcx
 1272bc0:	48 89 4d a8          	mov    %rcx,-0x58(%rbp)
 1272bc4:	48 8b 48 08          	mov    0x8(%rax),%rcx
 1272bc8:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 1272bcc:	48 8b 48 10          	mov    0x10(%rax),%rcx
 1272bd0:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 1272bd4:	48 8b 48 18          	mov    0x18(%rax),%rcx
 1272bd8:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 1272bdc:	c5 fc 10 40 20       	vmovups 0x20(%rax),%ymm0
 1272be1:	c5 fc 11 85 10 fe ff 	vmovups %ymm0,-0x1f0(%rbp)
 1272be8:	ff 
 1272be9:	44 0f b6 60 40       	movzbl 0x40(%rax),%r12d
 1272bee:	44 88 65 d0          	mov    %r12b,-0x30(%rbp)
 1272bf2:	0f b6 40 4e          	movzbl 0x4e(%rax),%eax
 1272bf6:	88 45 d7             	mov    %al,-0x29(%rbp)
 1272bf9:	4c 8b 7d 18          	mov    0x18(%rbp),%r15
 1272bfd:	4c 8b 75 10          	mov    0x10(%rbp),%r14
 1272c01:	48 8b 75 28          	mov    0x28(%rbp),%rsi
 1272c05:	48 8d bd e8 f3 ff ff 	lea    -0xc18(%rbp),%rdi
 1272c0c:	ba 60 01 00 00       	mov    $0x160,%edx
 1272c11:	c5 f8 77             	vzeroupper 
 1272c14:	e8 47 cb 06 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 1272c19:	4c 89 6d c0          	mov    %r13,-0x40(%rbp)
 1272c1d:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 1272c23:	c5 fc 11 85 f0 f9 ff 	vmovups %ymm0,-0x610(%rbp)
 1272c2a:	ff 
 1272c2b:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 1272c32:	48 8d b5 f0 f9 ff ff 	lea    -0x610(%rbp),%rsi
 1272c39:	ba 0a 00 00 00       	mov    $0xa,%edx
 1272c3e:	48 89 5d 88          	mov    %rbx,-0x78(%rbp)
 1272c42:	48 89 d9             	mov    %rbx,%rcx
 1272c45:	48 8b 5d 38          	mov    0x38(%rbp),%rbx
 1272c49:	4d 89 f0             	mov    %r14,%r8
 1272c4c:	4c 8b 75 30          	mov    0x30(%rbp),%r14
 1272c50:	c5 f8 77             	vzeroupper 
 1272c53:	e8 38 49 00 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 1272c58:	c4 c1 7c 10 47 70    	vmovups 0x70(%r15),%ymm0
 1272c5e:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 1272c65:	ff 
 1272c66:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1272c6b:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1272c71:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 1272c77:	c4 c1 7c 10 5f 60    	vmovups 0x60(%r15),%ymm3
 1272c7d:	c5 fc 11 9d e0 fd ff 	vmovups %ymm3,-0x220(%rbp)
 1272c84:	ff 
 1272c85:	c5 fc 11 95 c0 fd ff 	vmovups %ymm2,-0x240(%rbp)
 1272c8c:	ff 
 1272c8d:	c5 fc 11 8d a0 fd ff 	vmovups %ymm1,-0x260(%rbp)
 1272c94:	ff 
 1272c95:	c5 fc 11 85 80 fd ff 	vmovups %ymm0,-0x280(%rbp)
 1272c9c:	ff 
 1272c9d:	c4 c1 7c 10 47 70    	vmovups 0x70(%r15),%ymm0
 1272ca3:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1272caa:	ff 
 1272cab:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1272cb0:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1272cb6:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 1272cbc:	c4 c1 7c 10 5f 60    	vmovups 0x60(%r15),%ymm3
 1272cc2:	c5 fc 11 9d 90 fe ff 	vmovups %ymm3,-0x170(%rbp)
 1272cc9:	ff 
 1272cca:	c5 fc 11 95 70 fe ff 	vmovups %ymm2,-0x190(%rbp)
 1272cd1:	ff 
 1272cd2:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 1272cd9:	ff 
 1272cda:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 1272ce1:	ff 
 1272ce2:	41 80 7e 68 00       	cmpb   $0x0,0x68(%r14)
 1272ce7:	0f b6 85 40 f5 ff ff 	movzbl -0xac0(%rbp),%eax
 1272cee:	0f 94 c2             	sete   %dl
 1272cf1:	48 85 db             	test   %rbx,%rbx
 1272cf4:	40 0f 94 c6          	sete   %sil
 1272cf8:	b9 30 ad 03 01       	mov    $0x103ad30,%ecx
 1272cfd:	40 84 f2             	test   %sil,%dl
 1272d00:	74 37                	je     1272d39 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x1b9>
 1272d02:	c5 fc 10 85 f8 f3 ff 	vmovups -0xc08(%rbp),%ymm0
 1272d09:	ff 
 1272d0a:	c5 fc 10 8d 30 f4 ff 	vmovups -0xbd0(%rbp),%ymm1
 1272d11:	ff 
 1272d12:	c5 fc 11 8d a8 f7 ff 	vmovups %ymm1,-0x858(%rbp)
 1272d19:	ff 
 1272d1a:	c5 fc 10 8d 18 f4 ff 	vmovups -0xbe8(%rbp),%ymm1
 1272d21:	ff 
 1272d22:	c5 fc 11 8d 90 f7 ff 	vmovups %ymm1,-0x870(%rbp)
 1272d29:	ff 
 1272d2a:	c5 fc 11 85 70 f7 ff 	vmovups %ymm0,-0x890(%rbp)
 1272d31:	ff 
 1272d32:	48 8d 8d 70 f7 ff ff 	lea    -0x890(%rbp),%rcx
 1272d39:	c5 fc 10 01          	vmovups (%rcx),%ymm0
 1272d3d:	c5 fc 10 49 20       	vmovups 0x20(%rcx),%ymm1
 1272d42:	c5 fc 10 51 38       	vmovups 0x38(%rcx),%ymm2
 1272d47:	c5 fc 10 9d 10 fe ff 	vmovups -0x1f0(%rbp),%ymm3
 1272d4e:	ff 
 1272d4f:	c5 fc 11 9d 38 fa ff 	vmovups %ymm3,-0x5c8(%rbp)
 1272d56:	ff 
 1272d57:	41 80 e4 01          	and    $0x1,%r12b
 1272d5b:	44 88 a5 39 fc ff ff 	mov    %r12b,-0x3c7(%rbp)
 1272d62:	48 c7 85 28 fa ff ff 	movq   $0x0,-0x5d8(%rbp)
 1272d69:	00 00 00 00 
 1272d6d:	24 01                	and    $0x1,%al
 1272d6f:	88 85 3d fc ff ff    	mov    %al,-0x3c3(%rbp)
 1272d75:	c6 85 3c fc ff ff 00 	movb   $0x0,-0x3c4(%rbp)
 1272d7c:	c5 fc 11 85 58 fa ff 	vmovups %ymm0,-0x5a8(%rbp)
 1272d83:	ff 
 1272d84:	c5 fc 11 8d 78 fa ff 	vmovups %ymm1,-0x588(%rbp)
 1272d8b:	ff 
 1272d8c:	c5 fc 11 95 90 fa ff 	vmovups %ymm2,-0x570(%rbp)
 1272d93:	ff 
 1272d94:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 1272d99:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 1272d9f:	c4 c1 7c 10 56 40    	vmovups 0x40(%r14),%ymm2
 1272da5:	c4 c1 7c 10 5e 50    	vmovups 0x50(%r14),%ymm3
 1272dab:	c5 fc 11 9d 00 fb ff 	vmovups %ymm3,-0x500(%rbp)
 1272db2:	ff 
 1272db3:	c5 fc 11 95 f0 fa ff 	vmovups %ymm2,-0x510(%rbp)
 1272dba:	ff 
 1272dbb:	c5 fc 11 8d d0 fa ff 	vmovups %ymm1,-0x530(%rbp)
 1272dc2:	ff 
 1272dc3:	c5 fc 11 85 b0 fa ff 	vmovups %ymm0,-0x550(%rbp)
 1272dca:	ff 
 1272dcb:	48 89 9d 20 fb ff ff 	mov    %rbx,-0x4e0(%rbp)
 1272dd2:	48 8b 45 40          	mov    0x40(%rbp),%rax
 1272dd6:	48 89 85 28 fb ff ff 	mov    %rax,-0x4d8(%rbp)
 1272ddd:	48 8b 45 48          	mov    0x48(%rbp),%rax
 1272de1:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1272de5:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1272dea:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1272def:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1272df4:	c5 fc 11 9d 80 fb ff 	vmovups %ymm3,-0x480(%rbp)
 1272dfb:	ff 
 1272dfc:	c5 fc 11 95 70 fb ff 	vmovups %ymm2,-0x490(%rbp)
 1272e03:	ff 
 1272e04:	c5 fc 11 8d 50 fb ff 	vmovups %ymm1,-0x4b0(%rbp)
 1272e0b:	ff 
 1272e0c:	c5 fc 11 85 30 fb ff 	vmovups %ymm0,-0x4d0(%rbp)
 1272e13:	ff 
 1272e14:	48 8b 45 50          	mov    0x50(%rbp),%rax
 1272e18:	48 89 85 a0 fb ff ff 	mov    %rax,-0x460(%rbp)
 1272e1f:	48 8b 45 58          	mov    0x58(%rbp),%rax
 1272e23:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1272e27:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1272e2c:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1272e31:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1272e36:	c5 fc 11 9d f8 fb ff 	vmovups %ymm3,-0x408(%rbp)
 1272e3d:	ff 
 1272e3e:	c5 fc 11 95 e8 fb ff 	vmovups %ymm2,-0x418(%rbp)
 1272e45:	ff 
 1272e46:	c5 fc 11 8d c8 fb ff 	vmovups %ymm1,-0x438(%rbp)
 1272e4d:	ff 
 1272e4e:	c5 fc 11 85 a8 fb ff 	vmovups %ymm0,-0x458(%rbp)
 1272e55:	ff 
 1272e56:	48 8b 45 60          	mov    0x60(%rbp),%rax
 1272e5a:	48 89 85 18 fc ff ff 	mov    %rax,-0x3e8(%rbp)
 1272e61:	c6 85 30 fc ff ff 38 	movb   $0x38,-0x3d0(%rbp)
 1272e68:	c6 85 38 fc ff ff 00 	movb   $0x0,-0x3c8(%rbp)
 1272e6f:	0f b7 05 ba 80 dc ff 	movzwl -0x237f46(%rip),%eax        # 103af30 <__anon_29470>
 1272e76:	66 89 85 32 fc ff ff 	mov    %ax,-0x3ce(%rbp)
 1272e7d:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 1272e81:	24 1f                	and    $0x1f,%al
 1272e83:	88 45 d7             	mov    %al,-0x29(%rbp)
 1272e86:	88 85 31 fc ff ff    	mov    %al,-0x3cf(%rbp)
 1272e8c:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 1272e90:	48 89 85 18 fa ff ff 	mov    %rax,-0x5e8(%rbp)
 1272e97:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1272e9b:	48 89 85 20 fa ff ff 	mov    %rax,-0x5e0(%rbp)
 1272ea2:	c7 85 34 fc ff ff 01 	movl   $0x1000101,-0x3cc(%rbp)
 1272ea9:	01 00 01 
 1272eac:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1272eb0:	48 89 85 28 fc ff ff 	mov    %rax,-0x3d8(%rbp)
 1272eb7:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 1272ebb:	48 89 85 20 fc ff ff 	mov    %rax,-0x3e0(%rbp)
 1272ec2:	66 c7 85 3a fc ff ff 	movw   $0x0,-0x3c6(%rbp)
 1272ec9:	00 00 
 1272ecb:	48 c7 85 30 fa ff ff 	movq   $0x0,-0x5d0(%rbp)
 1272ed2:	00 00 00 00 
 1272ed6:	48 83 ec 08          	sub    $0x8,%rsp
 1272eda:	48 8d 85 18 fa ff ff 	lea    -0x5e8(%rbp),%rax
 1272ee1:	4c 8d 95 30 fe ff ff 	lea    -0x1d0(%rbp),%r10
 1272ee8:	48 8d bd 50 ff ff ff 	lea    -0xb0(%rbp),%rdi
 1272eef:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 1272ef3:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1272efa:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 1272efe:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 1272f02:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 1272f06:	50                   	push   %rax
 1272f07:	41 52                	push   %r10
 1272f09:	ff 75 10             	push   0x10(%rbp)
 1272f0c:	c5 f8 77             	vzeroupper 
 1272f0f:	e8 1c bc fb ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 1272f14:	48 83 c4 20          	add    $0x20,%rsp
 1272f18:	44 0f b7 bd 60 ff ff 	movzwl -0xa0(%rbp),%r15d
 1272f1f:	ff 
 1272f20:	4d 85 ff             	test   %r15,%r15
 1272f23:	0f 85 3b 0b 00 00    	jne    1273a64 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xee4>
 1272f29:	48 85 db             	test   %rbx,%rbx
 1272f2c:	0f 94 c0             	sete   %al
 1272f2f:	4c 8b bd 50 ff ff ff 	mov    -0xb0(%rbp),%r15
 1272f36:	4c 8b a5 58 ff ff ff 	mov    -0xa8(%rbp),%r12
 1272f3d:	41 80 7e 68 00       	cmpb   $0x0,0x68(%r14)
 1272f42:	0f 94 c1             	sete   %cl
 1272f45:	84 c1                	test   %al,%cl
 1272f47:	0f 84 f0 08 00 00    	je     127383d <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xcbd>
 1272f4d:	0f b6 85 41 f5 ff ff 	movzbl -0xabf(%rbp),%eax
 1272f54:	48 83 e0 03          	and    $0x3,%rax
 1272f58:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 1272f5f:	0f 84 37 05 00 00    	je     127349c <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x91c>
 1272f65:	31 c9                	xor    %ecx,%ecx
 1272f67:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 1272f6b:	eb 74                	jmp    1272fe1 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x461>
 1272f6d:	0f 1f 00             	nopl   (%rax)
 1272f70:	c5 fc 10 85 40 fd ff 	vmovups -0x2c0(%rbp),%ymm0
 1272f77:	ff 
 1272f78:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1272f7f:	ff 
 1272f80:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 1272f87:	ff 
 1272f88:	c5 fc 10 8d f0 fc ff 	vmovups -0x310(%rbp),%ymm1
 1272f8f:	ff 
 1272f90:	c5 fc 10 95 10 fd ff 	vmovups -0x2f0(%rbp),%ymm2
 1272f97:	ff 
 1272f98:	c5 fc 10 9d 30 fd ff 	vmovups -0x2d0(%rbp),%ymm3
 1272f9f:	ff 
 1272fa0:	c5 fc 11 9d 90 fe ff 	vmovups %ymm3,-0x170(%rbp)
 1272fa7:	ff 
 1272fa8:	c5 fc 11 95 70 fe ff 	vmovups %ymm2,-0x190(%rbp)
 1272faf:	ff 
 1272fb0:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 1272fb7:	ff 
 1272fb8:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 1272fbf:	ff 
 1272fc0:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1272fc4:	48 8b 8d 68 ff ff ff 	mov    -0x98(%rbp),%rcx
 1272fcb:	48 ff c1             	inc    %rcx
 1272fce:	49 89 dc             	mov    %rbx,%r12
 1272fd1:	49 89 c7             	mov    %rax,%r15
 1272fd4:	48 3b 8d 70 ff ff ff 	cmp    -0x90(%rbp),%rcx
 1272fdb:	0f 84 c5 04 00 00    	je     12734a6 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x926>
 1272fe1:	4d 89 e6             	mov    %r12,%r14
 1272fe4:	48 89 8d 68 ff ff ff 	mov    %rcx,-0x98(%rbp)
 1272feb:	48 8d 04 89          	lea    (%rcx,%rcx,4),%rax
 1272fef:	48 c1 e0 04          	shl    $0x4,%rax
 1272ff3:	48 8d 8d 50 f4 ff ff 	lea    -0xbb0(%rbp),%rcx
 1272ffa:	c5 fc 10 04 01       	vmovups (%rcx,%rax,1),%ymm0
 1272fff:	c5 fc 10 4c 01 20    	vmovups 0x20(%rcx,%rax,1),%ymm1
 1273005:	c5 fc 10 54 01 30    	vmovups 0x30(%rcx,%rax,1),%ymm2
 127300b:	48 8d 8d 88 f5 ff ff 	lea    -0xa78(%rbp),%rcx
 1273012:	c5 fc 11 51 30       	vmovups %ymm2,0x30(%rcx)
 1273017:	c5 fc 11 49 20       	vmovups %ymm1,0x20(%rcx)
 127301c:	c5 fc 11 01          	vmovups %ymm0,(%rcx)
 1273020:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 1273024:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 127302b:	ff 
 127302c:	c5 fc 11 41 e0       	vmovups %ymm0,-0x20(%rcx)
 1273031:	88 85 69 f7 ff ff    	mov    %al,-0x897(%rbp)
 1273037:	0f b6 85 40 f5 ff ff 	movzbl -0xac0(%rbp),%eax
 127303e:	48 c7 85 58 f5 ff ff 	movq   $0x0,-0xaa8(%rbp)
 1273045:	00 00 00 00 
 1273049:	88 85 6d f7 ff ff    	mov    %al,-0x893(%rbp)
 127304f:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 1273056:	ff 
 1273057:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 127305e:	ff 
 127305f:	c5 fc 10 85 80 fd ff 	vmovups -0x280(%rbp),%ymm0
 1273066:	ff 
 1273067:	c5 fc 10 8d a0 fd ff 	vmovups -0x260(%rbp),%ymm1
 127306e:	ff 
 127306f:	c5 fc 10 95 c0 fd ff 	vmovups -0x240(%rbp),%ymm2
 1273076:	ff 
 1273077:	c5 fc 10 9d e0 fd ff 	vmovups -0x220(%rbp),%ymm3
 127307e:	ff 
 127307f:	c5 fc 11 9d 30 fd ff 	vmovups %ymm3,-0x2d0(%rbp)
 1273086:	ff 
 1273087:	c5 fc 11 95 10 fd ff 	vmovups %ymm2,-0x2f0(%rbp)
 127308e:	ff 
 127308f:	c5 fc 11 8d f0 fc ff 	vmovups %ymm1,-0x310(%rbp)
 1273096:	ff 
 1273097:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 127309e:	ff 
 127309f:	c6 85 6c f7 ff ff 00 	movb   $0x0,-0x894(%rbp)
 12730a6:	c6 85 d8 f5 ff ff 01 	movb   $0x1,-0xa28(%rbp)
 12730ad:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12730b1:	c5 fc 11 81 b8 00 00 	vmovups %ymm0,0xb8(%rcx)
 12730b8:	00 
 12730b9:	c5 fc 11 81 98 00 00 	vmovups %ymm0,0x98(%rcx)
 12730c0:	00 
 12730c1:	c5 fc 11 41 78       	vmovups %ymm0,0x78(%rcx)
 12730c6:	c5 fc 11 41 58       	vmovups %ymm0,0x58(%rcx)
 12730cb:	48 8b 45 48          	mov    0x48(%rbp),%rax
 12730cf:	c5 fc 10 00          	vmovups (%rax),%ymm0
 12730d3:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 12730d8:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 12730dd:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 12730e2:	c5 fc 11 99 28 01 00 	vmovups %ymm3,0x128(%rcx)
 12730e9:	00 
 12730ea:	c5 fc 11 91 18 01 00 	vmovups %ymm2,0x118(%rcx)
 12730f1:	00 
 12730f2:	c5 fc 11 89 f8 00 00 	vmovups %ymm1,0xf8(%rcx)
 12730f9:	00 
 12730fa:	c5 fc 11 81 d8 00 00 	vmovups %ymm0,0xd8(%rcx)
 1273101:	00 
 1273102:	48 8b 45 50          	mov    0x50(%rbp),%rax
 1273106:	48 89 85 d0 f6 ff ff 	mov    %rax,-0x930(%rbp)
 127310d:	48 8b 45 58          	mov    0x58(%rbp),%rax
 1273111:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1273115:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 127311a:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 127311f:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1273124:	c5 fc 11 99 a0 01 00 	vmovups %ymm3,0x1a0(%rcx)
 127312b:	00 
 127312c:	c5 fc 11 91 90 01 00 	vmovups %ymm2,0x190(%rcx)
 1273133:	00 
 1273134:	c5 fc 11 89 70 01 00 	vmovups %ymm1,0x170(%rcx)
 127313b:	00 
 127313c:	c5 fc 11 81 50 01 00 	vmovups %ymm0,0x150(%rcx)
 1273143:	00 
 1273144:	48 8b 45 60          	mov    0x60(%rbp),%rax
 1273148:	48 89 85 48 f7 ff ff 	mov    %rax,-0x8b8(%rbp)
 127314f:	c6 85 60 f7 ff ff 38 	movb   $0x38,-0x8a0(%rbp)
 1273156:	c6 85 68 f7 ff ff 00 	movb   $0x0,-0x898(%rbp)
 127315d:	0f b7 05 cc 7d dc ff 	movzwl -0x238234(%rip),%eax        # 103af30 <__anon_29470>
 1273164:	66 89 85 62 f7 ff ff 	mov    %ax,-0x89e(%rbp)
 127316b:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 127316f:	88 85 61 f7 ff ff    	mov    %al,-0x89f(%rbp)
 1273175:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 1273179:	48 89 85 48 f5 ff ff 	mov    %rax,-0xab8(%rbp)
 1273180:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1273184:	48 89 85 50 f5 ff ff 	mov    %rax,-0xab0(%rbp)
 127318b:	c7 85 64 f7 ff ff 01 	movl   $0x1000101,-0x89c(%rbp)
 1273192:	01 00 01 
 1273195:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1273199:	48 89 85 58 f7 ff ff 	mov    %rax,-0x8a8(%rbp)
 12731a0:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 12731a4:	48 89 85 50 f7 ff ff 	mov    %rax,-0x8b0(%rbp)
 12731ab:	66 c7 85 6a f7 ff ff 	movw   $0x0,-0x896(%rbp)
 12731b2:	00 00 
 12731b4:	48 c7 85 60 f5 ff ff 	movq   $0x0,-0xaa0(%rbp)
 12731bb:	00 00 00 00 
 12731bf:	48 83 ec 08          	sub    $0x8,%rsp
 12731c3:	48 8d bd 38 ff ff ff 	lea    -0xc8(%rbp),%rdi
 12731ca:	4c 89 ee             	mov    %r13,%rsi
 12731cd:	4d 89 ec             	mov    %r13,%r12
 12731d0:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 12731d7:	4c 89 ea             	mov    %r13,%rdx
 12731da:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 12731de:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 12731e2:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 12731e6:	48 8d 85 48 f5 ff ff 	lea    -0xab8(%rbp),%rax
 12731ed:	50                   	push   %rax
 12731ee:	48 8d 85 d0 fc ff ff 	lea    -0x330(%rbp),%rax
 12731f5:	50                   	push   %rax
 12731f6:	ff 75 10             	push   0x10(%rbp)
 12731f9:	c5 f8 77             	vzeroupper 
 12731fc:	e8 2f b9 fb ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 1273201:	48 83 c4 20          	add    $0x20,%rsp
 1273205:	0f b7 9d 48 ff ff ff 	movzwl -0xb8(%rbp),%ebx
 127320c:	48 85 db             	test   %rbx,%rbx
 127320f:	0f 85 f7 07 00 00    	jne    1273a0c <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe8c>
 1273215:	48 8b b5 38 ff ff ff 	mov    -0xc8(%rbp),%rsi
 127321c:	48 8b 9d 40 ff ff ff 	mov    -0xc0(%rbp),%rbx
 1273223:	48 8d bd 60 fd ff ff 	lea    -0x2a0(%rbp),%rdi
 127322a:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 127322e:	48 89 da             	mov    %rbx,%rdx
 1273231:	4c 89 f9             	mov    %r15,%rcx
 1273234:	4d 89 f0             	mov    %r14,%r8
 1273237:	e8 a4 ad fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 127323c:	49 8b 4c 24 10       	mov    0x10(%r12),%rcx
 1273241:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 1273245:	4d 8b 4d 08          	mov    0x8(%r13),%r9
 1273249:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 127324d:	4c 8b a1 20 30 02 00 	mov    0x23020(%rcx),%r12
 1273254:	a8 01                	test   $0x1,%al
 1273256:	0f 84 84 00 00 00    	je     12732e0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x760>
 127325c:	4d 85 e4             	test   %r12,%r12
 127325f:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 1273263:	74 5b                	je     12732c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x740>
 1273265:	49 83 fc 01          	cmp    $0x1,%r12
 1273269:	0f 85 ee 00 00 00    	jne    127335d <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7dd>
 127326f:	31 c0                	xor    %eax,%eax
 1273271:	41 f6 c4 01          	test   $0x1,%r12b
 1273275:	74 49                	je     12732c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x740>
 1273277:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 127327e:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 1273285:	00 00 
 1273287:	41 80 e0 0f          	and    $0xf,%r8b
 127328b:	41 80 f8 07          	cmp    $0x7,%r8b
 127328f:	75 2f                	jne    12732c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x740>
 1273291:	48 01 f2             	add    %rsi,%rdx
 1273294:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 1273298:	74 26                	je     12732c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x740>
 127329a:	4c 39 72 38          	cmp    %r14,0x38(%rdx)
 127329e:	75 20                	jne    12732c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x740>
 12732a0:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 12732a7:	00 
 12732a8:	75 16                	jne    12732c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x740>
 12732aa:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12732b1:	00 
 12732b2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12732b9:	1f 84 00 00 00 00 00 
 12732c0:	4d 85 f6             	test   %r14,%r14
 12732c3:	0f 84 a7 fc ff ff    	je     1272f70 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x3f0>
 12732c9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12732cd:	4c 89 fe             	mov    %r15,%rsi
 12732d0:	4c 89 f2             	mov    %r14,%rdx
 12732d3:	31 c9                	xor    %ecx,%ecx
 12732d5:	41 ff 51 18          	call   *0x18(%r9)
 12732d9:	e9 92 fc ff ff       	jmp    1272f70 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x3f0>
 12732de:	66 90                	xchg   %ax,%ax
 12732e0:	4d 85 e4             	test   %r12,%r12
 12732e3:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 12732e7:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 12732eb:	74 53                	je     1273340 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7c0>
 12732ed:	49 83 fc 01          	cmp    $0x1,%r12
 12732f1:	0f 85 05 01 00 00    	jne    12733fc <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x87c>
 12732f7:	31 c0                	xor    %eax,%eax
 12732f9:	41 f6 c4 01          	test   $0x1,%r12b
 12732fd:	74 41                	je     1273340 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7c0>
 12732ff:	4c 69 d0 18 01 00 00 	imul   $0x118,%rax,%r10
 1273306:	46 0f b6 84 12 10 01 	movzbl 0x110(%rdx,%r10,1),%r8d
 127330d:	00 00 
 127330f:	41 80 e0 0f          	and    $0xf,%r8b
 1273313:	41 80 f8 07          	cmp    $0x7,%r8b
 1273317:	75 27                	jne    1273340 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7c0>
 1273319:	4c 01 d2             	add    %r10,%rdx
 127331c:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 1273320:	74 1e                	je     1273340 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7c0>
 1273322:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 1273326:	75 18                	jne    1273340 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7c0>
 1273328:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 127332f:	00 
 1273330:	75 0e                	jne    1273340 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7c0>
 1273332:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1273339:	00 
 127333a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1273340:	48 85 db             	test   %rbx,%rbx
 1273343:	74 0d                	je     1273352 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7d2>
 1273345:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1273349:	48 89 da             	mov    %rbx,%rdx
 127334c:	31 c9                	xor    %ecx,%ecx
 127334e:	41 ff 51 18          	call   *0x18(%r9)
 1273352:	4c 89 f8             	mov    %r15,%rax
 1273355:	4c 89 f3             	mov    %r14,%rbx
 1273358:	e9 67 fc ff ff       	jmp    1272fc4 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x444>
 127335d:	4d 89 e0             	mov    %r12,%r8
 1273360:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1273364:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1273368:	31 c0                	xor    %eax,%eax
 127336a:	eb 18                	jmp    1273384 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x804>
 127336c:	0f 1f 40 00          	nopl   0x0(%rax)
 1273370:	48 83 c0 02          	add    $0x2,%rax
 1273374:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127337b:	49 39 c0             	cmp    %rax,%r8
 127337e:	0f 84 ed fe ff ff    	je     1273271 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x6f1>
 1273384:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127338b:	00 
 127338c:	41 80 e3 0f          	and    $0xf,%r11b
 1273390:	41 80 fb 07          	cmp    $0x7,%r11b
 1273394:	75 2a                	jne    12733c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x840>
 1273396:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127339b:	74 23                	je     12733c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x840>
 127339d:	4d 39 32             	cmp    %r14,(%r10)
 12733a0:	75 1e                	jne    12733c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x840>
 12733a2:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 12733a9:	00 
 12733aa:	75 14                	jne    12733c0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x840>
 12733ac:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12733b3:	00 
 12733b4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 12733bb:	00 00 00 00 00 
 12733c0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12733c7:	00 
 12733c8:	41 80 e3 0f          	and    $0xf,%r11b
 12733cc:	41 80 fb 07          	cmp    $0x7,%r11b
 12733d0:	75 9e                	jne    1273370 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7f0>
 12733d2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12733d9:	00 
 12733da:	74 94                	je     1273370 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7f0>
 12733dc:	4d 39 b2 18 01 00 00 	cmp    %r14,0x118(%r10)
 12733e3:	75 8b                	jne    1273370 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7f0>
 12733e5:	4c 39 bc c1 d8 32 02 	cmp    %r15,0x232d8(%rcx,%rax,8)
 12733ec:	00 
 12733ed:	75 81                	jne    1273370 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7f0>
 12733ef:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12733f6:	00 
 12733f7:	e9 74 ff ff ff       	jmp    1273370 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x7f0>
 12733fc:	4d 89 e0             	mov    %r12,%r8
 12733ff:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1273403:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1273407:	31 c0                	xor    %eax,%eax
 1273409:	eb 19                	jmp    1273424 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x8a4>
 127340b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1273410:	48 83 c0 02          	add    $0x2,%rax
 1273414:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127341b:	49 39 c0             	cmp    %rax,%r8
 127341e:	0f 84 d5 fe ff ff    	je     12732f9 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x779>
 1273424:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127342b:	00 
 127342c:	41 80 e3 0f          	and    $0xf,%r11b
 1273430:	41 80 fb 07          	cmp    $0x7,%r11b
 1273434:	75 2a                	jne    1273460 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x8e0>
 1273436:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127343b:	74 23                	je     1273460 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x8e0>
 127343d:	49 39 1a             	cmp    %rbx,(%r10)
 1273440:	75 1e                	jne    1273460 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x8e0>
 1273442:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1273449:	00 
 127344a:	75 14                	jne    1273460 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x8e0>
 127344c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1273453:	00 
 1273454:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127345b:	00 00 00 00 00 
 1273460:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1273467:	00 
 1273468:	41 80 e3 0f          	and    $0xf,%r11b
 127346c:	41 80 fb 07          	cmp    $0x7,%r11b
 1273470:	75 9e                	jne    1273410 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x890>
 1273472:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1273479:	00 
 127347a:	74 94                	je     1273410 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x890>
 127347c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1273483:	75 8b                	jne    1273410 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x890>
 1273485:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 127348c:	00 
 127348d:	75 81                	jne    1273410 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x890>
 127348f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1273496:	00 
 1273497:	e9 74 ff ff ff       	jmp    1273410 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0x890>
 127349c:	4c 89 f8             	mov    %r15,%rax
 127349f:	4c 89 e3             	mov    %r12,%rbx
 12734a2:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 12734a6:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 12734aa:	80 bd 42 f5 ff ff 00 	cmpb   $0x0,-0xabe(%rbp)
 12734b1:	0f 84 7f 03 00 00    	je     1273836 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xcb6>
 12734b7:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 12734be:	ff 
 12734bf:	c5 fc 11 85 b0 fc ff 	vmovups %ymm0,-0x350(%rbp)
 12734c6:	ff 
 12734c7:	c5 fc 10 85 80 fd ff 	vmovups -0x280(%rbp),%ymm0
 12734ce:	ff 
 12734cf:	c5 fc 10 8d a0 fd ff 	vmovups -0x260(%rbp),%ymm1
 12734d6:	ff 
 12734d7:	c5 fc 10 95 c0 fd ff 	vmovups -0x240(%rbp),%ymm2
 12734de:	ff 
 12734df:	c5 fc 10 9d e0 fd ff 	vmovups -0x220(%rbp),%ymm3
 12734e6:	ff 
 12734e7:	c5 fc 11 9d a0 fc ff 	vmovups %ymm3,-0x360(%rbp)
 12734ee:	ff 
 12734ef:	c5 fc 11 95 80 fc ff 	vmovups %ymm2,-0x380(%rbp)
 12734f6:	ff 
 12734f7:	c5 fc 11 8d 60 fc ff 	vmovups %ymm1,-0x3a0(%rbp)
 12734fe:	ff 
 12734ff:	c5 fc 11 85 40 fc ff 	vmovups %ymm0,-0x3c0(%rbp)
 1273506:	ff 
 1273507:	0f b6 85 40 f5 ff ff 	movzbl -0xac0(%rbp),%eax
 127350e:	0f b6 4d d0          	movzbl -0x30(%rbp),%ecx
 1273512:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 1273519:	ff 
 127351a:	c5 fc 11 85 e8 f7 ff 	vmovups %ymm0,-0x818(%rbp)
 1273521:	ff 
 1273522:	88 8d e9 f9 ff ff    	mov    %cl,-0x617(%rbp)
 1273528:	48 c7 85 d8 f7 ff ff 	movq   $0x0,-0x828(%rbp)
 127352f:	00 00 00 00 
 1273533:	88 85 ed f9 ff ff    	mov    %al,-0x613(%rbp)
 1273539:	c6 85 ec f9 ff ff 00 	movb   $0x0,-0x614(%rbp)
 1273540:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1273544:	c5 fc 11 85 08 f8 ff 	vmovups %ymm0,-0x7f8(%rbp)
 127354b:	ff 
 127354c:	c5 fc 11 85 28 f8 ff 	vmovups %ymm0,-0x7d8(%rbp)
 1273553:	ff 
 1273554:	c5 fc 11 85 48 f8 ff 	vmovups %ymm0,-0x7b8(%rbp)
 127355b:	ff 
 127355c:	c5 fc 11 85 68 f8 ff 	vmovups %ymm0,-0x798(%rbp)
 1273563:	ff 
 1273564:	c5 fc 11 85 88 f8 ff 	vmovups %ymm0,-0x778(%rbp)
 127356b:	ff 
 127356c:	c5 fc 11 85 a8 f8 ff 	vmovups %ymm0,-0x758(%rbp)
 1273573:	ff 
 1273574:	c5 fc 11 85 c0 f8 ff 	vmovups %ymm0,-0x740(%rbp)
 127357b:	ff 
 127357c:	48 8b 45 48          	mov    0x48(%rbp),%rax
 1273580:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1273584:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1273589:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 127358e:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 1273593:	c5 fc 11 85 e0 f8 ff 	vmovups %ymm0,-0x720(%rbp)
 127359a:	ff 
 127359b:	c5 fc 11 8d 00 f9 ff 	vmovups %ymm1,-0x700(%rbp)
 12735a2:	ff 
 12735a3:	c5 fc 11 95 20 f9 ff 	vmovups %ymm2,-0x6e0(%rbp)
 12735aa:	ff 
 12735ab:	c5 fc 11 9d 30 f9 ff 	vmovups %ymm3,-0x6d0(%rbp)
 12735b2:	ff 
 12735b3:	48 8b 45 50          	mov    0x50(%rbp),%rax
 12735b7:	48 89 85 50 f9 ff ff 	mov    %rax,-0x6b0(%rbp)
 12735be:	48 8b 45 58          	mov    0x58(%rbp),%rax
 12735c2:	c5 fc 10 00          	vmovups (%rax),%ymm0
 12735c6:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 12735cb:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 12735d0:	c5 fc 10 58 50       	vmovups 0x50(%rax),%ymm3
 12735d5:	c5 fc 11 85 58 f9 ff 	vmovups %ymm0,-0x6a8(%rbp)
 12735dc:	ff 
 12735dd:	c5 fc 11 8d 78 f9 ff 	vmovups %ymm1,-0x688(%rbp)
 12735e4:	ff 
 12735e5:	c5 fc 11 95 98 f9 ff 	vmovups %ymm2,-0x668(%rbp)
 12735ec:	ff 
 12735ed:	c5 fc 11 9d a8 f9 ff 	vmovups %ymm3,-0x658(%rbp)
 12735f4:	ff 
 12735f5:	48 8b 45 60          	mov    0x60(%rbp),%rax
 12735f9:	48 89 85 c8 f9 ff ff 	mov    %rax,-0x638(%rbp)
 1273600:	c6 85 e0 f9 ff ff 38 	movb   $0x38,-0x620(%rbp)
 1273607:	c6 85 e8 f9 ff ff 00 	movb   $0x0,-0x618(%rbp)
 127360e:	0f b7 05 1b 79 dc ff 	movzwl -0x2386e5(%rip),%eax        # 103af30 <__anon_29470>
 1273615:	66 89 85 e2 f9 ff ff 	mov    %ax,-0x61e(%rbp)
 127361c:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 1273620:	88 85 e1 f9 ff ff    	mov    %al,-0x61f(%rbp)
 1273626:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 127362a:	48 89 85 c8 f7 ff ff 	mov    %rax,-0x838(%rbp)
 1273631:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1273635:	48 89 85 d0 f7 ff ff 	mov    %rax,-0x830(%rbp)
 127363c:	c7 85 e4 f9 ff ff 01 	movl   $0x1000101,-0x61c(%rbp)
 1273643:	01 00 01 
 1273646:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 127364a:	48 89 85 d8 f9 ff ff 	mov    %rax,-0x628(%rbp)
 1273651:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 1273655:	48 89 85 d0 f9 ff ff 	mov    %rax,-0x630(%rbp)
 127365c:	66 c7 85 ea f9 ff ff 	movw   $0x0,-0x616(%rbp)
 1273663:	00 00 
 1273665:	48 c7 85 e0 f7 ff ff 	movq   $0x0,-0x820(%rbp)
 127366c:	00 00 00 00 
 1273670:	48 83 ec 08          	sub    $0x8,%rsp
 1273674:	48 8d 85 c8 f7 ff ff 	lea    -0x838(%rbp),%rax
 127367b:	4c 8d 95 40 fc ff ff 	lea    -0x3c0(%rbp),%r10
 1273682:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1273689:	4c 89 ee             	mov    %r13,%rsi
 127368c:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 1273693:	4c 89 fa             	mov    %r15,%rdx
 1273696:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 127369a:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 127369e:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 12736a2:	50                   	push   %rax
 12736a3:	41 52                	push   %r10
 12736a5:	ff 75 10             	push   0x10(%rbp)
 12736a8:	c5 f8 77             	vzeroupper 
 12736ab:	e8 80 b4 fb ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 12736b0:	48 83 c4 20          	add    $0x20,%rsp
 12736b4:	44 0f b7 b5 30 ff ff 	movzwl -0xd0(%rbp),%r14d
 12736bb:	ff 
 12736bc:	4d 85 f6             	test   %r14,%r14
 12736bf:	0f 85 e8 03 00 00    	jne    1273aad <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xf2d>
 12736c5:	48 8b b5 20 ff ff ff 	mov    -0xe0(%rbp),%rsi
 12736cc:	4c 8b a5 28 ff ff ff 	mov    -0xd8(%rbp),%r12
 12736d3:	48 8d bd 60 fd ff ff 	lea    -0x2a0(%rbp),%rdi
 12736da:	49 89 f6             	mov    %rsi,%r14
 12736dd:	4c 89 e2             	mov    %r12,%rdx
 12736e0:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 12736e4:	49 89 d8             	mov    %rbx,%r8
 12736e7:	e8 f4 a8 fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 12736ec:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 12736f0:	49 8b 3f             	mov    (%r15),%rdi
 12736f3:	4d 8b 4f 08          	mov    0x8(%r15),%r9
 12736f7:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 12736fb:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 1273702:	a8 01                	test   $0x1,%al
 1273704:	0f 84 c5 00 00 00    	je     12737cf <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xc4f>
 127370a:	48 85 f6             	test   %rsi,%rsi
 127370d:	74 51                	je     1273760 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xbe0>
 127370f:	48 83 fe 01          	cmp    $0x1,%rsi
 1273713:	0f 85 9a 01 00 00    	jne    12738b3 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd33>
 1273719:	31 c0                	xor    %eax,%eax
 127371b:	40 f6 c6 01          	test   $0x1,%sil
 127371f:	74 3f                	je     1273760 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xbe0>
 1273721:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 1273728:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 127372f:	00 00 
 1273731:	41 80 e0 0f          	and    $0xf,%r8b
 1273735:	41 80 f8 07          	cmp    $0x7,%r8b
 1273739:	75 25                	jne    1273760 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xbe0>
 127373b:	48 01 f2             	add    %rsi,%rdx
 127373e:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 1273742:	74 1c                	je     1273760 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xbe0>
 1273744:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 1273748:	75 16                	jne    1273760 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xbe0>
 127374a:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 127374e:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 1273755:	00 
 1273756:	75 08                	jne    1273760 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xbe0>
 1273758:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 127375f:	00 
 1273760:	48 85 db             	test   %rbx,%rbx
 1273763:	74 11                	je     1273776 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xbf6>
 1273765:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1273769:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 127376d:	48 89 da             	mov    %rbx,%rdx
 1273770:	31 c9                	xor    %ecx,%ecx
 1273772:	41 ff 51 18          	call   *0x18(%r9)
 1273776:	c5 fc 10 85 b0 fc ff 	vmovups -0x350(%rbp),%ymm0
 127377d:	ff 
 127377e:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1273785:	ff 
 1273786:	c5 fc 10 85 40 fc ff 	vmovups -0x3c0(%rbp),%ymm0
 127378d:	ff 
 127378e:	c5 fc 10 8d 60 fc ff 	vmovups -0x3a0(%rbp),%ymm1
 1273795:	ff 
 1273796:	c5 fc 10 95 80 fc ff 	vmovups -0x380(%rbp),%ymm2
 127379d:	ff 
 127379e:	c5 fc 10 9d a0 fc ff 	vmovups -0x360(%rbp),%ymm3
 12737a5:	ff 
 12737a6:	c5 fc 11 9d 90 fe ff 	vmovups %ymm3,-0x170(%rbp)
 12737ad:	ff 
 12737ae:	c5 fc 11 95 70 fe ff 	vmovups %ymm2,-0x190(%rbp)
 12737b5:	ff 
 12737b6:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 12737bd:	ff 
 12737be:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 12737c5:	ff 
 12737c6:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12737ca:	4d 89 f7             	mov    %r14,%r15
 12737cd:	eb 72                	jmp    1273841 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xcc1>
 12737cf:	48 85 f6             	test   %rsi,%rsi
 12737d2:	74 4d                	je     1273821 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xca1>
 12737d4:	48 83 fe 01          	cmp    $0x1,%rsi
 12737d8:	0f 85 86 01 00 00    	jne    1273964 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xde4>
 12737de:	31 c0                	xor    %eax,%eax
 12737e0:	40 f6 c6 01          	test   $0x1,%sil
 12737e4:	74 3b                	je     1273821 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xca1>
 12737e6:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 12737ed:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 12737f4:	00 00 
 12737f6:	41 80 e0 0f          	and    $0xf,%r8b
 12737fa:	41 80 f8 07          	cmp    $0x7,%r8b
 12737fe:	75 21                	jne    1273821 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xca1>
 1273800:	48 01 f2             	add    %rsi,%rdx
 1273803:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 1273807:	74 18                	je     1273821 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xca1>
 1273809:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 127380d:	75 12                	jne    1273821 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xca1>
 127380f:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1273816:	00 
 1273817:	75 08                	jne    1273821 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xca1>
 1273819:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1273820:	00 
 1273821:	4d 85 e4             	test   %r12,%r12
 1273824:	74 10                	je     1273836 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xcb6>
 1273826:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 127382a:	4c 89 f6             	mov    %r14,%rsi
 127382d:	4c 89 e2             	mov    %r12,%rdx
 1273830:	31 c9                	xor    %ecx,%ecx
 1273832:	41 ff 51 18          	call   *0x18(%r9)
 1273836:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 127383a:	49 89 dc             	mov    %rbx,%r12
 127383d:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1273841:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 1273848:	ff 
 1273849:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 127384e:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1273855:	ff 
 1273856:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 127385d:	ff 
 127385e:	c5 fc 10 95 70 fe ff 	vmovups -0x190(%rbp),%ymm2
 1273865:	ff 
 1273866:	c5 fc 10 9d 90 fe ff 	vmovups -0x170(%rbp),%ymm3
 127386d:	ff 
 127386e:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1273873:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1273878:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 127387d:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1273881:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 1273888:	c5 f8 77             	vzeroupper 
 127388b:	e8 e0 38 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1273890:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1273894:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 127389a:	4c 89 38             	mov    %r15,(%rax)
 127389d:	4c 89 60 08          	mov    %r12,0x8(%rax)
 12738a1:	48 81 c4 f8 0b 00 00 	add    $0xbf8,%rsp
 12738a8:	5b                   	pop    %rbx
 12738a9:	41 5c                	pop    %r12
 12738ab:	41 5d                	pop    %r13
 12738ad:	41 5e                	pop    %r14
 12738af:	41 5f                	pop    %r15
 12738b1:	5d                   	pop    %rbp
 12738b2:	c3                   	ret    
 12738b3:	49 89 f0             	mov    %rsi,%r8
 12738b6:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12738ba:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12738be:	31 c0                	xor    %eax,%eax
 12738c0:	eb 22                	jmp    12738e4 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd64>
 12738c2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12738c9:	1f 84 00 00 00 00 00 
 12738d0:	48 83 c0 02          	add    $0x2,%rax
 12738d4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12738db:	49 39 c0             	cmp    %rax,%r8
 12738de:	0f 84 37 fe ff ff    	je     127371b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xb9b>
 12738e4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12738eb:	00 
 12738ec:	41 80 e3 0f          	and    $0xf,%r11b
 12738f0:	41 80 fb 07          	cmp    $0x7,%r11b
 12738f4:	75 2a                	jne    1273920 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xda0>
 12738f6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12738fb:	74 23                	je     1273920 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xda0>
 12738fd:	49 39 1a             	cmp    %rbx,(%r10)
 1273900:	75 1e                	jne    1273920 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xda0>
 1273902:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 1273906:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 127390d:	00 
 127390e:	75 10                	jne    1273920 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xda0>
 1273910:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1273917:	00 
 1273918:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 127391f:	00 
 1273920:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1273927:	00 
 1273928:	41 80 e3 0f          	and    $0xf,%r11b
 127392c:	41 80 fb 07          	cmp    $0x7,%r11b
 1273930:	75 9e                	jne    12738d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd50>
 1273932:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1273939:	00 
 127393a:	74 94                	je     12738d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd50>
 127393c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1273943:	75 8b                	jne    12738d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd50>
 1273945:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 1273949:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1273950:	00 
 1273951:	0f 85 79 ff ff ff    	jne    12738d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd50>
 1273957:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 127395e:	00 
 127395f:	e9 6c ff ff ff       	jmp    12738d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd50>
 1273964:	49 89 f0             	mov    %rsi,%r8
 1273967:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 127396b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 127396f:	31 c0                	xor    %eax,%eax
 1273971:	eb 21                	jmp    1273994 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe14>
 1273973:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 127397a:	84 00 00 00 00 00 
 1273980:	48 83 c0 02          	add    $0x2,%rax
 1273984:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127398b:	49 39 c0             	cmp    %rax,%r8
 127398e:	0f 84 4c fe ff ff    	je     12737e0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xc60>
 1273994:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127399b:	00 
 127399c:	41 80 e3 0f          	and    $0xf,%r11b
 12739a0:	41 80 fb 07          	cmp    $0x7,%r11b
 12739a4:	75 2a                	jne    12739d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe50>
 12739a6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12739ab:	74 23                	je     12739d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe50>
 12739ad:	4d 39 22             	cmp    %r12,(%r10)
 12739b0:	75 1e                	jne    12739d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe50>
 12739b2:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 12739b9:	00 
 12739ba:	75 14                	jne    12739d0 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe50>
 12739bc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12739c3:	00 
 12739c4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 12739cb:	00 00 00 00 00 
 12739d0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12739d7:	00 
 12739d8:	41 80 e3 0f          	and    $0xf,%r11b
 12739dc:	41 80 fb 07          	cmp    $0x7,%r11b
 12739e0:	75 9e                	jne    1273980 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe00>
 12739e2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12739e9:	00 
 12739ea:	74 94                	je     1273980 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe00>
 12739ec:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 12739f3:	75 8b                	jne    1273980 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe00>
 12739f5:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 12739fc:	00 
 12739fd:	75 81                	jne    1273980 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe00>
 12739ff:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1273a06:	00 
 1273a07:	e9 74 ff ff ff       	jmp    1273980 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xe00>
 1273a0c:	4c 89 e7             	mov    %r12,%rdi
 1273a0f:	4c 89 ee             	mov    %r13,%rsi
 1273a12:	4c 89 fa             	mov    %r15,%rdx
 1273a15:	4c 89 f1             	mov    %r14,%rcx
 1273a18:	e8 83 2b 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1273a1d:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 1273a24:	74 25                	je     1273a4b <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xecb>
 1273a26:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 1273a2d:	48 69 8d f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rcx
 1273a34:	18 01 00 00 
 1273a38:	89 da                	mov    %ebx,%edx
 1273a3a:	c1 e2 04             	shl    $0x4,%edx
 1273a3d:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 1273a44:	01 
 1273a45:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 1273a4b:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 1273a52:	e8 19 37 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1273a57:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1273a5b:	66 89 58 10          	mov    %bx,0x10(%rax)
 1273a5f:	e9 3d fe ff ff       	jmp    12738a1 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd21>
 1273a64:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 1273a6b:	74 26                	je     1273a93 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xf13>
 1273a6d:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 1273a74:	48 69 8d f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rcx
 1273a7b:	18 01 00 00 
 1273a7f:	44 89 fa             	mov    %r15d,%edx
 1273a82:	c1 e2 04             	shl    $0x4,%edx
 1273a85:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 1273a8c:	01 
 1273a8d:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 1273a93:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 1273a9a:	e8 d1 36 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1273a9f:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1273aa3:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 1273aa8:	e9 f4 fd ff ff       	jmp    12738a1 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd21>
 1273aad:	4c 89 ef             	mov    %r13,%rdi
 1273ab0:	4c 89 fe             	mov    %r15,%rsi
 1273ab3:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1273ab7:	48 89 d9             	mov    %rbx,%rcx
 1273aba:	e8 e1 2a 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1273abf:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 1273ac6:	74 26                	je     1273aee <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xf6e>
 1273ac8:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 1273acf:	48 69 8d f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rcx
 1273ad6:	18 01 00 00 
 1273ada:	44 89 f2             	mov    %r14d,%edx
 1273add:	c1 e2 04             	shl    $0x4,%edx
 1273ae0:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 1273ae7:	01 
 1273ae8:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 1273aee:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 1273af5:	e8 76 36 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1273afa:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1273afe:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 1273b03:	e9 99 fd ff ff       	jmp    12738a1 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681+0xd21>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
