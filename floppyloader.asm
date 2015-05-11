[bits 16]
[org 0]
; Where we'll load in the stage2
; Since we're located at 07C0:0000 and we're loading at 0100:000
; That leaves us 0x6C00 bytes or 27648 bytes for the stage 2 loader
%define stage_seg    0x100

; We want to load the root directory above this loader
%define ROOT_DIR_SEGMENT 0x7e0
%define FAT_SEGMENT      0x7e0

%define FLOPPY_DRIVE  0x00

%define DIRECTORY_ENTRIES   224
%define BYTES_PER_ENTRY     32
%define ROOT_DIR_SECTORS    ( (DIRECTORY_ENTRIES * BYTES_PER_ENTRY) / 512 )

%define TOTAL_SECTORS       2880
%define RESERVED_SECTORS    1
%define SECTORS_PER_CLUSTER 1
%define SECTORS_PER_FAT     9
%define NUM_FATS            2
%define NUM_HEADS           2
%define SECTORS_PER_TRACK   18

%define TRACKS_PER_SIDE     ((TOTAL_SECTORS / SECTORS_PER_TRACK)/2)

%define FAT_SECTOR          RESERVED_SECTORS
%define ROOT_DIR_SECTOR     ( FAT_SECTOR + (SECTORS_PER_FAT * NUM_FATS) )
%define FILENAME_LENGTH     11
;
; FAT Boot Record for a 1.44mb floppy
;
jmp short init                  ; Bytes 0-1   - Jump over boot record
nop                             ; Byte  2

db "real_os_"                   ; Bytes 3-10  - OEM Identifier
dw 512                          ; Bytes 11-12 - Bytes per Sector
db SECTORS_PER_CLUSTER          ; Byte  13    - Sectors per Cluster
dw RESERVED_SECTORS             ; Bytes 14-15 - Reserved Sectors (This one)
db NUM_FATS                     ; Byte  16    - Number of FATs
dw DIRECTORY_ENTRIES            ; Bytes 17-18 - Root Directory Entries
dw TOTAL_SECTORS                ; Bytes 19-20 - Total Number of Sectors
db 0xf0                         ; Byte  21    - Media Descriptor Type
dw SECTORS_PER_FAT              ; Bytes 22-23 - Sectors per FAT
dw SECTORS_PER_TRACK            ; Bytes 24-25 - Sectors per Track
dw NUM_HEADS                    ; Bytes 26-27 - Number of Heads/Sides
dd 0                            ; Bytes 28-31 - Number of Hidden Sectors
dd 0                            ; Bytes 32-35 - Large Amt Sectors (unused)
;
; FAT12 Extended Boot Record
;
db 0x00                         ; Byte  36    - Drive Number
db 0x00                         ; Byte  37    - Reserved
db 0x29                         ; Byte  38    - Signature (0x28 or 0x29)
dd 0xDEADBEEF                   ; Bytes 39-42 - Volume ID
db "RealOS     "                ; Bytes 43-53 - Volume Label (space padded)
db "FAT12   "                   ; Bytes 54-61 - System Identifier



; Make sure that cs=0x7c0 so we know where we are
; Most bioses boot to 0:0x7c00 but some boot to 0x7c0:0
; We do this to be consistant
init:
    jmp 0x7c0:start


start:
    cli
    mov ax, cs                  ;
    mov ds, ax                  ; Make all our segments the same
    mov es, ax                  ;

    ; Set up the stack to be the top of the first segment
    mov ax, 0
    mov ss, ax
    mov sp, 0xFFFF
    sti
    
    mov ah, 00h                 ; Set Video Mode
    mov al, 03h                 ; Mode 3 - 80x25 text, 16 color
    int 10h

    mov si, msgEnter            ; Print our entrance message
    call printStr

floppyReset:
    mov ah, 0                   ; Initialize drive
    mov dl, FLOPPY_DRIVE        ; Floppy Drive
    int 13h
    jc  floppyReset             ; If there was an error, try again


    ; Read in the directory entry
    mov ax, ROOT_DIR_SEGMENT
    mov es, ax                  ; Segment to load at
    mov ax, ROOT_DIR_SECTOR     ; Start sector
    mov bl, ROOT_DIR_SECTORS    ; Sectors to load
    call readFloppy

    
    ; Look through the directory entries for KERNEL  BIN
    mov si, stageFileName      ; First operand offset (segment in ds)
    mov di, 0                   ; Start at the first entry
    mov cx, FILENAME_LENGTH      
    mov al, DIRECTORY_ENTRIES

cmpEntry:
    repe cmpsb                  ; Compare the strings
    je foundKernel    


nextEntry:
    add di, ax                  ; Move the remaining characters in the name
    add di, 20                  ; Move to the next entry
    mov si, stageFileName
    mov cx, FILENAME_LENGTH
    dec al
    jnz cmpEntry
    
    ; Could not find the stage
    mov si, msgNoKernel
    call printStr
    mov ah, 0                   
    int 16h                     ; Wait for a keypress
    int 19h                     ; Reboot

foundKernel:
    mov ax, WORD [es:di+15]      ; Read in the starting cluster
    mov WORD [startingCluster], ax ; Keep it safe

    ; We don't need the size since we'll just load and follow the fat
   ; mov bx, WORD [es:di+17]      ; Read in the low half of the size
   ; mov dx, WORD [es:di+19]      ; Read in the high half of the size
    
    mov si, msgFoundKernel
    call printStr

    ; Read in the FAT
    mov ax, FAT_SEGMENT
    mov es, ax                  ; Segment to load at
    mov ax, FAT_SECTOR          ; Start sector
    mov bl, SECTORS_PER_FAT     ; Sectors to load
    call readFloppy


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
    jz  .done               ; Finish on a null character

    mov ah, 0x0e                ; BIOS - Write Character 
    int 10h                     ; 

    jmp .loop

 .done:
    mov sp, bp                  ; Restore stack pointer
    popa                        ; Restore GP registers
    ret



; Read sectors from the floppy disk to es:0
; Arguments:
;     es - Segment to load into
;     ax - Sector to load (cylinder/head calculated)
;     bl - Number of segments to load
readFloppy:
    pusha                       ; Save GP Registers
    mov bp,sp                   ; Save stack pointer

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
    xor bx, bx                  ; Always read starting at offset 0
    mov dl, FLOPPY_DRIVE        ; Read from the floppy drive
    mov ah, 02h                 ; We want to read from the drive
    int 13h
    jnc .success
    
    dec di
    jnz .found                  ; Try again
    ; Failed too many times, error
    mov si, diskError
    call printStr               ; Print error message
    mov ah, 0
    int 16h                     ; Wait for any key
    int 19h                     ; Reset

 .success:
    mov sp, bp                  ; Restore stack
    popa                        ; Restore registers
    ret                         ; Return







msgEnter       db "Entered Bootloader",10,13,0
msgNoKernel    db "stage2.bin not found",10,13,0
msgFoundKernel db "Found Stage 2l!",10,13,0
diskError      db "Disk Error",10,13,0
stageFileName db "STAGE2  BIN"

startingCluster dw 0x0000

times 510 - ($-$$) db 0         ; Fill all remaing space with 0's except
dw 0xaa55                       ; for the last two, which are 0xAA55
