
format Binary as "bin"
org 0x7C00
	jmp start

align 4
label sector_per_track word at $$
label head_count byte at $$ + 2
label disk_id byte at $$ + 3

version dw 13
first_sector_fs dw 10
bits_map_pos db 6
name db "ARRIST"
guid db "4178D01A379746C2920706F4C743CF98"

virtual at 0x800
info:
	type db ?
	fname rb 255
	adr dw ?
end virtual


write_str:
	push ax si
	mov ah, 0x0E
 @@:
	lodsb
	test al, al
	jz @f
	int 0x10
	jmp @b
 @@:
	pop si ax
	ret


continue:

	xor dx, dx
	mov ax, 1
	mov di, 0x7E00
	call load_sector
	xor dx, dx
	mov ax, 2
	mov di, 0x8000
	call load_sector
	xor dx, dx
	mov ax, 3
	mov di, 0x8200
	call load_sector
	xor dx, dx
	mov ax, 4
	mov di, 0x8400
	call load_sector
	xor dx, dx
	mov ax, 5
	mov di, 0x8600
	call load_sector
	push cx bx ax
	xor bx, bx
	xor cl, cl
	inc cl
	.q:
		cmp bx, 11
		je .h
		call fill
		inc bx
		jmp .q
	.h:
	pop ax bx cx
	cmp byte [0x7c00 + 0x1fd], 0
	je .ttt
	jmp boot2
	.ttt:
	   jmp boot2

load_sector:
	cmp byte[sector_per_track], 0xFF
	je .EX
	push ax bx cx dx si di
	div [sector_per_track]
	mov cl, dl
	inc cl
	div [head_count]
	mov dh, ah
	mov ch, al
	mov dl, [disk_id]
	mov bx, di
	mov al, 1
	mov si, 3
 .qq:
	mov ah, 2
	int 0x13
	jnc .ww
	xor ah, ah
	int 0x13
	dec si
	jnz .qq
 .ww:
	pop di si dx cx bx ax
	ret
 .EX:
	push ax dx si
	mov byte[0x600], 0x10
	mov byte[0x601], 0
	mov word[0x602], 1
	mov [0x604], di
	push es
	pop word[0x606]
	mov [0x608], ax
	mov [0x60A], dx
	mov word[0x60C], 0
	mov word[0x60E], 0
	mov ah, 0x42
	mov dl, [disk_id]
	mov si, 0x600
	int 0x13
	pop si dx ax
	ret

start:

	jmp 0:@f
 @@:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, $$
	sti
	mov [disk_id], dl
	mov ah, 0x41
	mov bx, 0x55AA
	int 0x13
	jc .rr
	mov byte[sector_per_track], 0xFF
	jmp .tt
 .rr:
	mov ah, 0x08
	xor di, di
	push es
	int 0x13
	pop es
	inc dh
	mov [head_count], dh
	and cx, 111111b
	mov [sector_per_track], cx
 .tt:
	jmp continue

rb 510 - ($ - $$)
db 0x55,0xAA


cmd_find db "open", 32
cmd_delete db "delete", 32
cmd_create db "create", 32
cmd_edit db "edit", 32
cmd_reboot db "reboot", 32
cmd_rename db "rename", 32
cmd_list db "list", 32
cmd_succes db "F", 13, 10, 0
not_found_str db "not found", 13, 10, 0
buffer db 80 dup (32)
temp_b db 80 dup (0)
temp_word dw ?
temp_word2 dw ?
temp_second_name rb 80
temp_sectorfull db ?
temp_name rb 80
temp_length dw ?
temp_size dw ?
temp_byte db ?

temp_di dw ?
temp_dh db ?

char:
	mov ah, 0Eh
	int 10h
	ret

readln:
    xor cx, cx
    .read:
    xor ah, ah
    int 16h
    cmp al, 13
    je .enter
    cmp cx, 79
    je .read
    cmp al, 8
    je .back
    mov [di], al
    inc di
    inc cx
    call char
    jmp .read
    .enter:
	mov byte [di], 32
	inc di
	mov al, 10
	call char
	mov al, 13
	call char
	ret
    .back:
	mov al, 8
	call char
	xor al, al
	call char
	mov al, 8
	call char
	dec di
	mov byte [di], 32
	jmp .read

save_sector:
	cmp byte[sector_per_track], 0xFF
	je .ex
	pusha
	div [sector_per_track]
	mov cl, dl
	inc cl
	div [head_count]
	mov dh, ah
	mov ch, al
	mov dl, [disk_id]
	mov bx, di
	mov al, 1
	mov ah, 3
	int 0x13
	popa
	ret
.ex:
	push ax dx si
	mov byte[0x600], 0x10
	mov byte[0x601], 0
	mov word[0x602], 1
	mov [0x604], di
	push es
	pop word[0x606]
	mov [0x608], ax
	mov [0x60A], dx
	mov word[0x60C], 0
	mov word[0x60E], 0
	mov ah, 0x43
	mov dl, [disk_id]
	mov si, 0x600
	int 0x13
	pop si dx ax
	ret

reset:
	push si di
	mov si, di
	add si, 200h
	.we:
		cmp di, si
		je .ex
		mov byte [di], 0
		inc di
		jmp .we
	.ex:
	pop di si
	ret

saving:
	popa
	push ax
	xor ax, ax
	mov es, ax
	mov ds, ax
	pop ax
	call search_empty_sector
	mov cl, 1
	call fill
	push bx
	call search_empty_sector
	mov cl, 1
	call fill
	mov cx, bx
	mov [temp_word2], cx
	pop bx
	push si cx
	mov si, temp_name
	mov cx, [temp_length]
	.tempcycl:
		inc si
		dec cx
		jnz .tempcycl
	mov byte [si + 1], 0
	pop cx si
	mov di, temp_name
	mov al, 2
	call create_file

	pusha
	mov bx, 0b87dh
	mov es, bx
	mov di, 0
	.ty:
		cmp byte [es:di], 20h
		jne .exit
		dec di
		jmp .ty
	.exit:
	mov byte [es:di + 1], 0x0a
	popa

	pusha
	push ax
	mov bx, 0b800h
	mov es, bx
	mov di, 0
	mov cx, 508
	mov si, 0x5000
	mov byte [si], 1
	inc si
	.for:
		mov al, [es:di]
		mov [si], al
		cmp al, 0x0a
		je .stop
		inc si
		inc di
		inc di
		cmp al, 0xff
		je .enter
		.c:
		dec cx
		cmp cx, 0
		jg .for
	.savek:
	xor bx, bx
	mov es, bx
	mov di, 0x5000
	xor dx, dx
	mov ax, [temp_word2]
	call save_sector

	mov cx, 512
	mov di, 0x5000
	xor al, al
	.q:
		mov [di], al
		inc di
		dec cx
		jnz .q
	call clear
	popa
	jmp scan
	.enter:
		mov byte [si - 1], 0xff
		inc si
		mov byte [si - 1], 13
		inc si
		mov byte [si - 1], 10
		.ww:
			inc di
			inc di
			cmp byte [es:di], 20h
			jne .c
			jmp .ww

	.stop:
		mov byte [si], 0
		jmp .savek

editt:
	call clear
	jmp edit

edit:
	pusha

    .read:
    xor cx, cx
    xor ah, ah
    int 16h

    cmp al, 13
    je .enter
    cmp ah, 53h
    je .hhh
    cmp ah, 61
    je saving
    cmp ah, 1
    je saving
    cmp al, 0
    je .cursor
    pusha
    mov ah, 03h

    mov bh, 0
    int 10h

    mov cx, 2
    cmp dl, 0
    jne .lk
    mov cx, 1
    .lk:

    cmp al, 8
    je .back
    xor cx, cx

    push ax
	mov bx, 0b800h
	mov es, bx
	mov di, 0
	mov cx, 0
	mov ah, 03h
	mov bh, 0
	int 10h
	push ax dx
	mov al, 80
	mul dh
	mov cx, ax
	mov ax, 2
	mul cx
	add di, ax
	pop dx ax
	push ax dx
	mov al, 2
	mul dl
	add di, ax
	pop dx ax
	mov [temp_di], di
	.qq:
		cmp byte [es:di], 0xff
		je .sd
		add di, 2
		jmp .qq
	.sd:
		mov byte [es:di + 2], 0xff
		inc di
		inc di
		.rt:
		dec di
		dec di
		mov al, [es:di]
		mov [es:di + 2], al
		cmp di, [temp_di]
		jne .rt
    pop ax
    call char
    popa
    jmp .read
    .enter:
	push ax bx cx

	mov ah, 03h
	mov bh, 0
	int 10h
	push dx
	push dx
	push dx

	mov cl, 0
	mov ch, dh
	inc ch
	mov dl, 80
	mov dh, 25
	mov al, 1
	mov bh, 0x7
	mov ah, 07h
	int 10h

	pop dx
	mov ah, 02h
	mov bh, 0
	int 10h

	mov ah, 03h
	mov bh, 0
	int 10h

	mov cl, dl
	mov ch, dh
	mov dl, 80
	inc dh
	mov al, 1
	mov bh, 0x7
	mov ah, 07h
	int 10h

	pop dx
	mov ah, 02h
	mov bh, 0
	int 10h

	mov ah, 09h
	mov al, 0xff
	mov bl, 7h
	mov bh, 0h
	mov cx, 1
	int 10h

	mov al, 13
	call char
	mov al, 10
	call char
	pop dx
		.www:
			cmp dl, 0
			je .ret
			dec dl
			mov cx, 10
			jmp .back
			.return:
			jmp .www
		 .ret:
	pop cx bx ax
	jmp .read
    .back:
	cmp cx, 1
	je .end
	push cx dx bx ax
	mov al, 8
	call char
	mov al, 32
	call char
	mov al, 8
	call char

	push ax
	mov bx, 0b800h
	mov es, bx
	mov di, 0
	mov cx, 0
	mov ah, 03h
	mov bh, 0
	int 10h
	push ax dx
	mov al, 80
	mul dh
	mov cx, ax
	mov ax, 2
	mul cx
	add di, ax
	pop dx ax
	push ax dx
	mov al, 2
	mul dl
	add di, ax
	pop dx ax
	push di
	.qqq:
		cmp byte [es:di], 0xff
		je .rtq
		add di, 2
		jmp .qqq

		.rtq:
		mov [temp_di], di
		pop di
		.u:
			inc di
			inc di
			mov al, [es:di]
			mov [es:di - 2], al
			cmp di, [temp_di]
			jne .u

	pop ax
	pop ax bx dx cx
	cmp cx, 10
	je .return
	cmp cx, 112
	je .io
	.end:
	jmp .read

    .cursor:
	cmp ah, 75
	je .left
	cmp ah, 77
	je .right
	cmp ah, 72
	je .up
	cmp ah, 80
	je .down
	jmp .read

    .left:
	mov ah, 03h
	mov bh, 0
	int 10h
	cmp dl, 0
	je .leftend
	dec dl
	mov ah, 02h
	int 10h
	jmp .read
	.leftend:
	dec dh
	mov dl, 79
	mov ah, 02h
	int 10h
	jmp .read

     .right:
	mov ah, 03h
	mov bh, 0
	int 10h
	cmp dl, 79
	je .rightend
	inc dl
	mov ah, 02h
	int 10h
	jmp .read
	.rightend:
	inc dh
	xor dl, dl
	mov ah, 02h
	int 10h
	jmp .read

     .up:
	mov ah, 03h
	mov bh, 0
	int 10h
	cmp dh, 0
	je .upend
	dec dh
	mov ah, 02h
	int 10h
	.upend:
	jmp .read

     .down:
	mov ah, 03h
	mov bh, 0
	int 10h
	cmp dh, 25
	je .downend
	inc dh
	mov ah, 02h
	int 10h
	.downend:
	jmp .read

      .hhh:
	push cx
	mov ah, 03h
	mov bh, 0
	int 10h
	inc dl
	mov ah, 02h
	int 10h
	mov cx, 112
	jmp .back
	.io:
	pop cx
	jmp .read

	popa
	jmp scan

clear:
	mov ax, 2h
	int 10h
	ret

create:
	call search_empty_sector
	mov cl, 1
	call fill
	push bx
	call search_empty_sector
	mov cl, 1
	call fill
	mov cx, bx
	pop bx
	pusha
	mov si, temp_name
	.b:
		cmp byte [di], 32
		je .c
		mov al, byte [di]
		mov [si], al
		inc si
		inc di
		jmp .b
	.c:
	mov byte [si], 0
	popa
	mov di, temp_name
	mov al, 2
	call create_file
	jmp scan


list:
	pusha
	mov ax, [first_sector_fs]
	.q:
	xor dx, dx
	mov di, info
	call load_sector
	cmp byte [di], 3
	je .exit
	cmp byte [di], 2
	jne .r
	    cmp byte [di + 1], 0
	    je .r
	    push ax
	    mov si, di
	    inc si
	    call write_str
	    mov al, 0x0d
	    call char
	    mov al, 0x0a
	    call char
	    pop ax
	.r:
	inc ax
	jmp .q
	.exit:
		cmp byte [di + 1], 0
		je .hardexit		; добавить сообщение - "Файлов пока нет, но вы можете создать их"
		mov si, di
		inc si
		call write_str
		mov al, 0x0d
		call char
		mov al, 0x0a
		call char
	.hardexit:
	popa
	jmp scan

fill_sector:			;параметры: ax - номер сектора, cl - заполнитель
	pusha
	xor dx, dx
	mov di, 0x2000
	call load_sector
	mov bx, 512
	mov di, 0x2000
	.q:
		mov byte [di], cl
		inc di
		dec bx
		jnz .q
	xor dx, dx
	mov di, 0x2000
	call save_sector
	popa
	ret

fill:
	pusha	      ;параметры: bx - номер сектора для заполнения, cl - заполнитель
	mov al, [bits_map_pos]
	xor ah, ah
	xor dx, dx
	mov di, 0x600
	call load_sector
	mov [0x610 + bx], cl
	mov al, [bits_map_pos]
	xor ah, ah
	xor dx, dx
	mov di, 0x600
	call save_sector
	popa
	ret



search_empty_sector:
	push ax dx cx si di
	mov al, [bits_map_pos]
	xor ah, ah
	xor dx, dx
	xor bx, bx
	mov di, 0x600
	call load_sector
	mov di, 0x610
	.q:
		cmp byte [di], 0
		je .f
		inc di
		inc bx
		jmp .q
	.f:
	pop di si cx dx ax
	ret

delete:
	pusha
	xor ax, ax
	mov [temp_length], ax
	mov si, temp_name
	.b:
		cmp byte [di], 32
		je .c
		mov al, byte [di]
		mov [si], al
		inc si
		inc di
		inc [temp_length]
		jmp .b
	.c:
	mov byte [si], 0
	call delete_file
	popa
	jmp scan

delete_file:	    ;параметры: temp_name - указатель на имя файла, оканчивающееся нуль - байтом (не больше 254 байт), temp_length - длина имени файла
	pusha

	mov ax, [first_sector_fs]
	.q:
		xor dx, dx
		mov di, info
		call load_sector
		mov di, info
		cmp byte [di], 2
		je .ww
		cmp byte [di], 3
		je .jj
		jmp .t
		.ww:
		mov si, temp_name
		mov cx, [temp_length]
		push si
		.k:
			cmp cx, 0
			je .j
			inc si
			dec cx
			jnz .k
		.j:
		mov byte [si], 0
		pop si
		inc di
		mov cx, [temp_length]
		inc cx
		repe cmpsb
		je .founded
		.t:
			inc ax
			jmp .q
		.jj:
			mov si, temp_name
			mov cx, [temp_length]
			push si
			.kk:
				cmp cx, 0
				je .ll
				inc si
				dec cx
				jnz .kk
				.ll:
				mov byte [si], 0
				pop si
				inc di
				mov cx, [temp_length]
				inc cx
				repe cmpsb
				je .founded
			mov si, not_found_str
			call write_str
			pop bx ax si
			jmp scan
		inc ax
		jmp .q
	.founded:
		push ax dx di
		cmp byte [info], 3
		jne .cycl
		dec ax
		.p:
			xor dx, dx
			mov di, 0x3000	   ; для больших файлов - увеличить
			call load_sector
			cmp byte [0x3000], 2
			je .hh
			dec ax
			mov bx, [first_sector_fs]
			dec bx
			cmp ax, bx
			je .cycl
			jmp .p
			.hh:
				mov byte [0x3000], 3
				xor dx, dx
				call save_sector
		.cycl:
		pop di dx ax
		mov bx, ax
		xor cl, cl
		call fill
		call fill_sector
		mov ax, [info + 100h]
		mov di, 0x1000
		.d:
			xor dx, dx
			call load_sector
			mov dx, [di + 1feh]
			cmp dx, 0
			je .h
			push bx cx di
			mov bx, ax
			xor cl, cl
			call fill
			call fill_sector
			pop di cx bx
			mov ax, dx
			add di, 200h
			jmp .d
		.h:
			push bx cx ax
			mov bx, ax
			xor cl, cl
			call fill
			call fill_sector
			pop ax cx bx
	.exit:
	popa
	ret

create_file:	    ;параметры: di - указатель на имя файла, оканчивающееся нуль - байтом (не больше 254 байт), al - тип файла,
		    ;		bx - номер сектора заголовка, cx - номер первого сектора данных.
	pusha
	push ax di
	xor ax, ax
	mov es, ax
	mov ds, ax
	mov di, 0x800
	call reset
	pop di ax
	mov si, 0x800
	mov [si], al ; записываем тип файла
	inc si
	.b:			     ; записываем имя файла
		cmp byte [di], 0
		je .e
		mov al, [di]
		mov [si], al
		inc si
		inc di
		jmp .b
	.e:

	mov byte [si], 0
	mov si, 0x900		; записываем адрес данных файла
	mov word [si], cx
	xor dx, dx
	mov ax, bx
	mov di, 0x800
	mov [temp_word], ax
	call save_sector
	mov ax, cx
	push di
	mov di, 0x800
	call reset
	pop di
	call load_sector
	mov byte [di], 1
	call save_sector


	mov ax, [temp_word]
	xor dx, dx
	mov di, info
	call reset
	call load_sector
	mov byte [info], 3
	call save_sector
	dec ax
	.qwe:
		mov di, info
		call reset
		call load_sector
		cmp byte [di], 3
		je .swap
		dec ax
		cmp ax, [first_sector_fs]
		jnb .qwe
      ;  mov ax, [temp_word]
      ;  xor dx, dx
      ;  mov di, info
      ;  call reset
      ;  call load_sector
      ;  mov byte [info], 2
      ;  call save_sector

	mov ax, [temp_word]
	inc ax
	xor dx, dx
	mov cx, 496
	mov di, info
	call reset
	.loop:
		call load_sector
		cmp byte [info], 3
		je .find
		inc ax
		dec cx
		jnz .loop
	jmp .exit
	.find:
		mov ax, [temp_word]
		mov di, info
		call reset
		call load_sector
		mov byte [info], 2
		call save_sector
	jmp .exit
	.swap:
		mov byte [di], 2
		call save_sector
	.exit:
		popa
		ret

rename:
	push si ax bx dx
	xor ax, ax
	mov [temp_length], ax
	mov si, temp_name
	.b:
		cmp byte [di], 32
		je .c
		mov al, byte [di]
		mov [si], al
		inc si
		inc di
		inc [temp_length]
		jmp .b
	.c:

	mov si, temp_second_name
	inc di
	.b1:
		cmp byte [di], 32
		je .e
		mov al, byte [di]
		mov [si], al
		inc si
		inc di
		jmp .b1
	.e:
		mov byte [si], 32

	mov ax, [first_sector_fs]
	.q:
		xor dx, dx
		mov di, info
		call load_sector
		mov di, info
		cmp byte [di], 2
		je .ww
		cmp byte [di], 3
		je .jj
		jmp .t
		.ww:
		mov si, temp_name
		mov cx, [temp_length]
		push si
		.k:
			cmp cx, 0
			je .j
			inc si
			dec cx
			jnz .k
		.j:
		mov byte [si], 0
		pop si
		inc di
		mov cx, [temp_length]
		inc cx
		repe cmpsb
		je .founded
		.t:
			inc ax
			jmp .q
		.jj:
			mov si, temp_name
			mov cx, [temp_length]
			push si
			.kk:
				cmp cx, 0
				je .ll
				inc si
				dec cx
				jnz .kk
				.ll:
				mov byte [si], 0
				pop si
				inc di
				mov cx, [temp_length]
				inc cx
				repe cmpsb
				je .founded
			mov si, not_found_str
			call write_str
			pop bx ax si
			jmp scan
	.founded:
			mov cx, [temp_length]
			mov di, info
			inc di

			.rrr:
				mov byte [di], 0
				inc di
				dec cx
				jnz .rrr
			mov di, info
			mov si, temp_second_name
			dec si
			push ax
			.www:
				inc si
				inc di
				cmp byte [si], 32
				je .ttt
				mov al, [si]
				mov [di], al
				jmp .www
			.ttt:
			mov byte [di], 0
			pop ax
			mov di, info
			xor dx, dx
			call save_sector
			pop bx ax si
			jmp scan

reboot:
	jmp 0xFFFF:0

open:
	push si ax bx
	call clear
	xor ax, ax
	mov [temp_length], ax
	mov si, temp_name
	.b:
	       cmp byte [di], 32
	       je .e
	       mov al, byte [di]
	       mov byte [si], al
	       inc si
	       inc di
	       inc [temp_length]
	       jmp .b
	.e:
	mov ax, [first_sector_fs]
	.q:
		xor dx, dx
		mov di, info
		call load_sector
		mov di, info
		cmp byte [di], 2
		je .ww
		cmp byte [di], 3
		je .jj
		jmp .t
		.ww:
		mov si, temp_name
		mov cx, [temp_length]
		push si
		.k:
			cmp cx, 0
			je .j
			inc si
			dec cx
			jnz .k
		.j:
		mov byte [si], 0
		pop si
		inc di
		mov cx, [temp_length]
		inc cx
		repe cmpsb
		je .founded
		.t:
			inc ax
			jmp .q
		.jj:
			mov si, temp_name
			mov cx, [temp_length]
			push si
			.kk:
				cmp cx, 0
				je .ll
				inc si
				dec cx
				jnz .kk
				.ll:
				mov byte [si], 0
				pop si
				inc di
				mov cx, [temp_length]
				inc cx
				repe cmpsb
				je .founded
			mov si, not_found_str
			call write_str
			pop bx ax si
			jmp scan
	.founded:

		xor dx, dx
		mov ax, [info + 100h]
		mov di, 0x1000
		.d:
		xor dx, dx
		call load_sector
		mov dx, [di + 1feh]
		cmp dx, 0
		je .h
		mov word [di + 1feh], 0
		mov si, di
		inc si
		call write_str
		mov ax, dx
		add di, 200h
		jmp .d
		.h:
		mov si, di
		inc si
		call write_str
		mov ah, 02h
		xor bh, bh
		xor dx, dx
		int 10h
		pop bx ax si
		call delete_file
		jmp edit
	.exit:
	mov si, not_found_str
	call write_str
	pop bx ax si
	jmp scan


boot2:
	mov ax, 2h
	int 10h
scan:

	mov di, buffer
	call readln
	mov di, buffer
	mov cx, 5
	mov si, cmd_find
	repe cmpsb
	jz open
	mov di, buffer
	mov cx, 7
	mov si, cmd_rename
	repe cmpsb
	jz rename
	mov di, buffer
	mov cx, 7
	mov si, cmd_create
	repe cmpsb
	jz create
	mov di, buffer
	mov cx, 7
	mov si, cmd_delete
	repe cmpsb
	jz delete
	mov di, buffer
	mov cx, 5
	mov si, cmd_list
	repe cmpsb
	jz list
	mov di, buffer
	mov cx, 5
	mov si, cmd_edit
	repe cmpsb
	jz editt
	mov di, buffer
	mov cx, 7
	mov si, cmd_reboot
	repe cmpsb
	jz reboot
	jmp scan


