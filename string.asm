; string.asm
;    String handling functions
;
;
;
;
;






; Compares the two strings in di and si
; Arguments:
;     ds:si - String 1
;     es:di - String 2
; Return:
;     ax - 0 if equal, <0 if str1<str2, >0 if str1>str2
strcmp:
    push di
    push si
    push cx
    
    call strlen             ; Get length of string 2 (max length to check)
    mov cx, ax
    
    
    ; Compare the strings
    cld                     ; Make sure we're incrementing
    repe cmpsb              ; Find the first non matching byte 
                            ; (up to cx into string)
    
    mov al, BYTE [ds:si - 1]; Read in last byte read from str 1
    mov cl, BYTE [es:di - 1]; Last byte read from str 2
    sub al, cl              ; Get the difference (if strings were equal
                            ; Then this is 0, otherwise it gives the 
                            ; comparison of the first mismatched char
    
    pop cx
    pop si
    pop di
    ret
    

; Finds the length of a null terminated string
; Arguments:
;   es:di - String 
; Return:
;    ax - Length
strlen:
    push cx
    push di
    
    xor ax, ax              ; We want to go till we hit NULL terminator
    xor cx, cx
    not cx                  ; Maximum string length of 65536
    
    cld                     ; Make sure we're incrementing
    repne scasb             ; Go through the string till we find the null
    
    dec ax                  ; 65536 (Starting value in cx)
    sub ax, cx              ; Get the number of bytes we read
    dec ax                  ; -1 for the null

    pop di
    pop cx
    ret

