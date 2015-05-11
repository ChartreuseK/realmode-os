; Stage 2 Loader
; 
;  This stage act's much the same as the floppy loader, but provides better
;  error handling and is boot drive independent.
;
;
;
;
;
;
;
;
;
[bits 16]
[org   0]


start:
	mov ax, cs				; Get our current segment
	mov ds, ax				; Set our data segment to the current
	mov es, ax				; 
	
	mov si, msgEnter
	call printStr

	mov si, msgFar
	call printStr


haltLoop:
	jmp haltLoop





; Print's a message at the current cursor position to the screen
; Arguments:
;     si - Address of string
printStr:
    pusha                       ; Save all GP registers
    mov bp, sp                  ; Save the old stack pointer

.loop:
    lodsb                       ; Read character from string into AL
    or  al, al                  ; Set flags based on al
    jz  .done                   ; Finish on a null character

    mov ah, 0x0e                ; BIOS - Write Character 
    int 10h                     ; 

    jmp .loop

 .done:
    mov sp, bp                  ; Restore stack pointer
    popa                        ; Restore GP registers
    ret

; Print a hex number recursively
; Arguments:
;   ax - number
printNum:
	pusha
	cmp ax, 0xF
	jbe .digit
	
	mov bx, ax
	and bx, 0xF
	shr ax, 4					; Next digit
	call printNum				; Recurse
	
	mov ax, bx
	cmp ax, 0x9
	jle .digit
	add ax, 17					; 'A'-'0'
 .digit:
	add ax, 48					; '0'
	mov ah, 0x0e
	int 10h
	popa
	ret

; Print a cr/nl
newline:
	pusha
	mov ax, 0x0e0a
	int 10h
	mov ax, 0x0e0d
	int 10h
	popa
	ret
	
	

msgEnter       db "Entered Stage Two!",10,13,0

times 512 db 0

msgFar		   db "Jumped to second sector!",10,13,0



	

