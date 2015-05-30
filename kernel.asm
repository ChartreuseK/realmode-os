; kernel.asm
;
;
;

[BITS 16]
[ORG 0]
[CPU 8086]  ; Attempt to stop me from using 286 instructions

%define KERNEL_SEG 0x1000

start:
    mov ax, cs
    mov ds, ax
    
    push es             ; Save the pointer to boot info
    push di             ; Till we need it
    
    mov es, ax
    
    mov si, msgEnter
    call printStr
    
    xor ax, ax
    int 12h             ; Request amount of low memory (kB in ax)
    push ax
    mov si, msgMemory
    call printf
    add sp, 1 * 2       ; Pop off the argument

    mov ax, 0
    mov es, ax
    
    mov di, 0x040E
    mov ax, WORD [es:di]    ; EBDA base address >> 4
    
    push ax
    mov si, msgEBDA
    call printf
    add sp, 1 * 2
 
    
    ; We'll be using cdecl for our functions from now on
    ; ax, cx, dx can be overwritten by the function
    ; Arguments are on the stack, caller sets up bp before pushing
    push bp 
    mov bp, sp              ; Create a call frame
    sub sp, 3 * 2           ; Make room for the arguments
    
    mov WORD [bp - 1 * 2], 0x1c  ; Install PIT interrupt (after bios)
    mov WORD [bp - 2 * 2], isrTimer   
    mov WORD [bp - 3 * 2], KERNEL_SEG
    call installISR
    
    add sp, 3 * 2
    pop bp
    
 
cmdLoop:
    mov si, msgPrompt
    call printf

    mov di, buff
    mov ax, 256         ; Max length
    call gets
    call printNewline
    
    
    mov si, cmdHello
    call strcmp
    test al, al
    je hello
    
    
    mov si, cmdTick
    call strcmp 
    test al, al
    je ctick
    
        
    jmp cmdLoop

hello:
    mov si, msgHello
    call printf
    jmp cmdLoop
    
ctick:
    mov si, msgTick
    mov ax, [tick]
    push ax
    call printf
    add sp, 1 * 2
    jmp cmdLoop
    
dir:
    


haltLoop:
    hlt
    jmp haltLoop



   
; Restarts the computer after waiting for a keypress
;
restart:
    mov si, msgRestart
    call printStr

    mov ah, 0                 
    int 16h                     ; Wait for a keypress
    int 19h                     ; Reboot


%include "string.asm"
%include "bios_stdio.asm"
%include "interrupt.asm"


msgEnter        db "Entered the Kernel!",10,13,0
msgRestart      db "Press any key to restart the computer...",0
msgMemory       db "Found %dkB low memory installed\r\n",0
msgPrompt       db "> ",0
msgStrDebug     db "strcmp result: %d, input strlen: %d\r\n",0
msgHello        db "Hello world!\r\n",0
msgEBDA         db "EBDA base address 0x%x0\r\n",0
msgTick         db "Current Tick: %d\r\n",0

cmdHello        db "hello",0
cmdTick         db "tick",0


tick dw 0

buff times 256 db 0
