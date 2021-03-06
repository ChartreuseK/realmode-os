; A simple version of printf
; Arguments:
;   si - Format string
;   remaining arguments are pushed on stack
printf:
    push ax
    push dx
    push si
    push bp
    mov bp, sp

    mov di, 2 * 5      ; We pushed 4 arguments on the stack + return ptr
    
    
 .loop:
    lodsb               ; Read a byte from the format string
    cmp al, '%'         ; Is it the start of a format specifier?
    je .format
    cmp al, 92          ; Is it an escape sequence '\'
    je .escape
    cmp al, 0           ; Is it the end of the string?
    je .end
 .normal:
    call putch          ; Normal character print it
    jmp .loop
    
 .format:
    lodsb               ; Read the second part of the format specifier
    cmp al, '%'         ; Literal % sign
    je .normal
    cmp al, 'x'         ; Hex number
    je .hex
    cmp al, 'd'         ; Decimal number
    je .dec
    cmp al, 's'         ; String
    je .str 
    
    ; Unknown/Unimplemented - ignore it
    jmp .loop

 .hex:
    mov ax, WORD[ss:bp + di] ; Read in the number
    add di, 2           ; Move to the next
    call printHex
    jmp .loop
 .dec:
    mov ax, WORD[ss:bp + di] ; Read in the number
    add di, 2
    call printDec
    jmp .loop
 .str:
    push si             ; Save our format string
    mov si, WORD [ss:bp +di] ; Read in the argument from the stack
    add di, 2           ; Move to the next
    call printStr
    pop si              ; Go back to the format string
    jmp .loop
    
 .escape:
    lodsb               ; Load in escaped character
    cmp al, 'b'
    je  .backspace
    cmp al, 'r'
    je  .char_ret
    cmp al, 'n'
    je  .newline
    cmp al, 92
    je  .backslash
    cmp al, 't'
    je  .tab
    cmp al, 39
    je  .quote
    cmp al, '"'
    je  .dquote
    cmp al, 'a'
    je  .bell
    cmp al, 'f'
    je  .form
    cmp al, 'v'
    je  .vtab
    cmp al, '0'
    je  .null
    ; Non special escape
    call putch
    jmp .loop
  .backspace:
    mov al, 8
    call putch
    jmp .loop
  .char_ret:
    mov al, 13
    call putch
    jmp .loop
  .newline:
    mov al, 10
    call putch
    jmp .loop
  .backslash:
    mov al, 92
    call putch
    jmp .loop
  .tab:
    mov al, 9
    call putch
    jmp .loop
  .quote:
    mov al, 39
    call putch
    jmp .loop
  .dquote:
    mov al, '"'
    call putch
    jmp .loop
  .bell:
    mov al, 7
    call putch
    jmp .loop
  .form:
    mov al, 12
    call putch
    jmp .loop
  .vtab:
    mov al, 11
    call putch
    jmp .loop
  .null:
    ; End the format string here
    
 .end:
    pop bp
    pop si
    pop dx
    pop ax
    ret

; Writes a character to the screen
; Arguments:
;   al - Character to write
putch:
    push ax
    mov ah, 0x0e
    int 10h
    pop ax
    ret

; Print's a message at the current cursor position to the screen
; Arguments:
;     si - Address of string
printStr:
    push ax
    push si

.loop:
    lodsb                       ; Read character from string into AL
    or  al, al                  ; Set flags based on al
    jz  .done                   ; Finish on a null character
    cmp al, 92                  ; Escape sequence
    je  .escape
 .write:
    mov ah, 0x0e                ; BIOS - Write Character 
    int 10h                     ; 

    jmp .loop

 .escape:
    lodsb               ; Load in escaped character
    cmp al, 'b'
    je  .backspace
    cmp al, 'r'
    je  .char_ret
    cmp al, 'n'
    je  .newline
    cmp al, 92
    je  .backslash
    cmp al, 't'
    je  .tab
    cmp al, 39
    je  .quote
    cmp al, '"'
    je  .dquote
    cmp al, 'a'
    je  .bell
    cmp al, 'f'
    je  .form
    cmp al, 'v'
    je  .vtab
    cmp al, '0'
    je  .null
    ; Non special escape
    jmp .write
  .backspace:
    mov al, 8
    jmp .write
  .char_ret:
    mov al, 13
    jmp .write
  .newline:
    mov al, 10
    jmp .write
  .backslash:
    mov al, 92
    jmp .write
  .tab:
    mov al, 9
    jmp .write
  .quote:
    mov al, 39
    jmp .write
  .dquote:
    mov al, '"'
    jmp .write
  .bell:
    mov al, 7
    jmp .write
  .form:
    mov al, 12
    jmp .write
  .vtab:
    mov al, 11
    jmp .write
  .null:
    ; End the format string here

 .done:
    pop si
    pop ax
    ret

; Print a hex number
; Arguments:
;   ax - number
; TODO:
;   More optimal shift algoritm, shr ax, cl costs 8 + 4n !
printHex:
    push ax
    push bx
    push cx

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
    
    pop cx
    pop bx
    pop ax
    ret

; Prints a 32-bit number in hex
; Arguments:
;   ax - High part
;   bx - Low part
printHexLarge:
    push ax
    call printHex
    mov ax, bx
    call printHex
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

; Prints an unsigned decimal number
; Arguments:
;   ax - Number
printDec:
    push ax
    push bx
    push cx
    push dx

    xor dx, dx          ;
    push dx             ; Store a 0 so we know when we're done
    
 .loop:
    xor dx, dx          ; Clear the upper half for the divide
    mov cx, 10          ; Divide by 10
    div cx              ; Divide ax by cx, remainder in dx, div in ax
    
    add dx, '0'         ; Offset the character
    push dx             ; Put it on the stack
    
    test ax,ax          ; Check if we're done
    jnz .loop
    
 .ploop:
    pop ax
    test ax,ax          ; Check if we're done
    jz .done
    call putch          ; Print the digit
    jmp .ploop
 .done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret





; Print a cr/nl
printNewline:
    push ax
    mov ax, 0x0e0a
    int 10h
    mov ax, 0x0e0d
    int 10h
    pop ax
    ret
    
; Uses bios functions to get a character from the keyboard, blocking
; Return:
;    al - ASCII Character
;    ax - Scancode 
bios_getch:
    mov ah, 0                   ; Wait and Read Character
    int 16h                     ; Keyboard functions
    ret
    
    
; Gets a string from the user
; Arguments:
;    ax - Max length
;    es:di - Buffer 
; Returns:
;    ax - Bytes Read
gets:
    push di
    push bx
    
    push ax                     ; Save original max length (for bytes read
    mov bx, ax                  
 .loop:
    call bios_getch
    cmp al, 10                  ; Line feed
    je  .end
    cmp al, 13                  ; Character return
    je  .end
    cmp al, 8                   ; Backspace
    je  .bksp
    
    dec bx
    jz .full                    ; If bx is 0, and this wasn't a newline
                                ; Then ignore it
    call putch                  ; Otherwise echo the character
    stosb                       ; Then store into the string
    jmp .loop
    
 .full:
    inc bx                      ; Ignore the character we read
    jmp .loop
    
 .bksp:
    inc bx                      ; 
    dec di                      ; Go back in the string
    call putch                  ; Move the character back one
    mov al, 32                  ; Space
    call putch
    mov al, 8                   ; Backspace
    call putch
    
    jmp .loop                   ; And continue looping

 .end:
    mov al, 0                   ; End of string
    stosb                       ; Store at the end of the string
    pop ax                      ; Max length
    sub ax, bx                  ; Get number of characters read
    
    pop bx                      ; Restore registers
    pop di
    ret
