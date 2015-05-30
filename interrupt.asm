; interrupt.asm
;  - Provides handlers and means of installing them
;
;
[BITS 16]
[CPU 8086]
 
%macro enterISR 0
    push ax
    push bx
    push cx
    push dx
    push sp
    push bp
    push si
    push di
    push ds
    push es
%endmacro

%macro leaveISR 0
    pop es
    pop ds
    pop di
    pop si
    pop bp
    pop sp
    pop dx
    pop cx
    pop bx
    pop ax
    
    iret
%endmacro

; installISR - Installs the specified handler to the given interrupt
; Arguments:
;     1 - Interrupt Number
;     2 - Handler Offset
;     3 - Handler Segment
installISR:
    push di
    push es
    
    cli                  ; We don't want any interrupts messing up this
    
    xor ax, ax
    mov es, ax           ; IVT is located at 0000:0000 to 0000:00400
    
    
    mov di, [bp - 1 * 2] ; Get first arg (interrupt number)
    shl di, 1
    shl di, 1            ; Multiply by 4 to get offset in IVT
    
    mov ax, [bp - 2 * 2] ; Get Handler offset
    mov [es:di + 0], ax  ; Store the offset
    mov ax, [bp - 3 * 2] ; Get the handler segment
    mov [es:di + 2] ,ax  ; Store the segment
    
    sti                  ; Re-enable interrupts
    
    pop es
    pop di
    
    ret


isrUnhandled:
    enterISR

    leaveISR

isrTimer:         ; PIT
    enterISR

    mov ax, KERNEL_SEG
    mov ds, ax
    
    mov ax, [tick]
    inc ax
    mov [tick], ax
    
    leaveISR
