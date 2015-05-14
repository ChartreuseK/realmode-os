; Stage 2 Loader
; 
;  This stage act's much the same as the floppy loader, but provides better
;  error handling.
;
;
;  TODO: 
;      -   Boot drive independent (stage 1 loader passes needed info)
;           - Sectors per track, num heads, boot drive
;
;
;
;
;
;
[bits 16]
[org   0]

%define KERNEL_SEGMENT 0x1000
%define KERNEL_OFFSET  0x0000

%define SCRATCH_SEGMENT 0x7c0   ; We'll use the space occupied by stage 1 as scratch

%define SECTORS_PER_TRACK   18
%define NUM_HEADS           2
%define FAT_SECTOR          RESERVED_SECTORS
%define ROOT_DIR_SECTOR     ( FAT_SECTOR + (SECTORS_PER_FAT * NUM_FATS) )
%define RESERVED_SECTORS    1
%define SECTORS_PER_FAT     9
%define NUM_FATS            2
%define DIRECTORY_ENTRIES   224
%define BYTES_PER_ENTRY     32
%define SECTORS_PER_CLUSTER 1
%define FILENAME_LENGTH     11
%define ROOT_DIR_SECTORS    ( (DIRECTORY_ENTRIES * BYTES_PER_ENTRY) / 512 )
%define BYTES_PER_SECTOR    512

start:
    mov ax, cs              ; Get our current segment
    mov ds, ax              ; Set our data segment to the current
    mov es, ax              ; 
    
    mov [bootDrive], bl     ; Save the boot drive that was passed to us
    
    mov si, msgEnter
    call printStr

    call findKernel
    
    mov WORD [startingCluster], ax  ; Save the starting cluster 
    call loadKernel
    
    ; Now that the kernel is loaded, all that is left to do is go to it!
    jmp KERNEL_SEGMENT:KERNEL_OFFSET

haltLoop:
    jmp haltLoop




loadKernel:
    push es
    call loadFat
    
    mov si, msgReading          ; Say that we're reading in the kernel
    call printStr
    
    mov ax, KERNEL_SEGMENT      ; We'll be loading to here
    mov es, ax
    
    mov ax, WORD [startingCluster]
    xor bx, bx                  ; Initial offset

 .next:
    push ax                     ; Save current cluster
    call clustToLBA
    mov cl, SECTORS_PER_CLUSTER ; Read in the cluster
    call readFloppy
    call printRead              ; Show that we read the cluster in
    pop ax                      ; Get the last cluster read
    
    call nextCluster            ; Get the next cluster in the chain
    
    cmp ax, 0xFF0               ; Check if this is the end of the chain 
    jge .done
    
    add bx, SECTORS_PER_CLUSTER * BYTES_PER_SECTOR
    jno .next                   ; If we didn't overflow the offset cont.
    ; We overflowed the segment
    mov cx, ax                  ; Save ax for a second
    mov ax, es
    add ax, 0x1000              ; Move to the next segment
    mov es, ax
    mov ax, cx                  ; Restore ax
    jmp .next                   ; Then continue on
 .done:
    mov si, msgKernelRead
    call printStr
    pop es
    ret

; Print that we read cluster ax into KERNEL_SEGMENT:bx
; Arguments:
;   ax - block number
;   bx - offset loaded at
;   es - segment loaded at
printRead:
    pusha
    mov si, msgReadBlock1       ; Start of message
    call printStr
    call printHexPrefix         ; 0x
    call printNum               ; Print the block number (hex)
    mov si, msgReadBlock2       ; Middle of message
    call printStr
    
    mov ax, es                  ; Print the segment
    call printNum
    
    mov al, ':'                 ; Print a colon seperator
    mov ah, 0x0e
    int 10h
    
    mov ax, bx                  ; Finally print the offset
    call printNum
    call printNewline           ; And end the line
    popa
    ret

; Get the next cluster from the FAT
; Arugments:
;     ax - Current Cluster Number
; Return:
;     ax - Next Cluster Number (if >= ff8 then there is no next cluster)
nextCluster:
    push bx                     ; Save the register's we're changing
    push cx
    push dx
    push es
    
    ; Since each cluster entry is 12 bytes we need to multiply by 1.5
    mov bx, ax                  ; Make a copy
    shr bx, 1                   ; Divide by 2
    add bx, ax                  ; Now we have cluster * 1.5

    mov cx, ax                  ; Save the original cluster number
    mov ax, SCRATCH_SEGMENT     
    mov es, ax                  ; We're reading from the fat segment
    mov dx, WORD [es:bx]        ; Read in 2 bytes from the fat

    test cx, 1                  ; Check if the cluster number is even
    jnz  .odd
 .even:
    and dx, 0x0FFF              ; Mask off the upper 4 bits
    jmp .found
 .odd:
    shr dx, 4                   ; Shift down to keep only the upper 12 bits
 .found:
    mov ax, dx                  ; Our return value
    pop es
    pop dx
    pop cx
    pop bx                      ; Restore the register's
    ret                         ; Return

    
; Convert a cluster to logical block
clustToLBA:
    push cx                     ; Save cx
    sub ax, 2                   ; Subtract 2 to zero the cluster number
    mov cx, SECTORS_PER_CLUSTER 
    mul cx                      ; Multiply ax by cx into ax
    add ax, ROOT_DIR_SECTOR + ROOT_DIR_SECTORS
    pop cx
    ret
    
    
; Reads in the FAT into the scratch space
loadFat:
    mov ax, SCRATCH_SEGMENT
    mov es, ax                  ; Segment to load at
    mov ax, FAT_SECTOR          ; Start sector
    xor bx, bx                  ; Offset to load at
    mov cl, SECTORS_PER_FAT     ; Sectors to load
    call readFloppy
    
    ret

; Searches through the root directory for the kernel
; Returns:
;   ax - Starting cluster
findKernel:
    ; Read in the directory entry
    mov ax, SCRATCH_SEGMENT
    mov es, ax                  ; Segment to load at
    xor bx, bx                  ; Offset to load at
    mov ax, ROOT_DIR_SECTOR     ; Start sector
    mov cl, ROOT_DIR_SECTORS    ; Sectors to load
    call readFloppy
    
    ; Look through the directory entries for Stage  BIN
    mov si, kernelFileName       ; First operand offset (segment in ds)
    mov di, 0                   ; Start at the first entry
    mov cx, FILENAME_LENGTH      
    mov al, DIRECTORY_ENTRIES

 .cmpEntry:
    push di                     ; Save the start of the current
    repe cmpsb                  ; Compare the strings
    je .foundKernel    


 .nextEntry:
    pop di                      ; Restore DI
    add di, BYTES_PER_ENTRY     ; Move to the next entry

    mov si, kernelFileName
    mov cx, FILENAME_LENGTH
    dec al

    jnz .cmpEntry
    
    ; Could not find the kernel
    mov si, msgNoKernel
    call printStr
    
    call restart

 .foundKernel:
    pop di
    
    mov si, msgFoundKernel
    call printStr
    mov ax, WORD [es:di+30]
    mov bx, WORD [es:di+28]
    call printNumLarge
    call printNewline
    
    mov ax, WORD [es:di+26]     ; Read in the starting cluster
    
    ret



; Read sectors from the floppy disk to es:0
; Arguments:
;     es - Segment to load into
;     bx - Offset to load at
;     ax - Sector to load (cylinder/head calculated)
;     cl - Number of segments to load

readFloppy:
    pusha                       ; Save GP Registers
    mov bp,sp                   ; Save stack pointer

    push bx                     ; Save offset
    mov  bl, cl                 ; Save number of segments
    ; Convert LBA/logical sector to CHS
    mov cx, SECTORS_PER_TRACK
    xor dx, dx                  ; Clear dx since we're dividing dx:ax by bx
    div cx                      ; Divide Sector / Sectors per track 
    inc dx                      ; Remainder + 1 is the sector
    push dx                     ; Save the sector

    xor dx, dx
    mov cx, NUM_HEADS           ; Now divide the last result by the number
    div cx                      ; of heads
    
    pop cx                      ; Sector in cl
    mov dh, dl                  ; Head number
    mov ch, al                  ; Track Number

    
    mov di, 5                   ; 5 retries
 .found:
    mov al, bl                  ; Number of sectors to read
    pop bx                      ; Offset to load at
    mov dl, [bootDrive]         ; Read from the drive
    mov ah, 02h                 ; We want to read from the drive
    int 13h
    jnc .success
    
    dec di
    jnz .found                  ; Try again
    
    ; Failed too many times, error
    mov si, msgDiskError
    call printStr               ; Print error message
    call restart                ; Die and restart
    
 .success:
    mov sp, bp                  ; Restore stack
    popa                        ; Restore registers
    ret                         ; Return







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

; Our 'data' section
bootDrive       db 0x00
startingCluster dw 0x0000

msgEnter        db "Entered Stage Two!",10,13,0
msgNoKernel     db "kernel.bin was not found in the root directory",10,13,0
msgRestart      db "Press any key to restart the computer...",0
msgDiskError    db "Failed to read sector after 5 retries",10,13,0
msgFoundKernel  db "Found kernel of size 0x",0
msgReading      db "Reading in kernel: ",10,13,0
msgReadBlock1   db " Block: ",0
msgReadBlock2   db " to ",0
msgKernelRead   db "Kernel successfully loaded.",10,13,0
kernelFileName  db "KERNEL  BIN"

    

