;
;
;
;

[BITS 16]
[ORG 0]

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    
    mov si, msgEnter
    call printStr
    
    
    mov si, msgMemory1
    call printStr
    
    xor ax, ax
    int 12h             ; Request amount of low memory (in ax kB)
    
    call printNum
    mov si, msgMemory2
    call printStr

haltLoop:
    hlt
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

; Print a hex number
; Arguments:
;   ax - number
printNum:
    pusha
    mov cl, 12                  ; Left most digit
    mov bx, ax                  ; Save our number

 .next:
    shr ax, cl                  ; Shift right to the current digit
    and al, 0xF                 ; Mask the current digit
    cmp al, 0x9                 ; Check if we're a number or letter
    jle .digit
    add al, 7                   ; Offset for A-F
 .digit:
    add al, '0'                 ; '0'
    mov ah, 0x0e                ; Write character
    int 10h                 
    
    mov ax, bx                  ; Restore our original number
    sub cl, 4                   ; Shift to the next digit
    jge .next
    
    popa
    ret

; Prints a 32-bit number in hex
; Arguments:
;   ax - High part
;   bx - Low part
printNumLarge:
    push ax
    call printNum
    mov ax, bx
    call printNum
    pop ax
    ret

; Prints 0x
printHexPrefix:
    push ax
    mov ah, 0x0e
    mov al, '0'
    int 10h
    
    mov ah, 0x0e
    mov al, 'x'
    int 10h
    pop ax
    ret


; Print a cr/nl
printNewline:
    pusha
    mov ax, 0x0e0a
    int 10h
    mov ax, 0x0e0d
    int 10h
    popa
    ret

    
; Restarts the computer after waiting for a keypress
;
restart:
    mov si, msgRestart
    call printStr

    mov ah, 0                 
    int 16h                     ; Wait for a keypress
    int 19h                     ; Reboot

msgEnter        db "Entered the Kernel!",10,13,0
msgRestart      db "Press any key to restart the computer...",0
msgMemory1      db "Found 0x",0
msgMemory2      db "kB of free low memory.",10,13,0
