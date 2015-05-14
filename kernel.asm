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



msgEnter        db "Entered the Kernel!",10,13,0
