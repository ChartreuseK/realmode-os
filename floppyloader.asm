[bits 16]
[org 0]
[cpu 8086] ; Attempt to stop me from accidentally using 286 instructions

; Where we'll load in the stage2
; Since we're located at 07C0:0000 and we're loading at 0100:000
; That leaves us 0x6C00 bytes or 27648 bytes for the stage 2 loader
%define STAGE_SEGMENT    0x100

; We want to load the root directory above this loader
%define ROOT_DIR_SEGMENT 0x7e0
%define FAT_SEGMENT      0x7e0

%define FLOPPY_DRIVE  0x00

%define DIRECTORY_ENTRIES   224
%define BYTES_PER_ENTRY     32
%define ROOT_DIR_SECTORS    ( (DIRECTORY_ENTRIES * BYTES_PER_ENTRY) / 512 )

%define BYTES_PER_SECTOR    512
%define TOTAL_SECTORS       2880
%define RESERVED_SECTORS    1
%define SECTORS_PER_CLUSTER 1
%define SECTORS_PER_FAT     9
%define NUM_FATS            2
%define NUM_HEADS           2
%define SECTORS_PER_TRACK   18
%define MEDIA_DESCRIPTOR 	0xf0
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
dw BYTES_PER_SECTOR             ; Bytes 11-12 - Bytes per Sector
db SECTORS_PER_CLUSTER          ; Byte  13    - Sectors per Cluster
dw RESERVED_SECTORS             ; Bytes 14-15 - Reserved Sectors (This one)
db NUM_FATS                     ; Byte  16    - Number of FATs
dw DIRECTORY_ENTRIES            ; Bytes 17-18 - Root Directory Entries
dw TOTAL_SECTORS                ; Bytes 19-20 - Total Number of Sectors
db MEDIA_DESCRIPTOR             ; Byte  21    - Media Descriptor Type
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

    ; Bios stores the boot drive in dl for us, save it 
    mov [bootDrive], dl

    mov ah, 00h                 ; Set Video Mode
    mov al, 03h                 ; Mode 3 - 80x25 text, 16 color
    int 10h

    mov si, msgEnter            ; Print our entrance message
    call printStr
 
driveReset:
    mov ah, 0                   ; Initialize drive
    mov dl, [bootDrive]         ; Boot Drive
    int 13h
    jc  driveReset             ; If there was an error, try again


    ; Read in the directory entry
    mov ax, ROOT_DIR_SEGMENT
    mov es, ax                  ; Segment to load at
    xor bx, bx                  ; Offset to load at
    mov ax, ROOT_DIR_SECTOR     ; Start sector
    mov cl, ROOT_DIR_SECTORS    ; Sectors to load
    call readFloppy

    
    ; Look through the directory entries for Stage  BIN
    mov si, stageFileName       ; First operand offset (segment in ds)
    mov di, 0                   ; Start at the first entry
    mov cx, FILENAME_LENGTH      
    mov al, DIRECTORY_ENTRIES

cmpEntry:
    push di                     ; Save the start of the current
    repe cmpsb                  ; Compare the strings
    je foundStage    


nextEntry:
    pop di                      ; Restore DI
    add di, BYTES_PER_ENTRY     ; Move to the next entry

    mov si, stageFileName
    mov cx, FILENAME_LENGTH
    dec al

    jnz cmpEntry
    
    ; Could not find the stage
    mov si, msgNoStage
    call printStr
    mov ah, 0                   
    int 16h                     ; Wait for a keypress
    int 19h                     ; Reboot

foundStage:
    pop di
    mov ax, WORD [es:di+26]     ; Read in the starting cluster
    mov WORD [startingCluster], ax  ; Keep it safe

    ; We don't need the size since we'll just load and follow the fat
    ; mov bx, WORD [es:di+28]   ; Read in the low half of the size
    ; mov dx, WORD [es:di+30]   ; Read in the high half of the size
    
    mov si, msgFoundStage
    call printStr

    ; Read in the FAT
    mov ax, FAT_SEGMENT
    mov es, ax                  ; Segment to load at
    mov ax, FAT_SECTOR          ; Start sector
    xor bx, bx                  ; Offset to load at
    mov cl, SECTORS_PER_FAT     ; Sectors to load
    call readFloppy


    mov ax, STAGE_SEGMENT
    mov es, ax                  ; Segment to load to
    mov ax, WORD [startingCluster]  ; Get the cluster to start at
    xor bx, bx                  ; Start at offset 0
    

 .next:
    ; Now convert the cluster to a logical sector
    push ax                     ; Save current cluster
    sub ax, 2                   ; Subtract 2 to zero the cluster number
    mov cx, SECTORS_PER_CLUSTER 
    mul cx                      ; Multiply ax by cx into ax
    add ax, ROOT_DIR_SECTOR + ROOT_DIR_SECTORS
    mov cl, SECTORS_PER_CLUSTER ; Read in one sector
    
    call readFloppy
    add bx, SECTORS_PER_CLUSTER * BYTES_PER_SECTOR  ; Move forward in ram
    pop ax                      ; Get current cluster
    call nextCluster            ; Find the next cluster
    cmp ax, 0xFF0

    jb .next                    ; If it's a valid sector, keep going
    
    ; We're done loading, jump to the Stage
    mov bl, BYTE [bootDrive]
    jmp STAGE_SEGMENT:0

haltLoop:
    jmp haltLoop




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
    mov ax, FAT_SEGMENT     
    mov es, ax                  ; We're reading from the fat segment
    mov dx, WORD [es:bx]        ; Read in 2 bytes from the fat

    test cx, 1                  ; Check if the cluster number is even
    jnz  .odd
 .even:
    and dx, 0x0FFF              ; Mask off the upper 4 bits
    jmp .found
 .odd:
    shr dx, 1                   ; Shift down to keep only the upper 12 bits
    shr dx, 1
    shr dx, 1
    shr dx, 1
 .found:
    mov ax, dx                  ; Our return value
    pop es
    pop dx
    pop cx
    pop bx                      ; Restore the register's
    ret                         ; Return


; Print's a message at the current cursor position to the screen
; Arguments:
;     si - Address of string
printStr:
    ;pusha                       ; Save all GP registers
    push ax
    push si

.loop:
    lodsb                       ; Read character from string into AL
    or  al, al                  ; Set flags based on al
    jz  .done                   ; Finish on a null character

    mov ah, 0x0e                ; BIOS - Write Character 
    int 10h                     ; 

    jmp .loop

 .done:
    ;popa                        ; Restore GP registers
    pop si
    pop ax
    ret

	

; Read sectors from the floppy disk to es:0
; Arguments:
;     es - Segment to load into
;     bx - Offset to load at
;     ax - Sector to load (cylinder/head calculated)
;     cl - Number of segments to load
readFloppy:
    ;pusha                       ; Save GP Registers
    push ax
    push bx
    push cx
    push dx
    
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
    mov si, diskError
    call printStr               ; Print error message
    mov ah, 0
    int 16h                     ; Wait for any key
    int 19h                     ; Reset

 .success:
    ;popa                        ; Restore registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret                         ; Return







msgEnter       db "Floppy Bootloader",10,13,0
msgNoStage     db "stage2.bin not found",10,13,0
msgFoundStage  db "Found Stage 2",10,13,0
diskError      db "Disk Error",10,13,0
stageFileName  db "STAGE2  BIN"

startingCluster dw 0x0000
bootDrive       db 0x00


times 510 - ($-$$) db 0         ; Fill all remaing space with 0's except
dw 0xaa55                       ; for the last two, which are 0xAA55
