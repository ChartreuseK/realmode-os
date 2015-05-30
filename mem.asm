; mem.asm
;   Memory manipulation functions
;
;
;
;



; Memcpy - Copys CX bytes from DS:SI to ES:DI
; Arguments:
;   ds:si - Source
;   es:di - Destination
;   cx - Number of bytes
memcpy:
    push di
    push si
    push cx
    rep movsb
    pop cx
    pop si
    pop di
    ret

; Memset - Sets CX bytes of ES:DI to AL
; Arguments:
;   es:di - Destination
;   al - Byte to set
;   cx - Number of bytes
memset:
    push di
    push si
    push cx
    rep stosb
    pop cx
    pop si
    pop di
    ret
