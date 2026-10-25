
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

00000000011b3de0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584>:
 11b3de0:	55                   	push   %rbp
 11b3de1:	48 89 e5             	mov    %rsp,%rbp
 11b3de4:	41 57                	push   %r15
 11b3de6:	41 56                	push   %r14
 11b3de8:	41 55                	push   %r13
 11b3dea:	41 54                	push   %r12
 11b3dec:	53                   	push   %rbx
 11b3ded:	48 81 ec 98 0f 00 00 	sub    $0xf98,%rsp
 11b3df4:	4c 89 cb             	mov    %r9,%rbx
 11b3df7:	4d 89 c7             	mov    %r8,%r15
 11b3dfa:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 11b3dfe:	48 89 55 c8          	mov    %rdx,-0x38(%rbp)
 11b3e02:	48 89 7d a8          	mov    %rdi,-0x58(%rbp)
 11b3e06:	c5 f8 10 06          	vmovups (%rsi),%xmm0
 11b3e0a:	c5 f8 29 85 60 fe ff 	vmovaps %xmm0,-0x1a0(%rbp)
 11b3e11:	ff 
 11b3e12:	48 8b 46 10          	mov    0x10(%rsi),%rax
 11b3e16:	48 8b 4e 18          	mov    0x18(%rsi),%rcx
 11b3e1a:	49 8b 51 58          	mov    0x58(%r9),%rdx
 11b3e1e:	48 89 95 20 ff ff ff 	mov    %rdx,-0xe0(%rbp)
 11b3e25:	49 8b 51 60          	mov    0x60(%r9),%rdx
 11b3e29:	48 89 95 28 ff ff ff 	mov    %rdx,-0xd8(%rbp)
 11b3e30:	41 0f b7 91 80 00 00 	movzwl 0x80(%r9),%edx
 11b3e37:	00 
 11b3e38:	89 95 20 fe ff ff    	mov    %edx,-0x1e0(%rbp)
 11b3e3e:	41 0f b6 91 85 00 00 	movzbl 0x85(%r9),%edx
 11b3e45:	00 
 11b3e46:	88 55 d7             	mov    %dl,-0x29(%rbp)
 11b3e49:	4d 8b a1 86 00 00 00 	mov    0x86(%r9),%r12
 11b3e50:	45 0f b6 a9 8e 00 00 	movzbl 0x8e(%r9),%r13d
 11b3e57:	00 
 11b3e58:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 11b3e5c:	c5 f8 10 06          	vmovups (%rsi),%xmm0
 11b3e60:	c5 f8 29 85 00 fb ff 	vmovaps %xmm0,-0x500(%rbp)
 11b3e67:	ff 
 11b3e68:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 11b3e6f:	48 89 85 10 fb ff ff 	mov    %rax,-0x4f0(%rbp)
 11b3e76:	48 89 8d 18 fe ff ff 	mov    %rcx,-0x1e8(%rbp)
 11b3e7d:	48 89 8d 18 fb ff ff 	mov    %rcx,-0x4e8(%rbp)
 11b3e84:	48 8d bd 80 f3 ff ff 	lea    -0xc80(%rbp),%rdi
 11b3e8b:	48 8d b5 00 fb ff ff 	lea    -0x500(%rbp),%rsi
 11b3e92:	ba 0a 00 00 00       	mov    $0xa,%edx
 11b3e97:	4c 89 c1             	mov    %r8,%rcx
 11b3e9a:	45 31 c0             	xor    %r8d,%r8d
 11b3e9d:	e8 ee 36 0c 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 11b3ea2:	c5 fc 10 85 80 f3 ff 	vmovups -0xc80(%rbp),%ymm0
 11b3ea9:	ff 
 11b3eaa:	c5 fc 10 8d a0 f3 ff 	vmovups -0xc60(%rbp),%ymm1
 11b3eb1:	ff 
 11b3eb2:	c5 fc 10 95 c0 f3 ff 	vmovups -0xc40(%rbp),%ymm2
 11b3eb9:	ff 
 11b3eba:	c5 fc 11 95 00 ff ff 	vmovups %ymm2,-0x100(%rbp)
 11b3ec1:	ff 
 11b3ec2:	c5 fc 11 8d e0 fe ff 	vmovups %ymm1,-0x120(%rbp)
 11b3ec9:	ff 
 11b3eca:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 11b3ed1:	ff 
 11b3ed2:	48 8d bd 28 fe ff ff 	lea    -0x1d8(%rbp),%rdi
 11b3ed9:	48 89 de             	mov    %rbx,%rsi
 11b3edc:	c5 f8 77             	vzeroupper 
 11b3edf:	e8 dc 2a 0c 00       	call   12769c0 <br.resolvedQualitySchedule>
 11b3ee4:	44 0f b7 b5 5c fe ff 	movzwl -0x1a4(%rbp),%r14d
 11b3eeb:	ff 
 11b3eec:	4d 85 f6             	test   %r14,%r14
 11b3eef:	0f 85 1c 1b 00 00    	jne    11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b3ef5:	44 88 6d 91          	mov    %r13b,-0x6f(%rbp)
 11b3ef9:	4c 89 a5 c0 fd ff ff 	mov    %r12,-0x240(%rbp)
 11b3f00:	4c 89 bd 70 fe ff ff 	mov    %r15,-0x190(%rbp)
 11b3f07:	8b 85 2c fe ff ff    	mov    -0x1d4(%rbp),%eax
 11b3f0d:	48 89 85 c8 fd ff ff 	mov    %rax,-0x238(%rbp)
 11b3f14:	8b 85 30 fe ff ff    	mov    -0x1d0(%rbp),%eax
 11b3f1a:	c5 fb 10 85 28 fe ff 	vmovsd -0x1d8(%rbp),%xmm0
 11b3f21:	ff 
 11b3f22:	c5 f8 29 85 20 fb ff 	vmovaps %xmm0,-0x4e0(%rbp)
 11b3f29:	ff 
 11b3f2a:	89 85 a0 fe ff ff    	mov    %eax,-0x160(%rbp)
 11b3f30:	0f b7 85 34 fe ff ff 	movzwl -0x1cc(%rbp),%eax
 11b3f37:	66 89 85 a4 fe ff ff 	mov    %ax,-0x15c(%rbp)
 11b3f3e:	0f b6 85 36 fe ff ff 	movzbl -0x1ca(%rbp),%eax
 11b3f45:	88 45 93             	mov    %al,-0x6d(%rbp)
 11b3f48:	0f b6 85 37 fe ff ff 	movzbl -0x1c9(%rbp),%eax
 11b3f4f:	88 45 96             	mov    %al,-0x6a(%rbp)
 11b3f52:	0f b7 85 3c fe ff ff 	movzwl -0x1c4(%rbp),%eax
 11b3f59:	48 89 85 78 fe ff ff 	mov    %rax,-0x188(%rbp)
 11b3f60:	0f b7 85 3e fe ff ff 	movzwl -0x1c2(%rbp),%eax
 11b3f67:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 11b3f6e:	0f b6 85 40 fe ff ff 	movzbl -0x1c0(%rbp),%eax
 11b3f75:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 11b3f79:	0f b7 85 42 fe ff ff 	movzwl -0x1be(%rbp),%eax
 11b3f80:	89 85 24 fe ff ff    	mov    %eax,-0x1dc(%rbp)
 11b3f86:	0f b6 85 44 fe ff ff 	movzbl -0x1bc(%rbp),%eax
 11b3f8d:	88 45 95             	mov    %al,-0x6b(%rbp)
 11b3f90:	0f b6 85 45 fe ff ff 	movzbl -0x1bb(%rbp),%eax
 11b3f97:	88 45 97             	mov    %al,-0x69(%rbp)
 11b3f9a:	0f b6 85 46 fe ff ff 	movzbl -0x1ba(%rbp),%eax
 11b3fa1:	88 45 c7             	mov    %al,-0x39(%rbp)
 11b3fa4:	0f b6 85 47 fe ff ff 	movzbl -0x1b9(%rbp),%eax
 11b3fab:	88 45 94             	mov    %al,-0x6c(%rbp)
 11b3fae:	0f b6 85 48 fe ff ff 	movzbl -0x1b8(%rbp),%eax
 11b3fb5:	88 85 a8 fe ff ff    	mov    %al,-0x158(%rbp)
 11b3fbb:	0f b6 85 4e fe ff ff 	movzbl -0x1b2(%rbp),%eax
 11b3fc2:	88 45 8f             	mov    %al,-0x71(%rbp)
 11b3fc5:	0f b6 85 4f fe ff ff 	movzbl -0x1b1(%rbp),%eax
 11b3fcc:	88 45 8b             	mov    %al,-0x75(%rbp)
 11b3fcf:	0f b6 85 50 fe ff ff 	movzbl -0x1b0(%rbp),%eax
 11b3fd6:	88 45 8c             	mov    %al,-0x74(%rbp)
 11b3fd9:	0f b6 85 51 fe ff ff 	movzbl -0x1af(%rbp),%eax
 11b3fe0:	88 85 90 fe ff ff    	mov    %al,-0x170(%rbp)
 11b3fe6:	0f b6 85 52 fe ff ff 	movzbl -0x1ae(%rbp),%eax
 11b3fed:	88 45 8a             	mov    %al,-0x76(%rbp)
 11b3ff0:	0f b6 85 53 fe ff ff 	movzbl -0x1ad(%rbp),%eax
 11b3ff7:	88 45 c6             	mov    %al,-0x3a(%rbp)
 11b3ffa:	0f b6 85 54 fe ff ff 	movzbl -0x1ac(%rbp),%eax
 11b4001:	88 45 8e             	mov    %al,-0x72(%rbp)
 11b4004:	0f b6 85 55 fe ff ff 	movzbl -0x1ab(%rbp),%eax
 11b400b:	88 45 8d             	mov    %al,-0x73(%rbp)
 11b400e:	80 bb 84 00 00 00 00 	cmpb   $0x0,0x84(%rbx)
 11b4015:	0f b6 85 56 fe ff ff 	movzbl -0x1aa(%rbp),%eax
 11b401c:	88 45 90             	mov    %al,-0x70(%rbp)
 11b401f:	0f b6 85 57 fe ff ff 	movzbl -0x1a9(%rbp),%eax
 11b4026:	88 45 b6             	mov    %al,-0x4a(%rbp)
 11b4029:	0f b6 85 58 fe ff ff 	movzbl -0x1a8(%rbp),%eax
 11b4030:	88 45 92             	mov    %al,-0x6e(%rbp)
 11b4033:	44 0f b6 b3 85 00 00 	movzbl 0x85(%rbx),%r14d
 11b403a:	00 
 11b403b:	44 0f b6 a3 87 00 00 	movzbl 0x87(%rbx),%r12d
 11b4042:	00 
 11b4043:	44 0f b6 ab 88 00 00 	movzbl 0x88(%rbx),%r13d
 11b404a:	00 
 11b404b:	74 50                	je     11b409d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x2bd>
 11b404d:	48 8d bd d0 fd ff ff 	lea    -0x230(%rbp),%rdi
 11b4054:	48 89 de             	mov    %rbx,%rsi
 11b4057:	e8 64 29 0c 00       	call   12769c0 <br.resolvedQualitySchedule>
 11b405c:	44 0f b7 bd 04 fe ff 	movzwl -0x1fc(%rbp),%r15d
 11b4063:	ff 
 11b4064:	66 45 85 ff          	test   %r15w,%r15w
 11b4068:	0f 85 da 03 00 00    	jne    11b4448 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x668>
 11b406e:	0f b6 8d f3 fd ff ff 	movzbl -0x20d(%rbp),%ecx
 11b4075:	41 f6 c6 01          	test   $0x1,%r14b
 11b4079:	74 62                	je     11b40dd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x2fd>
 11b407b:	45 84 ed             	test   %r13b,%r13b
 11b407e:	0f b6 c1             	movzbl %cl,%eax
 11b4081:	45 0f b6 ec          	movzbl %r12b,%r13d
 11b4085:	44 0f 44 e8          	cmove  %eax,%r13d
 11b4089:	41 8d 45 01          	lea    0x1(%r13),%eax
 11b408d:	24 1f                	and    $0x1f,%al
 11b408f:	66 41 bf 52 00       	mov    $0x52,%r15w
 11b4094:	3c 0b                	cmp    $0xb,%al
 11b4096:	73 7f                	jae    11b4117 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x337>
 11b4098:	e9 ab 03 00 00       	jmp    11b4448 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x668>
 11b409d:	45 84 ed             	test   %r13b,%r13b
 11b40a0:	41 0f b6 c4          	movzbl %r12b,%eax
 11b40a4:	41 bd 10 00 00 00    	mov    $0x10,%r13d
 11b40aa:	44 0f 45 e8          	cmovne %eax,%r13d
 11b40ae:	44 89 e8             	mov    %r13d,%eax
 11b40b1:	24 1f                	and    $0x1f,%al
 11b40b3:	41 f6 c6 01          	test   $0x1,%r14b
 11b40b7:	ba fe 00 00 00       	mov    $0xfe,%edx
 11b40bc:	b9 f8 00 00 00       	mov    $0xf8,%ecx
 11b40c1:	0f 45 ca             	cmovne %edx,%ecx
 11b40c4:	66 41 bf 52 00       	mov    $0x52,%r15w
 11b40c9:	3c 0a                	cmp    $0xa,%al
 11b40cb:	0f 82 77 03 00 00    	jb     11b4448 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x668>
 11b40d1:	80 e1 1f             	and    $0x1f,%cl
 11b40d4:	38 c8                	cmp    %cl,%al
 11b40d6:	76 3f                	jbe    11b4117 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x337>
 11b40d8:	e9 6b 03 00 00       	jmp    11b4448 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x668>
 11b40dd:	0f b7 85 f4 fd ff ff 	movzwl -0x20c(%rbp),%eax
 11b40e4:	45 84 ed             	test   %r13b,%r13b
 11b40e7:	0f b6 c9             	movzbl %cl,%ecx
 11b40ea:	45 0f b6 ec          	movzbl %r12b,%r13d
 11b40ee:	44 0f 44 e9          	cmove  %ecx,%r13d
 11b40f2:	41 80 e5 1f          	and    $0x1f,%r13b
 11b40f6:	89 c1                	mov    %eax,%ecx
 11b40f8:	80 e1 1f             	and    $0x1f,%cl
 11b40fb:	66 41 bf 52 00       	mov    $0x52,%r15w
 11b4100:	41 38 cd             	cmp    %cl,%r13b
 11b4103:	0f 82 3f 03 00 00    	jb     11b4448 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x668>
 11b4109:	c1 e8 08             	shr    $0x8,%eax
 11b410c:	24 1f                	and    $0x1f,%al
 11b410e:	41 38 c5             	cmp    %al,%r13b
 11b4111:	0f 87 31 03 00 00    	ja     11b4448 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x668>
 11b4117:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b411b:	c5 f8 29 85 60 fc ff 	vmovaps %xmm0,-0x3a0(%rbp)
 11b4122:	ff 
 11b4123:	48 c7 85 70 fc ff ff 	movq   $0x0,-0x390(%rbp)
 11b412a:	00 00 00 00 
 11b412e:	44 0f b6 65 d7       	movzbl -0x29(%rbp),%r12d
 11b4133:	41 80 e4 01          	and    $0x1,%r12b
 11b4137:	44 88 a5 88 fc ff ff 	mov    %r12b,-0x378(%rbp)
 11b413e:	44 89 e8             	mov    %r13d,%eax
 11b4141:	24 1f                	and    $0x1f,%al
 11b4143:	48 89 85 b8 fe ff ff 	mov    %rax,-0x148(%rbp)
 11b414a:	88 85 89 fc ff ff    	mov    %al,-0x377(%rbp)
 11b4150:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11b4157:	48 89 85 78 fc ff ff 	mov    %rax,-0x388(%rbp)
 11b415e:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11b4165:	48 89 85 80 fc ff ff 	mov    %rax,-0x380(%rbp)
 11b416c:	4c 8b bd 70 fe ff ff 	mov    -0x190(%rbp),%r15
 11b4173:	49 83 ff 04          	cmp    $0x4,%r15
 11b4177:	0f 87 86 00 00 00    	ja     11b4203 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x423>
 11b417d:	48 8d bd a0 fd ff ff 	lea    -0x260(%rbp),%rdi
 11b4184:	4c 8d 8d 60 fc ff ff 	lea    -0x3a0(%rbp),%r9
 11b418b:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11b418f:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 11b4193:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b4197:	4d 89 f8             	mov    %r15,%r8
 11b419a:	e8 01 27 0c 00       	call   12768a0 <br.encodeStoredStreamRecorded__anon_28729>
 11b419f:	0f b7 85 b0 fd ff ff 	movzwl -0x250(%rbp),%eax
 11b41a6:	48 85 c0             	test   %rax,%rax
 11b41a9:	74 2c                	je     11b41d7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x3f7>
 11b41ab:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 11b41b2:	74 23                	je     11b41d7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x3f7>
 11b41b4:	48 8b 8d e0 fe ff ff 	mov    -0x120(%rbp),%rcx
 11b41bb:	48 69 95 f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rdx
 11b41c2:	18 01 00 00 
 11b41c6:	c1 e0 04             	shl    $0x4,%eax
 11b41c9:	c5 f8 10 80 f0 5d 03 	vmovups 0x1035df0(%rax),%xmm0
 11b41d0:	01 
 11b41d1:	c5 f8 11 44 11 68    	vmovups %xmm0,0x68(%rcx,%rdx,1)
 11b41d7:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b41de:	e8 8d 2f 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b41e3:	48 8b 85 b0 fd ff ff 	mov    -0x250(%rbp),%rax
 11b41ea:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 11b41ee:	48 89 41 10          	mov    %rax,0x10(%rcx)
 11b41f2:	c5 f8 10 85 a0 fd ff 	vmovups -0x260(%rbp),%xmm0
 11b41f9:	ff 
 11b41fa:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 11b41fe:	e9 24 13 00 00       	jmp    11b5527 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1747>
 11b4203:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 11b4207:	24 0f                	and    $0xf,%al
 11b4209:	31 c9                	xor    %ecx,%ecx
 11b420b:	ba 00 00 00 00       	mov    $0x0,%edx
 11b4210:	88 45 c7             	mov    %al,-0x39(%rbp)
 11b4213:	3c 0b                	cmp    $0xb,%al
 11b4215:	0f 85 a8 00 00 00    	jne    11b42c3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x4e3>
 11b421b:	48 8d 83 85 00 00 00 	lea    0x85(%rbx),%rax
 11b4222:	8b 4b 7f             	mov    0x7f(%rbx),%ecx
 11b4225:	89 8d 0f f9 ff ff    	mov    %ecx,-0x6f1(%rbp)
 11b422b:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 11b422f:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 11b4234:	c5 fc 10 53 40       	vmovups 0x40(%rbx),%ymm2
 11b4239:	c5 fc 10 5b 60       	vmovups 0x60(%rbx),%ymm3
 11b423e:	c5 fc 11 9d f0 f8 ff 	vmovups %ymm3,-0x710(%rbp)
 11b4245:	ff 
 11b4246:	c5 fc 11 95 d0 f8 ff 	vmovups %ymm2,-0x730(%rbp)
 11b424d:	ff 
 11b424e:	c5 fc 11 8d b0 f8 ff 	vmovups %ymm1,-0x750(%rbp)
 11b4255:	ff 
 11b4256:	c5 fc 11 85 90 f8 ff 	vmovups %ymm0,-0x770(%rbp)
 11b425d:	ff 
 11b425e:	0f b7 0d c3 6a e8 ff 	movzwl -0x17953d(%rip),%ecx        # 103ad28 <__anon_28737>
 11b4265:	66 89 8d 13 f9 ff ff 	mov    %cx,-0x6ed(%rbp)
 11b426c:	48 8b 08             	mov    (%rax),%rcx
 11b426f:	48 89 8d 15 f9 ff ff 	mov    %rcx,-0x6eb(%rbp)
 11b4276:	8b 40 07             	mov    0x7(%rax),%eax
 11b4279:	89 85 1c f9 ff ff    	mov    %eax,-0x6e4(%rbp)
 11b427f:	48 8d bd 38 fc ff ff 	lea    -0x3c8(%rbp),%rdi
 11b4286:	4c 8d 8d 90 f8 ff ff 	lea    -0x770(%rbp),%r9
 11b428d:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11b4291:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 11b4295:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b4299:	4d 89 f8             	mov    %r15,%r8
 11b429c:	c5 f8 77             	vzeroupper 
 11b429f:	e8 3c fb ff ff       	call   11b3de0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584>
 11b42a4:	44 0f b7 b5 48 fc ff 	movzwl -0x3b8(%rbp),%r14d
 11b42ab:	ff 
 11b42ac:	4d 85 f6             	test   %r14,%r14
 11b42af:	0f 85 5c 17 00 00    	jne    11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b42b5:	48 8b 8d 38 fc ff ff 	mov    -0x3c8(%rbp),%rcx
 11b42bc:	48 8b 95 40 fc ff ff 	mov    -0x3c0(%rbp),%rdx
 11b42c3:	48 89 95 30 ff ff ff 	mov    %rdx,-0xd0(%rbp)
 11b42ca:	48 89 8d 48 ff ff ff 	mov    %rcx,-0xb8(%rbp)
 11b42d1:	44 88 65 b7          	mov    %r12b,-0x49(%rbp)
 11b42d5:	b8 01 00 00 00       	mov    $0x1,%eax
 11b42da:	48 8b 8d b8 fe ff ff 	mov    -0x148(%rbp),%rcx
 11b42e1:	c4 e2 f1 f7 c8       	shlx   %rcx,%rax,%rcx
 11b42e6:	48 83 c1 f0          	add    $0xfffffffffffffff0,%rcx
 11b42ea:	4c 39 f9             	cmp    %r15,%rcx
 11b42ed:	4c 89 f8             	mov    %r15,%rax
 11b42f0:	48 89 8d b8 fd ff ff 	mov    %rcx,-0x248(%rbp)
 11b42f7:	48 0f 42 c1          	cmovb  %rcx,%rax
 11b42fb:	48 3d ff ff 00 00    	cmp    $0xffff,%rax
 11b4301:	4d 89 fc             	mov    %r15,%r12
 11b4304:	41 bf ff ff 00 00    	mov    $0xffff,%r15d
 11b430a:	4c 0f 42 f8          	cmovb  %rax,%r15
 11b430e:	c5 f8 28 85 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm0
 11b4315:	ff 
 11b4316:	c5 f8 29 85 30 fd ff 	vmovaps %xmm0,-0x2d0(%rbp)
 11b431d:	ff 
 11b431e:	48 8b 8d 18 fe ff ff 	mov    -0x1e8(%rbp),%rcx
 11b4325:	48 89 ca             	mov    %rcx,%rdx
 11b4328:	48 c1 ea 08          	shr    $0x8,%rdx
 11b432c:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b4333:	48 89 85 40 fd ff ff 	mov    %rax,-0x2c0(%rbp)
 11b433a:	c6 85 48 fd ff ff 01 	movb   $0x1,-0x2b8(%rbp)
 11b4341:	48 89 c8             	mov    %rcx,%rax
 11b4344:	48 c1 e8 38          	shr    $0x38,%rax
 11b4348:	88 85 4f fd ff ff    	mov    %al,-0x2b1(%rbp)
 11b434e:	48 89 c8             	mov    %rcx,%rax
 11b4351:	48 c1 e8 28          	shr    $0x28,%rax
 11b4355:	66 89 85 4d fd ff ff 	mov    %ax,-0x2b3(%rbp)
 11b435c:	48 89 95 b0 fe ff ff 	mov    %rdx,-0x150(%rbp)
 11b4363:	89 95 49 fd ff ff    	mov    %edx,-0x2b7(%rbp)
 11b4369:	48 8d bd 10 fa ff ff 	lea    -0x5f0(%rbp),%rdi
 11b4370:	48 8d b5 30 fd ff ff 	lea    -0x2d0(%rbp),%rsi
 11b4377:	ba 01 00 00 00       	mov    $0x1,%edx
 11b437c:	4c 89 e1             	mov    %r12,%rcx
 11b437f:	45 31 c0             	xor    %r8d,%r8d
 11b4382:	e8 09 32 0c 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 11b4387:	f6 85 a8 fe ff ff 03 	testb  $0x3,-0x158(%rbp)
 11b438e:	4c 89 ad 98 fe ff ff 	mov    %r13,-0x168(%rbp)
 11b4395:	0f 84 f7 00 00 00    	je     11b4492 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x6b2>
 11b439b:	4c 89 bd 30 fb ff ff 	mov    %r15,-0x4d0(%rbp)
 11b43a2:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11b43a9:	48 89 85 38 fb ff ff 	mov    %rax,-0x4c8(%rbp)
 11b43b0:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 11b43b7:	48 89 85 40 fb ff ff 	mov    %rax,-0x4c0(%rbp)
 11b43be:	48 c7 85 48 fb ff ff 	movq   $0x1,-0x4b8(%rbp)
 11b43c5:	01 00 00 00 
 11b43c9:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 11b43cd:	48 89 85 50 fb ff ff 	mov    %rax,-0x4b0(%rbp)
 11b43d4:	48 c7 85 58 fb ff ff 	movq   $0x3,-0x4a8(%rbp)
 11b43db:	03 00 00 00 
 11b43df:	48 c7 85 60 fb ff ff 	movq   $0x102,-0x4a0(%rbp)
 11b43e6:	02 01 00 00 
 11b43ea:	48 c7 85 68 fb ff ff 	movq   $0x0,-0x498(%rbp)
 11b43f1:	00 00 00 00 
 11b43f5:	c6 85 70 fb ff ff 00 	movb   $0x0,-0x490(%rbp)
 11b43fc:	4c 8d b5 50 f0 ff ff 	lea    -0xfb0(%rbp),%r14
 11b4403:	4c 8d 85 30 fb ff ff 	lea    -0x4d0(%rbp),%r8
 11b440a:	4c 89 f7             	mov    %r14,%rdi
 11b440d:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b4411:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11b4415:	4c 89 e1             	mov    %r12,%rcx
 11b4418:	e8 a3 a2 ff ff       	call   11ae6c0 <lz77.lazyGreedyPlanAlloc>
 11b441d:	44 0f b7 bd 78 f0 ff 	movzwl -0xf88(%rbp),%r15d
 11b4424:	ff 
 11b4425:	4d 85 ff             	test   %r15,%r15
 11b4428:	0f 85 d1 14 00 00    	jne    11b58ff <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1b1f>
 11b442e:	4c 8d bd c0 fa ff ff 	lea    -0x540(%rbp),%r15
 11b4435:	4c 8d a5 b8 fa ff ff 	lea    -0x548(%rbp),%r12
 11b443c:	4c 8d ad b0 fa ff ff 	lea    -0x550(%rbp),%r13
 11b4443:	e9 f2 00 00 00       	jmp    11b453a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x75a>
 11b4448:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 11b444f:	74 27                	je     11b4478 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x698>
 11b4451:	48 69 85 f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rax
 11b4458:	18 01 00 00 
 11b445c:	48 8b 8d e0 fe ff ff 	mov    -0x120(%rbp),%rcx
 11b4463:	41 0f b7 d7          	movzwl %r15w,%edx
 11b4467:	c1 e2 04             	shl    $0x4,%edx
 11b446a:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b4471:	01 
 11b4472:	c5 f8 11 44 01 68    	vmovups %xmm0,0x68(%rcx,%rax,1)
 11b4478:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b447f:	e8 ec 2c 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b4484:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11b4488:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 11b448d:	e9 95 10 00 00       	jmp    11b5527 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1747>
 11b4492:	4c 89 bd 78 fb ff ff 	mov    %r15,-0x488(%rbp)
 11b4499:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11b44a0:	48 89 85 80 fb ff ff 	mov    %rax,-0x480(%rbp)
 11b44a7:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 11b44ae:	48 89 85 88 fb ff ff 	mov    %rax,-0x478(%rbp)
 11b44b5:	48 c7 85 90 fb ff ff 	movq   $0x1,-0x470(%rbp)
 11b44bc:	01 00 00 00 
 11b44c0:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 11b44c4:	48 89 85 98 fb ff ff 	mov    %rax,-0x468(%rbp)
 11b44cb:	48 c7 85 a0 fb ff ff 	movq   $0x3,-0x460(%rbp)
 11b44d2:	03 00 00 00 
 11b44d6:	48 c7 85 a8 fb ff ff 	movq   $0x102,-0x458(%rbp)
 11b44dd:	02 01 00 00 
 11b44e1:	48 c7 85 b0 fb ff ff 	movq   $0x0,-0x450(%rbp)
 11b44e8:	00 00 00 00 
 11b44ec:	c6 85 b8 fb ff ff 00 	movb   $0x0,-0x448(%rbp)
 11b44f3:	4c 8d b5 80 f0 ff ff 	lea    -0xf80(%rbp),%r14
 11b44fa:	4c 8d 85 78 fb ff ff 	lea    -0x488(%rbp),%r8
 11b4501:	4c 89 f7             	mov    %r14,%rdi
 11b4504:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b4508:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11b450c:	4c 89 e1             	mov    %r12,%rcx
 11b450f:	e8 5c 7e ff ff       	call   11ac370 <lz77.hashGreedyPlanAlloc>
 11b4514:	44 0f b7 bd a8 f0 ff 	movzwl -0xf58(%rbp),%r15d
 11b451b:	ff 
 11b451c:	4d 85 ff             	test   %r15,%r15
 11b451f:	0f 85 fc 15 00 00    	jne    11b5b21 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1d41>
 11b4525:	4c 8d bd d8 fa ff ff 	lea    -0x528(%rbp),%r15
 11b452c:	4c 8d a5 d0 fa ff ff 	lea    -0x530(%rbp),%r12
 11b4533:	4c 8d ad c8 fa ff ff 	lea    -0x538(%rbp),%r13
 11b453a:	49 8b 06             	mov    (%r14),%rax
 11b453d:	49 89 45 00          	mov    %rax,0x0(%r13)
 11b4541:	49 8b 46 08          	mov    0x8(%r14),%rax
 11b4545:	49 89 04 24          	mov    %rax,(%r12)
 11b4549:	49 8b 46 18          	mov    0x18(%r14),%rax
 11b454d:	49 89 07             	mov    %rax,(%r15)
 11b4550:	48 8d bd 10 fa ff ff 	lea    -0x5f0(%rbp),%rdi
 11b4557:	e8 14 2c 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b455c:	4d 8b 75 00          	mov    0x0(%r13),%r14
 11b4560:	4d 8b 2c 24          	mov    (%r12),%r13
 11b4564:	4d 8b 27             	mov    (%r15),%r12
 11b4567:	c5 f8 28 85 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm0
 11b456e:	ff 
 11b456f:	c5 f8 29 85 10 fd ff 	vmovaps %xmm0,-0x2f0(%rbp)
 11b4576:	ff 
 11b4577:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b457e:	48 89 85 20 fd ff ff 	mov    %rax,-0x2e0(%rbp)
 11b4585:	c6 85 28 fd ff ff 01 	movb   $0x1,-0x2d8(%rbp)
 11b458c:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 11b4593:	48 89 c1             	mov    %rax,%rcx
 11b4596:	48 c1 e9 30          	shr    $0x30,%rcx
 11b459a:	48 89 8d 80 fe ff ff 	mov    %rcx,-0x180(%rbp)
 11b45a1:	88 8d 2f fd ff ff    	mov    %cl,-0x2d1(%rbp)
 11b45a7:	48 89 c1             	mov    %rax,%rcx
 11b45aa:	48 c1 e9 20          	shr    $0x20,%rcx
 11b45ae:	48 89 8d 88 fe ff ff 	mov    %rcx,-0x178(%rbp)
 11b45b5:	66 89 8d 2d fd ff ff 	mov    %cx,-0x2d3(%rbp)
 11b45bc:	89 85 29 fd ff ff    	mov    %eax,-0x2d7(%rbp)
 11b45c2:	48 8d bd 30 f8 ff ff 	lea    -0x7d0(%rbp),%rdi
 11b45c9:	48 8d b5 10 fd ff ff 	lea    -0x2f0(%rbp),%rsi
 11b45d0:	ba 02 00 00 00       	mov    $0x2,%edx
 11b45d5:	4c 8b bd 70 fe ff ff 	mov    -0x190(%rbp),%r15
 11b45dc:	4c 89 f9             	mov    %r15,%rcx
 11b45df:	45 31 c0             	xor    %r8d,%r8d
 11b45e2:	e8 a9 2f 0c 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 11b45e7:	48 8d bd 90 fa ff ff 	lea    -0x570(%rbp),%rdi
 11b45ee:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b45f2:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11b45f6:	4c 89 f9             	mov    %r15,%rcx
 11b45f9:	4c 89 b5 78 ff ff ff 	mov    %r14,-0x88(%rbp)
 11b4600:	4d 89 f0             	mov    %r14,%r8
 11b4603:	4d 89 e9             	mov    %r13,%r9
 11b4606:	e8 25 b4 ff ff       	call   11afa30 <br.encoder.command_plan.buildAlloc>
 11b460b:	44 0f b7 b5 a8 fa ff 	movzwl -0x558(%rbp),%r14d
 11b4612:	ff 
 11b4613:	4d 85 f6             	test   %r14,%r14
 11b4616:	0f 85 4f 12 00 00    	jne    11b586b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1a8b>
 11b461c:	4c 89 ad 60 ff ff ff 	mov    %r13,-0xa0(%rbp)
 11b4623:	4c 8b ad 90 fa ff ff 	mov    -0x570(%rbp),%r13
 11b462a:	48 8b 85 98 fa ff ff 	mov    -0x568(%rbp),%rax
 11b4631:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 11b4635:	48 8d bd 30 f8 ff ff 	lea    -0x7d0(%rbp),%rdi
 11b463c:	e8 2f 2b 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b4641:	c5 f8 10 43 58       	vmovups 0x58(%rbx),%xmm0
 11b4646:	0f b6 83 85 00 00 00 	movzbl 0x85(%rbx),%eax
 11b464d:	0f b6 55 b6          	movzbl -0x4a(%rbp),%edx
 11b4651:	80 e2 01             	and    $0x1,%dl
 11b4654:	44 0f b6 75 8f       	movzbl -0x71(%rbp),%r14d
 11b4659:	41 80 e6 01          	and    $0x1,%r14b
 11b465d:	44 0f b6 4d 8b       	movzbl -0x75(%rbp),%r9d
 11b4662:	41 80 e1 01          	and    $0x1,%r9b
 11b4666:	44 0f b6 55 8c       	movzbl -0x74(%rbp),%r10d
 11b466b:	41 80 e2 01          	and    $0x1,%r10b
 11b466f:	44 0f b6 85 90 fe ff 	movzbl -0x170(%rbp),%r8d
 11b4676:	ff 
 11b4677:	41 80 e0 01          	and    $0x1,%r8b
 11b467b:	4c 89 a5 90 fe ff ff 	mov    %r12,-0x170(%rbp)
 11b4682:	44 0f b6 65 8e       	movzbl -0x72(%rbp),%r12d
 11b4687:	44 0a a3 8a 00 00 00 	or     0x8a(%rbx),%r12b
 11b468e:	41 80 e4 01          	and    $0x1,%r12b
 11b4692:	0f b6 7d 8a          	movzbl -0x76(%rbp),%edi
 11b4696:	40 80 e7 01          	and    $0x1,%dil
 11b469a:	44 0f b6 5d 8d       	movzbl -0x73(%rbp),%r11d
 11b469f:	44 0a 9b 89 00 00 00 	or     0x89(%rbx),%r11b
 11b46a6:	41 80 e3 01          	and    $0x1,%r11b
 11b46aa:	0f b6 75 c6          	movzbl -0x3a(%rbp),%esi
 11b46ae:	40 80 e6 01          	and    $0x1,%sil
 11b46b2:	80 bb 8c 00 00 00 00 	cmpb   $0x0,0x8c(%rbx)
 11b46b9:	0f b6 8b 8b 00 00 00 	movzbl 0x8b(%rbx),%ecx
 11b46c0:	88 55 c6             	mov    %dl,-0x3a(%rbp)
 11b46c3:	88 95 91 fd ff ff    	mov    %dl,-0x26f(%rbp)
 11b46c9:	44 88 b5 d0 fd ff ff 	mov    %r14b,-0x230(%rbp)
 11b46d0:	0f b6 95 d0 fd ff ff 	movzbl -0x230(%rbp),%edx
 11b46d7:	88 95 92 fd ff ff    	mov    %dl,-0x26e(%rbp)
 11b46dd:	c6 85 93 fd ff ff 01 	movb   $0x1,-0x26d(%rbp)
 11b46e4:	44 88 8d 94 fd ff ff 	mov    %r9b,-0x26c(%rbp)
 11b46eb:	44 88 95 95 fd ff ff 	mov    %r10b,-0x26b(%rbp)
 11b46f2:	66 c7 85 96 fd ff ff 	movw   $0x0,-0x26a(%rbp)
 11b46f9:	00 00 
 11b46fb:	44 88 85 98 fd ff ff 	mov    %r8b,-0x268(%rbp)
 11b4702:	44 88 a5 99 fd ff ff 	mov    %r12b,-0x267(%rbp)
 11b4709:	40 88 bd 9a fd ff ff 	mov    %dil,-0x266(%rbp)
 11b4710:	44 88 9d 9b fd ff ff 	mov    %r11b,-0x265(%rbp)
 11b4717:	4c 8b 5d a0          	mov    -0x60(%rbp),%r11
 11b471b:	40 88 b5 9c fd ff ff 	mov    %sil,-0x264(%rbp)
 11b4722:	0f b6 55 90          	movzbl -0x70(%rbp),%edx
 11b4726:	0f 45 d1             	cmovne %ecx,%edx
 11b4729:	80 e2 01             	and    $0x1,%dl
 11b472c:	88 95 9d fd ff ff    	mov    %dl,-0x263(%rbp)
 11b4732:	24 01                	and    $0x1,%al
 11b4734:	88 85 90 fd ff ff    	mov    %al,-0x270(%rbp)
 11b473a:	48 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%rax
 11b4741:	88 85 9e fd ff ff    	mov    %al,-0x262(%rbp)
 11b4747:	c5 f8 11 85 50 fd ff 	vmovups %xmm0,-0x2b0(%rbp)
 11b474e:	ff 
 11b474f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b4753:	c5 f8 11 85 60 fd ff 	vmovups %xmm0,-0x2a0(%rbp)
 11b475a:	ff 
 11b475b:	c5 fc 10 05 1d bc e4 	vmovups -0x1b43e3(%rip),%ymm0        # 1000380 <__anon_29473>
 11b4762:	ff 
 11b4763:	c5 fc 11 85 70 fd ff 	vmovups %ymm0,-0x290(%rbp)
 11b476a:	ff 
 11b476b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b476f:	c5 fc 11 85 60 f3 ff 	vmovups %ymm0,-0xca0(%rbp)
 11b4776:	ff 
 11b4777:	c5 fc 11 85 50 f3 ff 	vmovups %ymm0,-0xcb0(%rbp)
 11b477e:	ff 
 11b477f:	c5 fc 11 85 30 f3 ff 	vmovups %ymm0,-0xcd0(%rbp)
 11b4786:	ff 
 11b4787:	c5 fc 11 85 10 f3 ff 	vmovups %ymm0,-0xcf0(%rbp)
 11b478e:	ff 
 11b478f:	c5 fc 11 85 f0 f2 ff 	vmovups %ymm0,-0xd10(%rbp)
 11b4796:	ff 
 11b4797:	48 83 bd 90 fe ff ff 	cmpq   $0x0,-0x170(%rbp)
 11b479e:	00 
 11b479f:	4c 89 ad 58 ff ff ff 	mov    %r13,-0xa8(%rbp)
 11b47a6:	0f 84 f5 00 00 00    	je     11b48a1 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xac1>
 11b47ac:	c5 f8 28 85 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm0
 11b47b3:	ff 
 11b47b4:	c5 f8 29 85 f0 fc ff 	vmovaps %xmm0,-0x310(%rbp)
 11b47bb:	ff 
 11b47bc:	c6 85 d0 fd ff ff 01 	movb   $0x1,-0x230(%rbp)
 11b47c3:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b47ca:	48 89 85 00 fd ff ff 	mov    %rax,-0x300(%rbp)
 11b47d1:	c6 85 08 fd ff ff 01 	movb   $0x1,-0x2f8(%rbp)
 11b47d8:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 11b47df:	89 85 09 fd ff ff    	mov    %eax,-0x2f7(%rbp)
 11b47e5:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 11b47ec:	88 85 0f fd ff ff    	mov    %al,-0x2f1(%rbp)
 11b47f2:	48 8b 85 88 fe ff ff 	mov    -0x178(%rbp),%rax
 11b47f9:	66 89 85 0d fd ff ff 	mov    %ax,-0x2f3(%rbp)
 11b4800:	48 83 ec 08          	sub    $0x8,%rsp
 11b4804:	48 8d 85 50 fd ff ff 	lea    -0x2b0(%rbp),%rax
 11b480b:	4c 8d 95 f0 f2 ff ff 	lea    -0xd10(%rbp),%r10
 11b4812:	48 8d 9d 80 f9 ff ff 	lea    -0x680(%rbp),%rbx
 11b4819:	48 8d b5 f0 fc ff ff 	lea    -0x310(%rbp),%rsi
 11b4820:	48 89 df             	mov    %rbx,%rdi
 11b4823:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 11b4827:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b482b:	4d 89 f8             	mov    %r15,%r8
 11b482e:	4d 89 e9             	mov    %r13,%r9
 11b4831:	50                   	push   %rax
 11b4832:	41 52                	push   %r10
 11b4834:	41 53                	push   %r11
 11b4836:	c5 f8 77             	vzeroupper 
 11b4839:	e8 a2 47 0b 00       	call   1268fe0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228>
 11b483e:	48 83 c4 20          	add    $0x20,%rsp
 11b4842:	44 0f b7 b5 90 f9 ff 	movzwl -0x670(%rbp),%r14d
 11b4849:	ff 
 11b484a:	4d 85 f6             	test   %r14,%r14
 11b484d:	0f 84 87 00 00 00    	je     11b48da <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xafa>
 11b4853:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b4857:	48 85 c9             	test   %rcx,%rcx
 11b485a:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11b485e:	74 1e                	je     11b487e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xa9e>
 11b4860:	48 8b 3b             	mov    (%rbx),%rdi
 11b4863:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b4867:	48 c1 e1 05          	shl    $0x5,%rcx
 11b486b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b486f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b4873:	4c 89 ee             	mov    %r13,%rsi
 11b4876:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b487b:	ff 50 18             	call   *0x18(%rax)
 11b487e:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 11b4885:	48 85 c9             	test   %rcx,%rcx
 11b4888:	0f 84 49 10 00 00    	je     11b58d7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1af7>
 11b488e:	48 8b 3b             	mov    (%rbx),%rdi
 11b4891:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b4895:	48 01 c9             	add    %rcx,%rcx
 11b4898:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b489c:	e9 23 10 00 00       	jmp    11b58c4 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1ae4>
 11b48a1:	48 8d 9d 98 f9 ff ff 	lea    -0x668(%rbp),%rbx
 11b48a8:	4c 8d 8d 60 fc ff ff 	lea    -0x3a0(%rbp),%r9
 11b48af:	48 89 df             	mov    %rbx,%rdi
 11b48b2:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11b48b6:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 11b48ba:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b48be:	4d 89 f8             	mov    %r15,%r8
 11b48c1:	c5 f8 77             	vzeroupper 
 11b48c4:	e8 d7 1f 0c 00       	call   12768a0 <br.encodeStoredStreamRecorded__anon_28729>
 11b48c9:	44 0f b7 b5 a8 f9 ff 	movzwl -0x658(%rbp),%r14d
 11b48d0:	ff 
 11b48d1:	4d 85 f6             	test   %r14,%r14
 11b48d4:	0f 85 b0 12 00 00    	jne    11b5b8a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1daa>
 11b48da:	c5 f8 10 03          	vmovups (%rbx),%xmm0
 11b48de:	c5 f8 11 85 68 ff ff 	vmovups %xmm0,-0x98(%rbp)
 11b48e5:	ff 
 11b48e6:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 11b48ed:	48 85 c9             	test   %rcx,%rcx
 11b48f0:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11b48f4:	74 1a                	je     11b4910 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xb30>
 11b48f6:	48 8d 95 68 ff ff ff 	lea    -0x98(%rbp),%rdx
 11b48fd:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b4901:	48 89 de             	mov    %rbx,%rsi
 11b4904:	4c 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%r8
 11b490b:	e8 10 44 0b 00       	call   1268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>
 11b4910:	0f b6 85 a8 fe ff ff 	movzbl -0x158(%rbp),%eax
 11b4917:	24 03                	and    $0x3,%al
 11b4919:	3c 02                	cmp    $0x2,%al
 11b491b:	0f 94 c0             	sete   %al
 11b491e:	80 bd b8 fe ff ff 11 	cmpb   $0x11,-0x148(%rbp)
 11b4925:	0f 93 c1             	setae  %cl
 11b4928:	49 81 ff f2 ff 00 00 	cmp    $0xfff2,%r15
 11b492f:	0f 93 c2             	setae  %dl
 11b4932:	20 ca                	and    %cl,%dl
 11b4934:	84 c2                	test   %al,%dl
 11b4936:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11b493a:	0f 84 43 02 00 00    	je     11b4b83 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xda3>
 11b4940:	c6 85 40 ff ff ff 00 	movb   $0x0,-0xc0(%rbp)
 11b4947:	48 c7 85 20 f9 ff ff 	movq   $0x0,-0x6e0(%rbp)
 11b494e:	00 00 00 00 
 11b4952:	4c 89 bd 28 f9 ff ff 	mov    %r15,-0x6d8(%rbp)
 11b4959:	48 c7 85 30 f9 ff ff 	movq   $0x2,-0x6d0(%rbp)
 11b4960:	02 00 00 00 
 11b4964:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b4968:	c5 fc 11 85 38 f9 ff 	vmovups %ymm0,-0x6c8(%rbp)
 11b496f:	ff 
 11b4970:	c6 85 3f ff ff ff 00 	movb   $0x0,-0xc1(%rbp)
 11b4977:	c5 fc 11 85 58 f9 ff 	vmovups %ymm0,-0x6a8(%rbp)
 11b497e:	ff 
 11b497f:	66 c7 85 78 f9 ff ff 	movw   $0x0,-0x688(%rbp)
 11b4986:	00 00 
 11b4988:	b8 01 00 00 00       	mov    $0x1,%eax
 11b498d:	48 89 85 a8 fe ff ff 	mov    %rax,-0x158(%rbp)
 11b4994:	4d 85 f6             	test   %r14,%r14
 11b4997:	74 23                	je     11b49bc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xbdc>
 11b4999:	49 8d 45 58          	lea    0x58(%r13),%rax
 11b499d:	4c 89 f1             	mov    %r14,%rcx
 11b49a0:	f6 00 01             	testb  $0x1,(%rax)
 11b49a3:	75 0b                	jne    11b49b0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xbd0>
 11b49a5:	48 83 c0 60          	add    $0x60,%rax
 11b49a9:	48 ff c9             	dec    %rcx
 11b49ac:	75 f2                	jne    11b49a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xbc0>
 11b49ae:	eb 0c                	jmp    11b49bc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xbdc>
 11b49b0:	b8 02 00 00 00       	mov    $0x2,%eax
 11b49b5:	48 89 85 a8 fe ff ff 	mov    %rax,-0x158(%rbp)
 11b49bc:	45 31 e4             	xor    %r12d,%r12d
 11b49bf:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11b49c3:	48 89 85 78 fe ff ff 	mov    %rax,-0x188(%rbp)
 11b49ca:	eb 1f                	jmp    11b49eb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xc0b>
 11b49cc:	0f 1f 40 00          	nopl   0x0(%rax)
 11b49d0:	49 ff c4             	inc    %r12
 11b49d3:	4c 39 a5 a8 fe ff ff 	cmp    %r12,-0x158(%rbp)
 11b49da:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 11b49e1:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11b49e5:	0f 84 98 01 00 00    	je     11b4b83 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xda3>
 11b49eb:	4d 85 e4             	test   %r12,%r12
 11b49ee:	48 8d 85 20 f9 ff ff 	lea    -0x6e0(%rbp),%rax
 11b49f5:	49 0f 44 c5          	cmove  %r13,%rax
 11b49f9:	41 ba 01 00 00 00    	mov    $0x1,%r10d
 11b49ff:	4d 0f 44 d6          	cmove  %r14,%r10
 11b4a03:	ba 8e 9e 13 01       	mov    $0x1139e8e,%edx
 11b4a08:	48 8d bd d0 fd ff ff 	lea    -0x230(%rbp),%rdi
 11b4a0f:	48 89 de             	mov    %rbx,%rsi
 11b4a12:	31 c9                	xor    %ecx,%ecx
 11b4a14:	4c 8b 45 98          	mov    -0x68(%rbp),%r8
 11b4a18:	4d 89 f9             	mov    %r15,%r9
 11b4a1b:	ff b5 78 fe ff ff    	push   -0x188(%rbp)
 11b4a21:	ff b5 b8 fd ff ff    	push   -0x248(%rbp)
 11b4a27:	41 52                	push   %r10
 11b4a29:	50                   	push   %rax
 11b4a2a:	c5 f8 77             	vzeroupper 
 11b4a2d:	e8 0e e6 ff ff       	call   11b3040 <br.encoder.long_distance.augmentAllocWithHistoryAndMaxDistanceForFormat>
 11b4a32:	48 83 c4 20          	add    $0x20,%rsp
 11b4a36:	0f b7 9d e0 fd ff ff 	movzwl -0x220(%rbp),%ebx
 11b4a3d:	48 85 db             	test   %rbx,%rbx
 11b4a40:	0f 85 96 0b 00 00    	jne    11b55dc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x17fc>
 11b4a46:	4c 8b ad d0 fd ff ff 	mov    -0x230(%rbp),%r13
 11b4a4d:	4d 85 ed             	test   %r13,%r13
 11b4a50:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11b4a54:	0f 84 76 ff ff ff    	je     11b49d0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xbf0>
 11b4a5a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b4a5e:	c5 fc 11 85 d0 f2 ff 	vmovups %ymm0,-0xd30(%rbp)
 11b4a65:	ff 
 11b4a66:	c5 fc 11 85 c0 f2 ff 	vmovups %ymm0,-0xd40(%rbp)
 11b4a6d:	ff 
 11b4a6e:	c5 fc 11 85 a0 f2 ff 	vmovups %ymm0,-0xd60(%rbp)
 11b4a75:	ff 
 11b4a76:	c5 fc 11 85 80 f2 ff 	vmovups %ymm0,-0xd80(%rbp)
 11b4a7d:	ff 
 11b4a7e:	4c 8b b5 d8 fd ff ff 	mov    -0x228(%rbp),%r14
 11b4a85:	c5 fc 11 85 60 f2 ff 	vmovups %ymm0,-0xda0(%rbp)
 11b4a8c:	ff 
 11b4a8d:	c5 f8 28 85 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm0
 11b4a94:	ff 
 11b4a95:	c5 f8 29 85 d0 fc ff 	vmovaps %xmm0,-0x330(%rbp)
 11b4a9c:	ff 
 11b4a9d:	c6 85 d0 fd ff ff 01 	movb   $0x1,-0x230(%rbp)
 11b4aa4:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b4aab:	48 89 85 e0 fc ff ff 	mov    %rax,-0x320(%rbp)
 11b4ab2:	c6 85 e8 fc ff ff 01 	movb   $0x1,-0x318(%rbp)
 11b4ab9:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 11b4ac0:	89 85 e9 fc ff ff    	mov    %eax,-0x317(%rbp)
 11b4ac6:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 11b4acd:	88 85 ef fc ff ff    	mov    %al,-0x311(%rbp)
 11b4ad3:	48 8b 85 88 fe ff ff 	mov    -0x178(%rbp),%rax
 11b4ada:	66 89 85 ed fc ff ff 	mov    %ax,-0x313(%rbp)
 11b4ae1:	48 83 ec 08          	sub    $0x8,%rsp
 11b4ae5:	48 8d bd 20 fc ff ff 	lea    -0x3e0(%rbp),%rdi
 11b4aec:	48 8d b5 d0 fc ff ff 	lea    -0x330(%rbp),%rsi
 11b4af3:	48 89 da             	mov    %rbx,%rdx
 11b4af6:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b4afa:	4d 89 f8             	mov    %r15,%r8
 11b4afd:	4d 89 e9             	mov    %r13,%r9
 11b4b00:	48 8d 85 50 fd ff ff 	lea    -0x2b0(%rbp),%rax
 11b4b07:	50                   	push   %rax
 11b4b08:	48 8d 85 60 f2 ff ff 	lea    -0xda0(%rbp),%rax
 11b4b0f:	50                   	push   %rax
 11b4b10:	41 56                	push   %r14
 11b4b12:	c5 f8 77             	vzeroupper 
 11b4b15:	e8 c6 44 0b 00       	call   1268fe0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228>
 11b4b1a:	48 83 c4 20          	add    $0x20,%rsp
 11b4b1e:	44 0f b7 bd 30 fc ff 	movzwl -0x3d0(%rbp),%r15d
 11b4b25:	ff 
 11b4b26:	4d 85 ff             	test   %r15,%r15
 11b4b29:	0f 85 6a 0b 00 00    	jne    11b5699 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x18b9>
 11b4b2f:	48 8b 8d 20 fc ff ff 	mov    -0x3e0(%rbp),%rcx
 11b4b36:	4c 8b 85 28 fc ff ff 	mov    -0x3d8(%rbp),%r8
 11b4b3d:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b4b41:	48 89 de             	mov    %rbx,%rsi
 11b4b44:	48 8d 95 68 ff ff ff 	lea    -0x98(%rbp),%rdx
 11b4b4b:	e8 d0 41 0b 00       	call   1268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>
 11b4b50:	4d 85 f6             	test   %r14,%r14
 11b4b53:	4c 8b bd 70 fe ff ff 	mov    -0x190(%rbp),%r15
 11b4b5a:	0f 84 70 fe ff ff    	je     11b49d0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xbf0>
 11b4b60:	48 8b 3b             	mov    (%rbx),%rdi
 11b4b63:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b4b67:	49 c1 e6 05          	shl    $0x5,%r14
 11b4b6b:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 11b4b6f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b4b73:	4c 89 ee             	mov    %r13,%rsi
 11b4b76:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b4b7b:	ff 50 18             	call   *0x18(%rax)
 11b4b7e:	e9 4d fe ff ff       	jmp    11b49d0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0xbf0>
 11b4b83:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 11b4b8a:	48 c1 e8 38          	shr    $0x38,%rax
 11b4b8e:	83 e0 01             	and    $0x1,%eax
 11b4b91:	80 7d 91 00          	cmpb   $0x0,-0x6f(%rbp)
 11b4b95:	0f b6 5d 92          	movzbl -0x6e(%rbp),%ebx
 11b4b99:	0f 45 d8             	cmovne %eax,%ebx
 11b4b9c:	0f b6 4d b6          	movzbl -0x4a(%rbp),%ecx
 11b4ba0:	20 d9                	and    %bl,%cl
 11b4ba2:	48 83 bd 90 fe ff ff 	cmpq   $0x0,-0x170(%rbp)
 11b4ba9:	00 
 11b4baa:	0f 95 c0             	setne  %al
 11b4bad:	84 c1                	test   %al,%cl
 11b4baf:	4c 8b a5 60 ff ff ff 	mov    -0xa0(%rbp),%r12
 11b4bb6:	0f 84 2a 02 00 00    	je     11b4de6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1006>
 11b4bbc:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b4bc0:	c5 fc 11 85 40 f2 ff 	vmovups %ymm0,-0xdc0(%rbp)
 11b4bc7:	ff 
 11b4bc8:	c5 fc 11 85 30 f2 ff 	vmovups %ymm0,-0xdd0(%rbp)
 11b4bcf:	ff 
 11b4bd0:	c5 fc 11 85 10 f2 ff 	vmovups %ymm0,-0xdf0(%rbp)
 11b4bd7:	ff 
 11b4bd8:	c5 fc 11 85 f0 f1 ff 	vmovups %ymm0,-0xe10(%rbp)
 11b4bdf:	ff 
 11b4be0:	c5 fc 11 85 d0 f1 ff 	vmovups %ymm0,-0xe30(%rbp)
 11b4be7:	ff 
 11b4be8:	c5 f8 28 8d 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm1
 11b4bef:	ff 
 11b4bf0:	c5 f8 29 8d b0 fc ff 	vmovaps %xmm1,-0x350(%rbp)
 11b4bf7:	ff 
 11b4bf8:	c6 85 d0 fd ff ff 01 	movb   $0x1,-0x230(%rbp)
 11b4bff:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b4c06:	48 89 85 c0 fc ff ff 	mov    %rax,-0x340(%rbp)
 11b4c0d:	c6 85 c8 fc ff ff 01 	movb   $0x1,-0x338(%rbp)
 11b4c14:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 11b4c1b:	89 85 c9 fc ff ff    	mov    %eax,-0x337(%rbp)
 11b4c21:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 11b4c28:	88 85 cf fc ff ff    	mov    %al,-0x331(%rbp)
 11b4c2e:	48 8b 85 88 fe ff ff 	mov    -0x178(%rbp),%rax
 11b4c35:	66 89 85 cd fc ff ff 	mov    %ax,-0x333(%rbp)
 11b4c3c:	c6 45 88 00          	movb   $0x0,-0x78(%rbp)
 11b4c40:	c6 45 89 00          	movb   $0x0,-0x77(%rbp)
 11b4c44:	0f b6 45 b7          	movzbl -0x49(%rbp),%eax
 11b4c48:	88 85 29 f8 ff ff    	mov    %al,-0x7d7(%rbp)
 11b4c4e:	48 c7 85 18 f6 ff ff 	movq   $0x0,-0x9e8(%rbp)
 11b4c55:	00 00 00 00 
 11b4c59:	c6 85 2d f8 ff ff 01 	movb   $0x1,-0x7d3(%rbp)
 11b4c60:	c6 85 2c f8 ff ff 00 	movb   $0x0,-0x7d4(%rbp)
 11b4c67:	c5 fc 11 85 e8 f7 ff 	vmovups %ymm0,-0x818(%rbp)
 11b4c6e:	ff 
 11b4c6f:	c5 fc 11 85 c8 f7 ff 	vmovups %ymm0,-0x838(%rbp)
 11b4c76:	ff 
 11b4c77:	c5 fc 11 85 a8 f7 ff 	vmovups %ymm0,-0x858(%rbp)
 11b4c7e:	ff 
 11b4c7f:	c5 fc 11 85 88 f7 ff 	vmovups %ymm0,-0x878(%rbp)
 11b4c86:	ff 
 11b4c87:	c5 fc 11 85 68 f7 ff 	vmovups %ymm0,-0x898(%rbp)
 11b4c8e:	ff 
 11b4c8f:	c5 fc 11 85 48 f7 ff 	vmovups %ymm0,-0x8b8(%rbp)
 11b4c96:	ff 
 11b4c97:	c5 fc 11 85 28 f7 ff 	vmovups %ymm0,-0x8d8(%rbp)
 11b4c9e:	ff 
 11b4c9f:	c5 fc 11 85 08 f7 ff 	vmovups %ymm0,-0x8f8(%rbp)
 11b4ca6:	ff 
 11b4ca7:	c5 fc 11 85 e8 f6 ff 	vmovups %ymm0,-0x918(%rbp)
 11b4cae:	ff 
 11b4caf:	c5 fc 11 85 c8 f6 ff 	vmovups %ymm0,-0x938(%rbp)
 11b4cb6:	ff 
 11b4cb7:	c5 fc 11 85 a8 f6 ff 	vmovups %ymm0,-0x958(%rbp)
 11b4cbe:	ff 
 11b4cbf:	c5 fc 11 85 88 f6 ff 	vmovups %ymm0,-0x978(%rbp)
 11b4cc6:	ff 
 11b4cc7:	c5 fc 11 85 68 f6 ff 	vmovups %ymm0,-0x998(%rbp)
 11b4cce:	ff 
 11b4ccf:	c5 fc 11 85 48 f6 ff 	vmovups %ymm0,-0x9b8(%rbp)
 11b4cd6:	ff 
 11b4cd7:	48 c7 85 08 f8 ff ff 	movq   $0x0,-0x7f8(%rbp)
 11b4cde:	00 00 00 00 
 11b4ce2:	c6 85 20 f8 ff ff 38 	movb   $0x38,-0x7e0(%rbp)
 11b4ce9:	c6 85 28 f8 ff ff 00 	movb   $0x0,-0x7d8(%rbp)
 11b4cf0:	0f b6 45 88          	movzbl -0x78(%rbp),%eax
 11b4cf4:	0f b6 4d 89          	movzbl -0x77(%rbp),%ecx
 11b4cf8:	88 85 22 f8 ff ff    	mov    %al,-0x7de(%rbp)
 11b4cfe:	88 8d 23 f8 ff ff    	mov    %cl,-0x7dd(%rbp)
 11b4d04:	48 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%rax
 11b4d0b:	88 85 21 f8 ff ff    	mov    %al,-0x7df(%rbp)
 11b4d11:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11b4d18:	48 89 85 08 f6 ff ff 	mov    %rax,-0x9f8(%rbp)
 11b4d1f:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11b4d26:	48 89 85 10 f6 ff ff 	mov    %rax,-0x9f0(%rbp)
 11b4d2d:	c7 85 24 f8 ff ff 01 	movl   $0x1000101,-0x7dc(%rbp)
 11b4d34:	01 00 01 
 11b4d37:	66 c7 85 2a f8 ff ff 	movw   $0x0,-0x7d6(%rbp)
 11b4d3e:	00 00 
 11b4d40:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b4d44:	c5 f8 11 85 10 f8 ff 	vmovups %xmm0,-0x7f0(%rbp)
 11b4d4b:	ff 
 11b4d4c:	c5 fc 10 05 2c b6 e4 	vmovups -0x1b49d4(%rip),%ymm0        # 1000380 <__anon_29473>
 11b4d53:	ff 
 11b4d54:	c5 fc 11 85 28 f6 ff 	vmovups %ymm0,-0x9d8(%rbp)
 11b4d5b:	ff 
 11b4d5c:	48 c7 85 20 f6 ff ff 	movq   $0x0,-0x9e0(%rbp)
 11b4d63:	00 00 00 00 
 11b4d67:	48 83 ec 08          	sub    $0x8,%rsp
 11b4d6b:	48 8d 85 08 f6 ff ff 	lea    -0x9f8(%rbp),%rax
 11b4d72:	4c 8d 95 d0 f1 ff ff 	lea    -0xe30(%rbp),%r10
 11b4d79:	48 8d bd 08 fc ff ff 	lea    -0x3f8(%rbp),%rdi
 11b4d80:	48 8d b5 b0 fc ff ff 	lea    -0x350(%rbp),%rsi
 11b4d87:	4d 89 f8             	mov    %r15,%r8
 11b4d8a:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 11b4d8e:	4c 89 fa             	mov    %r15,%rdx
 11b4d91:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b4d95:	4d 89 e9             	mov    %r13,%r9
 11b4d98:	50                   	push   %rax
 11b4d99:	41 52                	push   %r10
 11b4d9b:	41 56                	push   %r14
 11b4d9d:	c5 f8 77             	vzeroupper 
 11b4da0:	e8 5b 68 08 00       	call   123b600 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477>
 11b4da5:	48 83 c4 20          	add    $0x20,%rsp
 11b4da9:	44 0f b7 b5 18 fc ff 	movzwl -0x3e8(%rbp),%r14d
 11b4db0:	ff 
 11b4db1:	4d 85 f6             	test   %r14,%r14
 11b4db4:	0f 85 9d 0b 00 00    	jne    11b5957 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1b77>
 11b4dba:	48 8b 8d 08 fc ff ff 	mov    -0x3f8(%rbp),%rcx
 11b4dc1:	4c 8b 85 10 fc ff ff 	mov    -0x3f0(%rbp),%r8
 11b4dc8:	48 8d 95 68 ff ff ff 	lea    -0x98(%rbp),%rdx
 11b4dcf:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b4dd3:	4c 89 fe             	mov    %r15,%rsi
 11b4dd6:	e8 45 3f 0b 00       	call   1268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>
 11b4ddb:	4c 8b bd 70 fe ff ff 	mov    -0x190(%rbp),%r15
 11b4de2:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11b4de6:	0f b6 4d 93          	movzbl -0x6d(%rbp),%ecx
 11b4dea:	f6 c1 01             	test   $0x1,%cl
 11b4ded:	0f 84 19 01 00 00    	je     11b4f0c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x112c>
 11b4df3:	49 81 ff 00 10 00 00 	cmp    $0x1000,%r15
 11b4dfa:	0f 82 0c 01 00 00    	jb     11b4f0c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x112c>
 11b4e00:	4c 3b bd c8 fd ff ff 	cmp    -0x238(%rbp),%r15
 11b4e07:	0f 87 ff 00 00 00    	ja     11b4f0c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x112c>
 11b4e0d:	c5 f8 28 85 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm0
 11b4e14:	ff 
 11b4e15:	c5 f8 29 85 90 fc ff 	vmovaps %xmm0,-0x370(%rbp)
 11b4e1c:	ff 
 11b4e1d:	c6 85 d0 fd ff ff 02 	movb   $0x2,-0x230(%rbp)
 11b4e24:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b4e2b:	48 89 85 a0 fc ff ff 	mov    %rax,-0x360(%rbp)
 11b4e32:	c6 85 a8 fc ff ff 02 	movb   $0x2,-0x358(%rbp)
 11b4e39:	48 8b 85 b0 fe ff ff 	mov    -0x150(%rbp),%rax
 11b4e40:	89 85 a9 fc ff ff    	mov    %eax,-0x357(%rbp)
 11b4e46:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 11b4e4d:	88 85 af fc ff ff    	mov    %al,-0x351(%rbp)
 11b4e53:	48 8b 85 88 fe ff ff 	mov    -0x178(%rbp),%rax
 11b4e5a:	66 89 85 ad fc ff ff 	mov    %ax,-0x353(%rbp)
 11b4e61:	c5 f8 28 85 20 fb ff 	vmovaps -0x4e0(%rbp),%xmm0
 11b4e68:	ff 
 11b4e69:	c5 f8 13 85 08 fe ff 	vmovlps %xmm0,-0x1f8(%rbp)
 11b4e70:	ff 
 11b4e71:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 11b4e77:	89 85 10 fe ff ff    	mov    %eax,-0x1f0(%rbp)
 11b4e7d:	0f b7 85 a4 fe ff ff 	movzwl -0x15c(%rbp),%eax
 11b4e84:	66 89 85 14 fe ff ff 	mov    %ax,-0x1ec(%rbp)
 11b4e8b:	88 8d 16 fe ff ff    	mov    %cl,-0x1ea(%rbp)
 11b4e91:	0f b6 45 96          	movzbl -0x6a(%rbp),%eax
 11b4e95:	88 85 17 fe ff ff    	mov    %al,-0x1e9(%rbp)
 11b4e9b:	48 83 ec 08          	sub    $0x8,%rsp
 11b4e9f:	48 8d 85 50 fd ff ff 	lea    -0x2b0(%rbp),%rax
 11b4ea6:	48 8d bd f0 fb ff ff 	lea    -0x410(%rbp),%rdi
 11b4ead:	48 8d b5 90 fc ff ff 	lea    -0x370(%rbp),%rsi
 11b4eb4:	4c 8d 8d 08 fe ff ff 	lea    -0x1f8(%rbp),%r9
 11b4ebb:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 11b4ebf:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b4ec3:	4d 89 f8             	mov    %r15,%r8
 11b4ec6:	50                   	push   %rax
 11b4ec7:	e8 d4 59 08 00       	call   123a8a0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_29486>
 11b4ecc:	48 83 c4 10          	add    $0x10,%rsp
 11b4ed0:	44 0f b7 b5 00 fc ff 	movzwl -0x400(%rbp),%r14d
 11b4ed7:	ff 
 11b4ed8:	4d 85 f6             	test   %r14,%r14
 11b4edb:	0f 85 c5 0a 00 00    	jne    11b59a6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1bc6>
 11b4ee1:	48 8b 8d f0 fb ff ff 	mov    -0x410(%rbp),%rcx
 11b4ee8:	48 85 c9             	test   %rcx,%rcx
 11b4eeb:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11b4eef:	74 1b                	je     11b4f0c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x112c>
 11b4ef1:	4c 8b 85 f8 fb ff ff 	mov    -0x408(%rbp),%r8
 11b4ef8:	48 8d 95 68 ff ff ff 	lea    -0x98(%rbp),%rdx
 11b4eff:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b4f03:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b4f07:	e8 14 3e 0b 00       	call   1268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>
 11b4f0c:	49 81 ff 00 10 00 00 	cmp    $0x1000,%r15
 11b4f13:	0f 93 c0             	setae  %al
 11b4f16:	80 7d c7 0a          	cmpb   $0xa,-0x39(%rbp)
 11b4f1a:	0f 93 c1             	setae  %cl
 11b4f1d:	f6 85 98 fe ff ff 10 	testb  $0x10,-0x168(%rbp)
 11b4f24:	0f 95 c2             	setne  %dl
 11b4f27:	20 c1                	and    %al,%cl
 11b4f29:	84 d1                	test   %dl,%cl
 11b4f2b:	0f 84 cc 00 00 00    	je     11b4ffd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x121d>
 11b4f31:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 11b4f35:	42 80 7c 38 ff 0a    	cmpb   $0xa,-0x1(%rax,%r15,1)
 11b4f3b:	0f 85 bc 00 00 00    	jne    11b4ffd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x121d>
 11b4f41:	48 8b 7d 98          	mov    -0x68(%rbp),%rdi
 11b4f45:	4c 89 fe             	mov    %r15,%rsi
 11b4f48:	e8 93 1f f9 ff       	call   1146ee0 <vortBrStableFixedWidthRecord>
 11b4f4d:	84 c0                	test   %al,%al
 11b4f4f:	0f 84 a8 00 00 00    	je     11b4ffd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x121d>
 11b4f55:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b4f59:	c5 fc 11 85 b0 f1 ff 	vmovups %ymm0,-0xe50(%rbp)
 11b4f60:	ff 
 11b4f61:	c5 fc 11 85 a0 f1 ff 	vmovups %ymm0,-0xe60(%rbp)
 11b4f68:	ff 
 11b4f69:	c5 fc 11 85 80 f1 ff 	vmovups %ymm0,-0xe80(%rbp)
 11b4f70:	ff 
 11b4f71:	c5 fc 11 85 60 f1 ff 	vmovups %ymm0,-0xea0(%rbp)
 11b4f78:	ff 
 11b4f79:	c5 fc 11 85 40 f1 ff 	vmovups %ymm0,-0xec0(%rbp)
 11b4f80:	ff 
 11b4f81:	48 8d 85 40 f1 ff ff 	lea    -0xec0(%rbp),%rax
 11b4f88:	44 0f b6 d3          	movzbl %bl,%r10d
 11b4f8c:	44 0f b6 85 98 fe ff 	movzbl -0x168(%rbp),%r8d
 11b4f93:	ff 
 11b4f94:	44 0f b6 4d d7       	movzbl -0x29(%rbp),%r9d
 11b4f99:	48 8d bd d8 fb ff ff 	lea    -0x428(%rbp),%rdi
 11b4fa0:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b4fa4:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11b4fa8:	4c 89 f9             	mov    %r15,%rcx
 11b4fab:	50                   	push   %rax
 11b4fac:	41 52                	push   %r10
 11b4fae:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 11b4fb4:	ff b5 20 ff ff ff    	push   -0xe0(%rbp)
 11b4fba:	c5 f8 77             	vzeroupper 
 11b4fbd:	e8 ce a4 07 00       	call   122f490 <br.encodeRecordOptimalCandidateWithOptionsAlloc>
 11b4fc2:	48 83 c4 20          	add    $0x20,%rsp
 11b4fc6:	0f b7 9d e8 fb ff ff 	movzwl -0x418(%rbp),%ebx
 11b4fcd:	48 85 db             	test   %rbx,%rbx
 11b4fd0:	0f 85 95 0a 00 00    	jne    11b5a6b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c8b>
 11b4fd6:	48 8b 8d d8 fb ff ff 	mov    -0x428(%rbp),%rcx
 11b4fdd:	48 85 c9             	test   %rcx,%rcx
 11b4fe0:	74 1b                	je     11b4ffd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x121d>
 11b4fe2:	4c 8b 85 e0 fb ff ff 	mov    -0x420(%rbp),%r8
 11b4fe9:	48 8d 95 68 ff ff ff 	lea    -0x98(%rbp),%rdx
 11b4ff0:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b4ff4:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b4ff8:	e8 23 3d 0b 00       	call   1268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>
 11b4ffd:	0f b6 45 94          	movzbl -0x6c(%rbp),%eax
 11b5001:	24 03                	and    $0x3,%al
 11b5003:	3c 02                	cmp    $0x2,%al
 11b5005:	0f 94 c0             	sete   %al
 11b5008:	80 7d c7 04          	cmpb   $0x4,-0x39(%rbp)
 11b500c:	0f 93 c1             	setae  %cl
 11b500f:	84 c8                	test   %cl,%al
 11b5011:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11b5015:	0f 84 ce 01 00 00    	je     11b51e9 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1409>
 11b501b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b501f:	c5 fc 11 85 20 f1 ff 	vmovups %ymm0,-0xee0(%rbp)
 11b5026:	ff 
 11b5027:	c5 fc 11 85 10 f1 ff 	vmovups %ymm0,-0xef0(%rbp)
 11b502e:	ff 
 11b502f:	c5 fc 11 85 f0 f0 ff 	vmovups %ymm0,-0xf10(%rbp)
 11b5036:	ff 
 11b5037:	c5 fc 11 85 d0 f0 ff 	vmovups %ymm0,-0xf30(%rbp)
 11b503e:	ff 
 11b503f:	c5 fc 11 85 b0 f0 ff 	vmovups %ymm0,-0xf50(%rbp)
 11b5046:	ff 
 11b5047:	c6 45 86 01          	movb   $0x1,-0x7a(%rbp)
 11b504b:	c6 45 87 06          	movb   $0x6,-0x79(%rbp)
 11b504f:	0f b6 45 b7          	movzbl -0x49(%rbp),%eax
 11b5053:	88 85 01 f6 ff ff    	mov    %al,-0x9ff(%rbp)
 11b5059:	48 c7 85 f0 f3 ff ff 	movq   $0x0,-0xc10(%rbp)
 11b5060:	00 00 00 00 
 11b5064:	0f b6 45 c6          	movzbl -0x3a(%rbp),%eax
 11b5068:	88 85 05 f6 ff ff    	mov    %al,-0x9fb(%rbp)
 11b506e:	c6 85 04 f6 ff ff 00 	movb   $0x0,-0x9fc(%rbp)
 11b5075:	c5 fc 11 85 20 f4 ff 	vmovups %ymm0,-0xbe0(%rbp)
 11b507c:	ff 
 11b507d:	c5 fc 11 85 40 f4 ff 	vmovups %ymm0,-0xbc0(%rbp)
 11b5084:	ff 
 11b5085:	c5 fc 11 85 60 f4 ff 	vmovups %ymm0,-0xba0(%rbp)
 11b508c:	ff 
 11b508d:	c5 fc 11 85 80 f4 ff 	vmovups %ymm0,-0xb80(%rbp)
 11b5094:	ff 
 11b5095:	c5 fc 11 85 a0 f4 ff 	vmovups %ymm0,-0xb60(%rbp)
 11b509c:	ff 
 11b509d:	c5 fc 11 85 c0 f4 ff 	vmovups %ymm0,-0xb40(%rbp)
 11b50a4:	ff 
 11b50a5:	c5 fc 11 85 e0 f4 ff 	vmovups %ymm0,-0xb20(%rbp)
 11b50ac:	ff 
 11b50ad:	c5 fc 11 85 00 f5 ff 	vmovups %ymm0,-0xb00(%rbp)
 11b50b4:	ff 
 11b50b5:	c5 fc 11 85 20 f5 ff 	vmovups %ymm0,-0xae0(%rbp)
 11b50bc:	ff 
 11b50bd:	c5 fc 11 85 40 f5 ff 	vmovups %ymm0,-0xac0(%rbp)
 11b50c4:	ff 
 11b50c5:	c5 fc 11 85 60 f5 ff 	vmovups %ymm0,-0xaa0(%rbp)
 11b50cc:	ff 
 11b50cd:	c5 fc 11 85 80 f5 ff 	vmovups %ymm0,-0xa80(%rbp)
 11b50d4:	ff 
 11b50d5:	c5 fc 11 85 a0 f5 ff 	vmovups %ymm0,-0xa60(%rbp)
 11b50dc:	ff 
 11b50dd:	c5 fc 11 85 c0 f5 ff 	vmovups %ymm0,-0xa40(%rbp)
 11b50e4:	ff 
 11b50e5:	48 c7 85 e0 f5 ff ff 	movq   $0x0,-0xa20(%rbp)
 11b50ec:	00 00 00 00 
 11b50f0:	c6 85 f8 f5 ff ff 38 	movb   $0x38,-0xa08(%rbp)
 11b50f7:	c6 85 00 f6 ff ff 00 	movb   $0x0,-0xa00(%rbp)
 11b50fe:	0f b6 45 86          	movzbl -0x7a(%rbp),%eax
 11b5102:	0f b6 4d 87          	movzbl -0x79(%rbp),%ecx
 11b5106:	88 85 fa f5 ff ff    	mov    %al,-0xa06(%rbp)
 11b510c:	88 8d fb f5 ff ff    	mov    %cl,-0xa05(%rbp)
 11b5112:	48 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%rax
 11b5119:	88 85 f9 f5 ff ff    	mov    %al,-0xa07(%rbp)
 11b511f:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11b5126:	48 89 85 e0 f3 ff ff 	mov    %rax,-0xc20(%rbp)
 11b512d:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11b5134:	48 89 85 e8 f3 ff ff 	mov    %rax,-0xc18(%rbp)
 11b513b:	c7 85 fc f5 ff ff 01 	movl   $0x101,-0xa04(%rbp)
 11b5142:	01 00 00 
 11b5145:	66 c7 85 02 f6 ff ff 	movw   $0x0,-0x9fe(%rbp)
 11b514c:	00 00 
 11b514e:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11b5152:	c5 f8 11 85 e8 f5 ff 	vmovups %xmm0,-0xa18(%rbp)
 11b5159:	ff 
 11b515a:	c5 fc 10 05 1e b2 e4 	vmovups -0x1b4de2(%rip),%ymm0        # 1000380 <__anon_29473>
 11b5161:	ff 
 11b5162:	c5 fc 11 85 00 f4 ff 	vmovups %ymm0,-0xc00(%rbp)
 11b5169:	ff 
 11b516a:	48 c7 85 f8 f3 ff ff 	movq   $0x0,-0xc08(%rbp)
 11b5171:	00 00 00 00 
 11b5175:	48 83 ec 08          	sub    $0x8,%rsp
 11b5179:	48 8d 85 e0 f3 ff ff 	lea    -0xc20(%rbp),%rax
 11b5180:	4c 8d 95 b0 f0 ff ff 	lea    -0xf50(%rbp),%r10
 11b5187:	48 8d bd c0 fb ff ff 	lea    -0x440(%rbp),%rdi
 11b518e:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11b5192:	48 89 da             	mov    %rbx,%rdx
 11b5195:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b5199:	4d 89 f8             	mov    %r15,%r8
 11b519c:	4d 89 e9             	mov    %r13,%r9
 11b519f:	50                   	push   %rax
 11b51a0:	41 52                	push   %r10
 11b51a2:	41 56                	push   %r14
 11b51a4:	c5 f8 77             	vzeroupper 
 11b51a7:	e8 84 99 07 00       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 11b51ac:	48 83 c4 20          	add    $0x20,%rsp
 11b51b0:	0f b7 9d d0 fb ff ff 	movzwl -0x430(%rbp),%ebx
 11b51b7:	85 db                	test   %ebx,%ebx
 11b51b9:	0f 85 9b 08 00 00    	jne    11b5a5a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c7a>
 11b51bf:	48 8b 8d c0 fb ff ff 	mov    -0x440(%rbp),%rcx
 11b51c6:	4c 8b 85 c8 fb ff ff 	mov    -0x438(%rbp),%r8
 11b51cd:	48 85 c9             	test   %rcx,%rcx
 11b51d0:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11b51d4:	74 13                	je     11b51e9 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1409>
 11b51d6:	48 8d 95 68 ff ff ff 	lea    -0x98(%rbp),%rdx
 11b51dd:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b51e1:	48 89 de             	mov    %rbx,%rsi
 11b51e4:	e8 37 3b 0b 00       	call   1268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>
 11b51e9:	49 81 ff 01 01 00 00 	cmp    $0x101,%r15
 11b51f0:	0f 92 c0             	setb   %al
 11b51f3:	84 45 95             	test   %al,-0x6b(%rbp)
 11b51f6:	0f 84 8f 00 00 00    	je     11b528b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x14ab>
 11b51fc:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b5203:	c6 80 d1 42 02 00 00 	movb   $0x0,0x242d1(%rax)
 11b520a:	c5 f8 10 85 68 ff ff 	vmovups -0x98(%rbp),%xmm0
 11b5211:	ff 
 11b5212:	48 83 ec 30          	sub    $0x30,%rsp
 11b5216:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11b521d:	48 89 44 24 28       	mov    %rax,0x28(%rsp)
 11b5222:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11b5229:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 11b522e:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11b5232:	89 44 24 18          	mov    %eax,0x18(%rsp)
 11b5236:	0f b6 85 98 fe ff ff 	movzbl -0x168(%rbp),%eax
 11b523d:	89 44 24 10          	mov    %eax,0x10(%rsp)
 11b5241:	c5 f8 11 04 24       	vmovups %xmm0,(%rsp)
 11b5246:	48 8d bd 78 fa ff ff 	lea    -0x588(%rbp),%rdi
 11b524d:	48 89 de             	mov    %rbx,%rsi
 11b5250:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11b5254:	4c 89 f9             	mov    %r15,%rcx
 11b5257:	4d 89 e8             	mov    %r13,%r8
 11b525a:	4d 89 f1             	mov    %r14,%r9
 11b525d:	e8 2e 74 07 00       	call   122c690 <br.selectRatioStaticDictionaryAlloc>
 11b5262:	48 83 c4 30          	add    $0x30,%rsp
 11b5266:	0f b7 9d 88 fa ff ff 	movzwl -0x578(%rbp),%ebx
 11b526d:	48 85 db             	test   %rbx,%rbx
 11b5270:	0f 85 64 08 00 00    	jne    11b5ada <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1cfa>
 11b5276:	c5 f8 10 85 78 fa ff 	vmovups -0x588(%rbp),%xmm0
 11b527d:	ff 
 11b527e:	c5 f8 11 85 68 ff ff 	vmovups %xmm0,-0x98(%rbp)
 11b5285:	ff 
 11b5286:	e9 81 00 00 00       	jmp    11b530c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x152c>
 11b528b:	49 81 ff 01 10 00 00 	cmp    $0x1001,%r15
 11b5292:	0f 92 c0             	setb   %al
 11b5295:	84 45 97             	test   %al,-0x69(%rbp)
 11b5298:	8b 8d 20 fe ff ff    	mov    -0x1e0(%rbp),%ecx
 11b529e:	74 6c                	je     11b530c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x152c>
 11b52a0:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b52a7:	c6 80 d1 42 02 00 00 	movb   $0x0,0x242d1(%rax)
 11b52ae:	66 85 c9             	test   %cx,%cx
 11b52b1:	0f 44 8d 24 fe ff ff 	cmove  -0x1dc(%rbp),%ecx
 11b52b8:	66 85 c9             	test   %cx,%cx
 11b52bb:	74 4f                	je     11b530c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x152c>
 11b52bd:	0f b7 c1             	movzwl %cx,%eax
 11b52c0:	48 83 ec 08          	sub    $0x8,%rsp
 11b52c4:	4c 8d 95 68 ff ff ff 	lea    -0x98(%rbp),%r10
 11b52cb:	44 0f b6 5d d7       	movzbl -0x29(%rbp),%r11d
 11b52d0:	44 0f b6 8d 98 fe ff 	movzbl -0x168(%rbp),%r9d
 11b52d7:	ff 
 11b52d8:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 11b52dc:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 11b52e0:	4c 89 fa             	mov    %r15,%rdx
 11b52e3:	4c 89 e9             	mov    %r13,%rcx
 11b52e6:	4d 89 f0             	mov    %r14,%r8
 11b52e9:	41 52                	push   %r10
 11b52eb:	50                   	push   %rax
 11b52ec:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 11b52f2:	ff b5 20 ff ff ff    	push   -0xe0(%rbp)
 11b52f8:	41 53                	push   %r11
 11b52fa:	e8 01 1a 00 00       	call   11b6d00 <br.selectExtendedRatioStaticDictionary>
 11b52ff:	48 83 c4 30          	add    $0x30,%rsp
 11b5303:	66 85 c0             	test   %ax,%ax
 11b5306:	0f 85 05 09 00 00    	jne    11b5c11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1e31>
 11b530c:	c5 f8 28 85 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm0
 11b5313:	ff 
 11b5314:	c5 f8 29 85 e0 fa ff 	vmovaps %xmm0,-0x520(%rbp)
 11b531b:	ff 
 11b531c:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 11b5323:	48 89 85 f0 fa ff ff 	mov    %rax,-0x510(%rbp)
 11b532a:	48 8b 85 18 fe ff ff 	mov    -0x1e8(%rbp),%rax
 11b5331:	48 89 85 f8 fa ff ff 	mov    %rax,-0x508(%rbp)
 11b5338:	48 8d bd b0 f9 ff ff 	lea    -0x650(%rbp),%rdi
 11b533f:	48 8d b5 e0 fa ff ff 	lea    -0x520(%rbp),%rsi
 11b5346:	ba 09 00 00 00       	mov    $0x9,%edx
 11b534b:	4c 89 f9             	mov    %r15,%rcx
 11b534e:	45 31 c0             	xor    %r8d,%r8d
 11b5351:	e8 3a 22 0c 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 11b5356:	4c 8b ad 68 ff ff ff 	mov    -0x98(%rbp),%r13
 11b535d:	48 8b 9d 70 ff ff ff 	mov    -0x90(%rbp),%rbx
 11b5364:	48 8d bd 50 fc ff ff 	lea    -0x3b0(%rbp),%rdi
 11b536b:	48 8d 95 60 fc ff ff 	lea    -0x3a0(%rbp),%rdx
 11b5372:	4c 89 fe             	mov    %r15,%rsi
 11b5375:	e8 16 1c 00 00       	call   11b6f90 <br.encodedStoredStreamBoundWithOptions>
 11b537a:	44 0f b7 b5 58 fc ff 	movzwl -0x3a8(%rbp),%r14d
 11b5381:	ff 
 11b5382:	66 45 85 f6          	test   %r14w,%r14w
 11b5386:	0f 85 ef 03 00 00    	jne    11b577b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x199b>
 11b538c:	48 3b 9d 50 fc ff ff 	cmp    -0x3b0(%rbp),%rbx
 11b5393:	0f 86 c7 00 00 00    	jbe    11b5460 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1680>
 11b5399:	48 8d bd d0 fd ff ff 	lea    -0x230(%rbp),%rdi
 11b53a0:	4c 8d 8d 60 fc ff ff 	lea    -0x3a0(%rbp),%r9
 11b53a7:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11b53ab:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 11b53af:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 11b53b3:	4d 89 f8             	mov    %r15,%r8
 11b53b6:	e8 e5 14 0c 00       	call   12768a0 <br.encodeStoredStreamRecorded__anon_28729>
 11b53bb:	44 0f b7 b5 e0 fd ff 	movzwl -0x220(%rbp),%r14d
 11b53c2:	ff 
 11b53c3:	66 45 85 f6          	test   %r14w,%r14w
 11b53c7:	0f 85 ae 03 00 00    	jne    11b577b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x199b>
 11b53cd:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11b53d1:	48 8b 48 10          	mov    0x10(%rax),%rcx
 11b53d5:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b53d9:	48 8b 38             	mov    (%rax),%rdi
 11b53dc:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b53e0:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 11b53e7:	48 85 f6             	test   %rsi,%rsi
 11b53ea:	74 51                	je     11b543d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x165d>
 11b53ec:	48 83 fe 01          	cmp    $0x1,%rsi
 11b53f0:	0f 85 43 01 00 00    	jne    11b5539 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1759>
 11b53f6:	31 d2                	xor    %edx,%edx
 11b53f8:	40 f6 c6 01          	test   $0x1,%sil
 11b53fc:	74 3f                	je     11b543d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x165d>
 11b53fe:	48 8d 71 20          	lea    0x20(%rcx),%rsi
 11b5402:	4c 69 c2 18 01 00 00 	imul   $0x118,%rdx,%r8
 11b5409:	46 0f b6 8c 06 10 01 	movzbl 0x110(%rsi,%r8,1),%r9d
 11b5410:	00 00 
 11b5412:	41 80 e1 0f          	and    $0xf,%r9b
 11b5416:	41 80 f9 07          	cmp    $0x7,%r9b
 11b541a:	75 21                	jne    11b543d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x165d>
 11b541c:	4c 01 c6             	add    %r8,%rsi
 11b541f:	80 7e 40 00          	cmpb   $0x0,0x40(%rsi)
 11b5423:	74 18                	je     11b543d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x165d>
 11b5425:	48 39 5e 38          	cmp    %rbx,0x38(%rsi)
 11b5429:	75 12                	jne    11b543d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x165d>
 11b542b:	4c 39 ac d1 d0 32 02 	cmp    %r13,0x232d0(%rcx,%rdx,8)
 11b5432:	00 
 11b5433:	75 08                	jne    11b543d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x165d>
 11b5435:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 11b543c:	00 
 11b543d:	4c 8b b5 d0 fd ff ff 	mov    -0x230(%rbp),%r14
 11b5444:	4c 8b bd d8 fd ff ff 	mov    -0x228(%rbp),%r15
 11b544b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b544f:	4c 89 ee             	mov    %r13,%rsi
 11b5452:	48 89 da             	mov    %rbx,%rdx
 11b5455:	31 c9                	xor    %ecx,%ecx
 11b5457:	ff 50 18             	call   *0x18(%rax)
 11b545a:	4d 89 f5             	mov    %r14,%r13
 11b545d:	4c 89 fb             	mov    %r15,%rbx
 11b5460:	80 bd e8 f9 ff ff 00 	cmpb   $0x0,-0x618(%rbp)
 11b5467:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11b546b:	74 3c                	je     11b54a9 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x16c9>
 11b546d:	48 8b 85 d0 f9 ff ff 	mov    -0x630(%rbp),%rax
 11b5474:	48 8b 8d e0 f9 ff ff 	mov    -0x620(%rbp),%rcx
 11b547b:	48 69 d1 18 01 00 00 	imul   $0x118,%rcx,%rdx
 11b5482:	48 89 5c 10 58       	mov    %rbx,0x58(%rax,%rdx,1)
 11b5487:	c6 44 10 60 01       	movb   $0x1,0x60(%rax,%rdx,1)
 11b548c:	4c 89 ac c8 d0 32 02 	mov    %r13,0x232d0(%rax,%rcx,8)
 11b5493:	00 
 11b5494:	0f b6 95 00 fa ff ff 	movzbl -0x600(%rbp),%edx
 11b549b:	80 e2 0f             	and    $0xf,%dl
 11b549e:	80 fa 07             	cmp    $0x7,%dl
 11b54a1:	0f 94 84 08 d3 42 02 	sete   0x242d3(%rax,%rcx,1)
 11b54a8:	00 
 11b54a9:	48 8d bd b0 f9 ff ff 	lea    -0x650(%rbp),%rdi
 11b54b0:	e8 bb 1c 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b54b5:	4d 85 f6             	test   %r14,%r14
 11b54b8:	74 26                	je     11b54e0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1700>
 11b54ba:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b54be:	48 8b 38             	mov    (%rax),%rdi
 11b54c1:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b54c5:	49 c1 e6 05          	shl    $0x5,%r14
 11b54c9:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 11b54cd:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b54d1:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 11b54d8:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b54dd:	ff 50 18             	call   *0x18(%rax)
 11b54e0:	4d 85 e4             	test   %r12,%r12
 11b54e3:	74 25                	je     11b550a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x172a>
 11b54e5:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b54e9:	48 8b 38             	mov    (%rax),%rdi
 11b54ec:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b54f0:	4d 01 e4             	add    %r12,%r12
 11b54f3:	4b 8d 14 64          	lea    (%r12,%r12,2),%rdx
 11b54f7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b54fb:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b5502:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b5507:	ff 50 18             	call   *0x18(%rax)
 11b550a:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b5511:	e8 5a 1c 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b5516:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11b551a:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 11b5520:	4c 89 28             	mov    %r13,(%rax)
 11b5523:	48 89 58 08          	mov    %rbx,0x8(%rax)
 11b5527:	48 81 c4 98 0f 00 00 	add    $0xf98,%rsp
 11b552e:	5b                   	pop    %rbx
 11b552f:	41 5c                	pop    %r12
 11b5531:	41 5d                	pop    %r13
 11b5533:	41 5e                	pop    %r14
 11b5535:	41 5f                	pop    %r15
 11b5537:	5d                   	pop    %rbp
 11b5538:	c3                   	ret    
 11b5539:	49 89 f0             	mov    %rsi,%r8
 11b553c:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 11b5540:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 11b5544:	31 d2                	xor    %edx,%edx
 11b5546:	eb 1c                	jmp    11b5564 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1784>
 11b5548:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 11b554f:	00 
 11b5550:	48 83 c2 02          	add    $0x2,%rdx
 11b5554:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 11b555b:	49 39 d0             	cmp    %rdx,%r8
 11b555e:	0f 84 94 fe ff ff    	je     11b53f8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1618>
 11b5564:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 11b556b:	00 
 11b556c:	41 80 e2 0f          	and    $0xf,%r10b
 11b5570:	41 80 fa 07          	cmp    $0x7,%r10b
 11b5574:	75 2a                	jne    11b55a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x17c0>
 11b5576:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 11b557b:	74 23                	je     11b55a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x17c0>
 11b557d:	49 39 19             	cmp    %rbx,(%r9)
 11b5580:	75 1e                	jne    11b55a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x17c0>
 11b5582:	4c 39 ac d1 d0 32 02 	cmp    %r13,0x232d0(%rcx,%rdx,8)
 11b5589:	00 
 11b558a:	75 14                	jne    11b55a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x17c0>
 11b558c:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 11b5593:	00 
 11b5594:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 11b559b:	00 00 00 00 00 
 11b55a0:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 11b55a7:	00 
 11b55a8:	41 80 e2 0f          	and    $0xf,%r10b
 11b55ac:	41 80 fa 07          	cmp    $0x7,%r10b
 11b55b0:	75 9e                	jne    11b5550 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1770>
 11b55b2:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 11b55b9:	00 
 11b55ba:	74 94                	je     11b5550 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1770>
 11b55bc:	49 39 99 18 01 00 00 	cmp    %rbx,0x118(%r9)
 11b55c3:	75 8b                	jne    11b5550 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1770>
 11b55c5:	4c 39 ac d1 d8 32 02 	cmp    %r13,0x232d8(%rcx,%rdx,8)
 11b55cc:	00 
 11b55cd:	75 81                	jne    11b5550 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1770>
 11b55cf:	c6 84 11 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rdx,1)
 11b55d6:	00 
 11b55d7:	e9 74 ff ff ff       	jmp    11b5550 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1770>
 11b55dc:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 11b55e3:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11b55ea:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b55ee:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 11b55f2:	4c 89 f6             	mov    %r14,%rsi
 11b55f5:	e8 a6 0f 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b55fa:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b55fe:	48 85 c9             	test   %rcx,%rcx
 11b5601:	74 1e                	je     11b5621 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1841>
 11b5603:	49 8b 3e             	mov    (%r14),%rdi
 11b5606:	49 8b 46 08          	mov    0x8(%r14),%rax
 11b560a:	48 c1 e1 05          	shl    $0x5,%rcx
 11b560e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b5612:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5616:	4c 89 ee             	mov    %r13,%rsi
 11b5619:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b561e:	ff 50 18             	call   *0x18(%rax)
 11b5621:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 11b5628:	48 85 c9             	test   %rcx,%rcx
 11b562b:	74 25                	je     11b5652 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1872>
 11b562d:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5631:	48 8b 38             	mov    (%rax),%rdi
 11b5634:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5638:	48 01 c9             	add    %rcx,%rcx
 11b563b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b563f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5643:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b564a:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b564f:	ff 50 18             	call   *0x18(%rax)
 11b5652:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 11b5659:	74 25                	je     11b5680 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x18a0>
 11b565b:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 11b5662:	48 69 8d f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rcx
 11b5669:	18 01 00 00 
 11b566d:	89 da                	mov    %ebx,%edx
 11b566f:	c1 e2 04             	shl    $0x4,%edx
 11b5672:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b5679:	01 
 11b567a:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b5680:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b5687:	e8 e4 1a 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b568c:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11b5690:	66 89 58 10          	mov    %bx,0x10(%rax)
 11b5694:	e9 8e fe ff ff       	jmp    11b5527 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1747>
 11b5699:	4d 85 f6             	test   %r14,%r14
 11b569c:	74 1e                	je     11b56bc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x18dc>
 11b569e:	48 8b 3b             	mov    (%rbx),%rdi
 11b56a1:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b56a5:	49 c1 e6 05          	shl    $0x5,%r14
 11b56a9:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 11b56ad:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b56b1:	4c 89 ee             	mov    %r13,%rsi
 11b56b4:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b56b9:	ff 50 18             	call   *0x18(%rax)
 11b56bc:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 11b56c3:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11b56ca:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b56ce:	48 89 de             	mov    %rbx,%rsi
 11b56d1:	e8 ca 0e 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b56d6:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b56da:	48 85 c9             	test   %rcx,%rcx
 11b56dd:	4c 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%r14
 11b56e4:	74 22                	je     11b5708 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1928>
 11b56e6:	48 8b 3b             	mov    (%rbx),%rdi
 11b56e9:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b56ed:	48 c1 e1 05          	shl    $0x5,%rcx
 11b56f1:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b56f5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b56f9:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 11b5700:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b5705:	ff 50 18             	call   *0x18(%rax)
 11b5708:	4d 85 f6             	test   %r14,%r14
 11b570b:	74 25                	je     11b5732 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1952>
 11b570d:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5711:	48 8b 38             	mov    (%rax),%rdi
 11b5714:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5718:	4d 01 f6             	add    %r14,%r14
 11b571b:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 11b571f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5723:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b572a:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b572f:	ff 50 18             	call   *0x18(%rax)
 11b5732:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 11b5739:	74 26                	je     11b5761 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1981>
 11b573b:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 11b5742:	48 69 8d f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rcx
 11b5749:	18 01 00 00 
 11b574d:	44 89 fa             	mov    %r15d,%edx
 11b5750:	c1 e2 04             	shl    $0x4,%edx
 11b5753:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b575a:	01 
 11b575b:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b5761:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b5768:	e8 03 1a 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b576d:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11b5771:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 11b5776:	e9 ac fd ff ff       	jmp    11b5527 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1747>
 11b577b:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b577f:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b5783:	4c 89 ea             	mov    %r13,%rdx
 11b5786:	48 89 d9             	mov    %rbx,%rcx
 11b5789:	e8 12 0e 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b578e:	80 bd e8 f9 ff ff 00 	cmpb   $0x0,-0x618(%rbp)
 11b5795:	41 0f b7 de          	movzwl %r14w,%ebx
 11b5799:	74 25                	je     11b57c0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x19e0>
 11b579b:	48 8b 85 d0 f9 ff ff 	mov    -0x630(%rbp),%rax
 11b57a2:	48 69 8d e0 f9 ff ff 	imul   $0x118,-0x620(%rbp),%rcx
 11b57a9:	18 01 00 00 
 11b57ad:	89 da                	mov    %ebx,%edx
 11b57af:	c1 e2 04             	shl    $0x4,%edx
 11b57b2:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b57b9:	01 
 11b57ba:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b57c0:	48 8d bd b0 f9 ff ff 	lea    -0x650(%rbp),%rdi
 11b57c7:	e8 a4 19 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b57cc:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b57d0:	48 85 c9             	test   %rcx,%rcx
 11b57d3:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 11b57da:	74 1f                	je     11b57fb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1a1b>
 11b57dc:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b57e0:	48 8b 38             	mov    (%rax),%rdi
 11b57e3:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b57e7:	48 c1 e1 05          	shl    $0x5,%rcx
 11b57eb:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b57ef:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b57f3:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b57f8:	ff 50 18             	call   *0x18(%rax)
 11b57fb:	4d 85 e4             	test   %r12,%r12
 11b57fe:	74 25                	je     11b5825 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1a45>
 11b5800:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5804:	48 8b 38             	mov    (%rax),%rdi
 11b5807:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b580b:	4d 01 e4             	add    %r12,%r12
 11b580e:	4b 8d 14 64          	lea    (%r12,%r12,2),%rdx
 11b5812:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5816:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b581d:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b5822:	ff 50 18             	call   *0x18(%rax)
 11b5825:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 11b582c:	74 23                	je     11b5851 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1a71>
 11b582e:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 11b5835:	48 69 8d f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rcx
 11b583c:	18 01 00 00 
 11b5840:	c1 e3 04             	shl    $0x4,%ebx
 11b5843:	c5 f8 10 83 f0 5d 03 	vmovups 0x1035df0(%rbx),%xmm0
 11b584a:	01 
 11b584b:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b5851:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b5858:	e8 13 19 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b585d:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11b5861:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 11b5866:	e9 bc fc ff ff       	jmp    11b5527 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1747>
 11b586b:	80 bd 68 f8 ff ff 00 	cmpb   $0x0,-0x798(%rbp)
 11b5872:	74 26                	je     11b589a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1aba>
 11b5874:	48 8b 85 50 f8 ff ff 	mov    -0x7b0(%rbp),%rax
 11b587b:	48 69 8d 60 f8 ff ff 	imul   $0x118,-0x7a0(%rbp),%rcx
 11b5882:	18 01 00 00 
 11b5886:	44 89 f2             	mov    %r14d,%edx
 11b5889:	c1 e2 04             	shl    $0x4,%edx
 11b588c:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b5893:	01 
 11b5894:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b589a:	48 8d bd 30 f8 ff ff 	lea    -0x7d0(%rbp),%rdi
 11b58a1:	e8 ca 18 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b58a6:	4d 85 ed             	test   %r13,%r13
 11b58a9:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11b58ad:	74 28                	je     11b58d7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1af7>
 11b58af:	48 8b 3b             	mov    (%rbx),%rdi
 11b58b2:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b58b6:	4d 01 ed             	add    %r13,%r13
 11b58b9:	4a 8d 14 6d 00 00 00 	lea    0x0(,%r13,2),%rdx
 11b58c0:	00 
 11b58c1:	4c 01 ea             	add    %r13,%rdx
 11b58c4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b58c8:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b58cf:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b58d4:	ff 50 18             	call   *0x18(%rax)
 11b58d7:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 11b58de:	48 85 d2             	test   %rdx,%rdx
 11b58e1:	0f 84 2a 01 00 00    	je     11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b58e7:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b58eb:	48 89 de             	mov    %rbx,%rsi
 11b58ee:	48 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%rcx
 11b58f5:	e8 a6 0c 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b58fa:	e9 12 01 00 00       	jmp    11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b58ff:	80 bd 48 fa ff ff 00 	cmpb   $0x0,-0x5b8(%rbp)
 11b5906:	74 26                	je     11b592e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1b4e>
 11b5908:	48 8b 85 30 fa ff ff 	mov    -0x5d0(%rbp),%rax
 11b590f:	48 69 8d 40 fa ff ff 	imul   $0x118,-0x5c0(%rbp),%rcx
 11b5916:	18 01 00 00 
 11b591a:	44 89 fa             	mov    %r15d,%edx
 11b591d:	c1 e2 04             	shl    $0x4,%edx
 11b5920:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b5927:	01 
 11b5928:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b592e:	48 8d bd 10 fa ff ff 	lea    -0x5f0(%rbp),%rdi
 11b5935:	e8 36 18 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b593a:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 11b5941:	48 85 d2             	test   %rdx,%rdx
 11b5944:	0f 84 e8 fd ff ff    	je     11b5732 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1952>
 11b594a:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b594e:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b5952:	e9 22 02 00 00       	jmp    11b5b79 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1d99>
 11b5957:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 11b595e:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11b5965:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b5969:	4c 89 fe             	mov    %r15,%rsi
 11b596c:	e8 2f 0c 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b5971:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b5975:	48 85 c9             	test   %rcx,%rcx
 11b5978:	74 1e                	je     11b5998 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1bb8>
 11b597a:	49 8b 3f             	mov    (%r15),%rdi
 11b597d:	49 8b 47 08          	mov    0x8(%r15),%rax
 11b5981:	48 c1 e1 05          	shl    $0x5,%rcx
 11b5985:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b5989:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b598d:	4c 89 ee             	mov    %r13,%rsi
 11b5990:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b5995:	ff 50 18             	call   *0x18(%rax)
 11b5998:	4d 85 e4             	test   %r12,%r12
 11b599b:	74 74                	je     11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b599d:	49 8b 3f             	mov    (%r15),%rdi
 11b59a0:	49 8b 47 08          	mov    0x8(%r15),%rax
 11b59a4:	eb 51                	jmp    11b59f7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c17>
 11b59a6:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 11b59ad:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11b59b4:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b59b8:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 11b59bc:	48 89 de             	mov    %rbx,%rsi
 11b59bf:	e8 dc 0b 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b59c4:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b59c8:	48 85 c9             	test   %rcx,%rcx
 11b59cb:	74 1e                	je     11b59eb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c0b>
 11b59cd:	48 8b 3b             	mov    (%rbx),%rdi
 11b59d0:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b59d4:	48 c1 e1 05          	shl    $0x5,%rcx
 11b59d8:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b59dc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b59e0:	4c 89 ee             	mov    %r13,%rsi
 11b59e3:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b59e8:	ff 50 18             	call   *0x18(%rax)
 11b59eb:	4d 85 e4             	test   %r12,%r12
 11b59ee:	74 21                	je     11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b59f0:	48 8b 3b             	mov    (%rbx),%rdi
 11b59f3:	48 8b 43 08          	mov    0x8(%rbx),%rax
 11b59f7:	4d 01 e4             	add    %r12,%r12
 11b59fa:	4b 8d 14 64          	lea    (%r12,%r12,2),%rdx
 11b59fe:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5a02:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b5a09:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b5a0e:	ff 50 18             	call   *0x18(%rax)
 11b5a11:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 11b5a18:	74 26                	je     11b5a40 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c60>
 11b5a1a:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 11b5a21:	48 69 8d f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rcx
 11b5a28:	18 01 00 00 
 11b5a2c:	44 89 f2             	mov    %r14d,%edx
 11b5a2f:	c1 e2 04             	shl    $0x4,%edx
 11b5a32:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b5a39:	01 
 11b5a3a:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b5a40:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b5a47:	e8 24 17 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b5a4c:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11b5a50:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 11b5a55:	e9 cd fa ff ff       	jmp    11b5527 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1747>
 11b5a5a:	31 c9                	xor    %ecx,%ecx
 11b5a5c:	41 b8 00 00 00 00    	mov    $0x0,%r8d
 11b5a62:	83 fb 52             	cmp    $0x52,%ebx
 11b5a65:	0f 84 62 f7 ff ff    	je     11b51cd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x13ed>
 11b5a6b:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 11b5a72:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11b5a79:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b5a7d:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b5a81:	e8 1a 0b 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b5a86:	4d 85 f6             	test   %r14,%r14
 11b5a89:	74 2a                	je     11b5ab5 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1cd5>
 11b5a8b:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5a8f:	48 8b 38             	mov    (%rax),%rdi
 11b5a92:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5a96:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b5a9a:	48 c1 e1 05          	shl    $0x5,%rcx
 11b5a9e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b5aa2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5aa6:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 11b5aad:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b5ab2:	ff 50 18             	call   *0x18(%rax)
 11b5ab5:	48 83 bd 60 ff ff ff 	cmpq   $0x0,-0xa0(%rbp)
 11b5abc:	00 
 11b5abd:	0f 84 8f fb ff ff    	je     11b5652 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1872>
 11b5ac3:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5ac7:	48 8b 38             	mov    (%rax),%rdi
 11b5aca:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5ace:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 11b5ad5:	e9 5e fb ff ff       	jmp    11b5638 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1858>
 11b5ada:	4d 85 f6             	test   %r14,%r14
 11b5add:	74 22                	je     11b5b01 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1d21>
 11b5adf:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5ae3:	48 8b 38             	mov    (%rax),%rdi
 11b5ae6:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5aea:	49 c1 e6 05          	shl    $0x5,%r14
 11b5aee:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 11b5af2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5af6:	4c 89 ee             	mov    %r13,%rsi
 11b5af9:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b5afe:	ff 50 18             	call   *0x18(%rax)
 11b5b01:	4d 85 e4             	test   %r12,%r12
 11b5b04:	0f 84 48 fb ff ff    	je     11b5652 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1872>
 11b5b0a:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5b0e:	48 8b 38             	mov    (%rax),%rdi
 11b5b11:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5b15:	4d 01 e4             	add    %r12,%r12
 11b5b18:	4b 8d 14 64          	lea    (%r12,%r12,2),%rdx
 11b5b1c:	e9 1e fb ff ff       	jmp    11b563f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x185f>
 11b5b21:	80 bd 48 fa ff ff 00 	cmpb   $0x0,-0x5b8(%rbp)
 11b5b28:	74 26                	je     11b5b50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1d70>
 11b5b2a:	48 8b 85 30 fa ff ff 	mov    -0x5d0(%rbp),%rax
 11b5b31:	48 69 8d 40 fa ff ff 	imul   $0x118,-0x5c0(%rbp),%rcx
 11b5b38:	18 01 00 00 
 11b5b3c:	44 89 fa             	mov    %r15d,%edx
 11b5b3f:	c1 e2 04             	shl    $0x4,%edx
 11b5b42:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b5b49:	01 
 11b5b4a:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 11b5b50:	48 8d bd 10 fa ff ff 	lea    -0x5f0(%rbp),%rdi
 11b5b57:	e8 14 16 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b5b5c:	48 83 bd 48 ff ff ff 	cmpq   $0x0,-0xb8(%rbp)
 11b5b63:	00 
 11b5b64:	0f 84 c8 fb ff ff    	je     11b5732 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1952>
 11b5b6a:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b5b6e:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b5b72:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 11b5b79:	48 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%rcx
 11b5b80:	e8 1b 0a 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b5b85:	e9 a8 fb ff ff       	jmp    11b5732 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1952>
 11b5b8a:	48 83 7d a0 00       	cmpq   $0x0,-0x60(%rbp)
 11b5b8f:	74 2a                	je     11b5bbb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1ddb>
 11b5b91:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5b95:	48 8b 38             	mov    (%rax),%rdi
 11b5b98:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5b9c:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b5ba0:	48 c1 e1 05          	shl    $0x5,%rcx
 11b5ba4:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b5ba8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5bac:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 11b5bb3:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b5bb8:	ff 50 18             	call   *0x18(%rax)
 11b5bbb:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 11b5bc2:	48 85 c0             	test   %rax,%rax
 11b5bc5:	74 28                	je     11b5bef <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1e0f>
 11b5bc7:	48 89 c1             	mov    %rax,%rcx
 11b5bca:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5bce:	48 8b 38             	mov    (%rax),%rdi
 11b5bd1:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5bd5:	48 01 c9             	add    %rcx,%rcx
 11b5bd8:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b5bdc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5be0:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b5be7:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b5bec:	ff 50 18             	call   *0x18(%rax)
 11b5bef:	48 83 bd 48 ff ff ff 	cmpq   $0x0,-0xb8(%rbp)
 11b5bf6:	00 
 11b5bf7:	0f 84 14 fe ff ff    	je     11b5a11 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1c31>
 11b5bfd:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b5c01:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b5c05:	48 8b 95 48 ff ff ff 	mov    -0xb8(%rbp),%rdx
 11b5c0c:	e9 dd fc ff ff       	jmp    11b58ee <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1b0e>
 11b5c11:	89 c3                	mov    %eax,%ebx
 11b5c13:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 11b5c1a:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11b5c21:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11b5c25:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 11b5c29:	e8 72 09 0c 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 11b5c2e:	4d 85 f6             	test   %r14,%r14
 11b5c31:	74 2a                	je     11b5c5d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1e7d>
 11b5c33:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5c37:	48 8b 38             	mov    (%rax),%rdi
 11b5c3a:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5c3e:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 11b5c42:	48 c1 e1 05          	shl    $0x5,%rcx
 11b5c46:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b5c4a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5c4e:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 11b5c55:	b9 03 00 00 00       	mov    $0x3,%ecx
 11b5c5a:	ff 50 18             	call   *0x18(%rax)
 11b5c5d:	48 83 bd 60 ff ff ff 	cmpq   $0x0,-0xa0(%rbp)
 11b5c64:	00 
 11b5c65:	74 2c                	je     11b5c93 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1eb3>
 11b5c67:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 11b5c6b:	48 8b 38             	mov    (%rax),%rdi
 11b5c6e:	48 8b 40 08          	mov    0x8(%rax),%rax
 11b5c72:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 11b5c79:	48 01 c9             	add    %rcx,%rcx
 11b5c7c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 11b5c80:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11b5c84:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 11b5c8b:	b9 01 00 00 00       	mov    $0x1,%ecx
 11b5c90:	ff 50 18             	call   *0x18(%rax)
 11b5c93:	80 bd f8 fe ff ff 00 	cmpb   $0x0,-0x108(%rbp)
 11b5c9a:	74 26                	je     11b5cc2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1ee2>
 11b5c9c:	48 69 85 f0 fe ff ff 	imul   $0x118,-0x110(%rbp),%rax
 11b5ca3:	18 01 00 00 
 11b5ca7:	48 8b 8d e0 fe ff ff 	mov    -0x120(%rbp),%rcx
 11b5cae:	0f b7 d3             	movzwl %bx,%edx
 11b5cb1:	c1 e2 04             	shl    $0x4,%edx
 11b5cb4:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 11b5cbb:	01 
 11b5cbc:	c5 f8 11 44 01 68    	vmovups %xmm0,0x68(%rcx,%rax,1)
 11b5cc2:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 11b5cc9:	e8 a2 14 0c 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11b5cce:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 11b5cd2:	66 89 58 10          	mov    %bx,0x10(%rax)
 11b5cd6:	e9 4c f8 ff ff       	jmp    11b5527 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584+0x1747>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
