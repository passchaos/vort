 11ba820:	44 8b 0c 8f          	mov    (%rdi,%rcx,4),%r9d
 11ba824:	4c 89 8c cd d8 eb ff 	mov    %r9,-0x1428(%rbp,%rcx,8)
 11ba82b:	ff 
 11ba82c:	66 89 8c 4d d0 fd ff 	mov    %cx,-0x230(%rbp,%rcx,2)
 11ba833:	ff 
 11ba834:	44 8b 4c 8f 04       	mov    0x4(%rdi,%rcx,4),%r9d
 11ba839:	4c 89 8c cd e0 eb ff 	mov    %r9,-0x1420(%rbp,%rcx,8)
 11ba840:	ff 
 11ba841:	44 8d 49 01          	lea    0x1(%rcx),%r9d
 11ba845:	66 44 89 8c 4d d2 fd 	mov    %r9w,-0x22e(%rbp,%rcx,2)
 11ba84c:	ff ff 
 11ba84e:	44 8b 4c 8f 08       	mov    0x8(%rdi,%rcx,4),%r9d
 11ba853:	4c 89 8c cd e8 eb ff 	mov    %r9,-0x1418(%rbp,%rcx,8)
 11ba85a:	ff 
 11ba85b:	44 8d 49 02          	lea    0x2(%rcx),%r9d
 11ba85f:	66 44 89 8c 4d d4 fd 	mov    %r9w,-0x22c(%rbp,%rcx,2)
 11ba866:	ff ff 
 11ba868:	44 8b 4c 8f 0c       	mov    0xc(%rdi,%rcx,4),%r9d
 11ba86d:	4c 89 8c cd f0 eb ff 	mov    %r9,-0x1410(%rbp,%rcx,8)
 11ba874:	ff 
 11ba875:	44 8d 49 03          	lea    0x3(%rcx),%r9d
 11ba879:	66 44 89 8c 4d d6 fd 	mov    %r9w,-0x22a(%rbp,%rcx,2)
 11ba880:	ff ff 

 11ba900:	44 8b 04 8f          	mov    (%rdi,%rcx,4),%r8d
 11ba904:	4c 89 84 cd d8 eb ff 	mov    %r8,-0x1428(%rbp,%rcx,8)
 11ba90b:	ff 
 11ba90c:	66 89 8c 4d d0 fd ff 	mov    %cx,-0x230(%rbp,%rcx,2)
 11ba913:	ff 
 11ba914:	48 ff c1             	inc    %rcx
 11ba917:	48 ff c8             	dec    %rax
 11ba91a:	75 e4                	jne    11ba900 <br.encoder.small_huffman.build__anon_35945+0x140>
