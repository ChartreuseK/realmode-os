; interrupt.asm
;  - Provides handlers, an IVT, and means of installing them
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
%endmacro

%macro leaveISR 0
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
;     ax - Interrupt Number
;     bl - Handler Offset
;     bh - Handler Segment
installISR:
    push ax
    shl ax, 1
    shl ax, 1           ; Offset into the IVT is interrupt * 4
    mov WORD [ax], bx   ; Store the offset and segment into the IVT        
    pop ax
    ret


isrUnhandled:
    enterISR

    leaveISR

isrIR0:         ; PIT
    enterISR

    leaveISR

isrIR1:         ; Keyboard
    enterISR

    leaveISR

isrIR2:         ; (Second PIC if AT or newer, otherwise available/Tandy HD)
    enterISR

    leaveISR

isrIR3:         ; COM2 (or COM4)
    enterISR

    leaveISR

isrIR4:         ; COM1 (or COM3)
    enterISR

    leaveISR

isrIR5:         ; LPT2 or Hard Disk Controller 
    enterISR

    leaveISR

isrIR6:         ; Floppy Disk Controller
    enterISR

    leaveISR

isrIR7:         ; LPT1
    enterISR

    leaveISR

defaultTable:
    dw isrUnhandled, KERNEL_SEG
    dw isrUnhandled, KERNEL_SEG
    dw isrUnhandled, KERNEL_SEG
    dw isrUnhandled, KERNEL_SEG
    dw isrUnhandled, KERNEL_SEG
    dw isrUnhandled, KERNEL_SEG
    dw isrUnhandled, KERNEL_SEG
    dw isrUnhandled, KERNEL_SEG
    dw isrIRQ0, KERNEL_SEG
    dw isrIRQ1, KERNEL_SEG
    dw isrIRQ2, KERNEL_SEG
    dw isrIRQ3, KERNEL_SEG
    dw isrIRQ4, KERNEL_SEG
    dw isrIRQ5, KERNEL_SEG
    dw isrIRQ6, KERNEL_SEG
    dw isrIRQ7, KERNEL_SEG

