org 0x7C00 ;location 0x7C00 is where the bios finds the first sector of our bootable device (legacy booting) => org directive offsets all of our code to this location
bits 16 ;tells the assembler to emit 16-bits code (nothing to see with 32/64 bits architecture)

%define ENDL 0x0D, 0x0A

;
; FAT12 headers
;

jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'   ;8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_entries_count:          dw 0E0h
bdb_total_sectors:          dw 2880         ;2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h         ;F0: 3.5" floppy disk
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

;extended boot record
ebr_drive_number:           db 0            ;0x00: floppy; 0x80: hdd; actually useless
                            db 0            ;reserved byte
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; put anything here, just 4 bytes
ebr_volume_label:           db 'PRUNEAU OS '   ;11 bytes string, padded with spaces
ebr_system_id:              db 'FAT12   '      ;8 bytes, padded with spaces


start:
    jmp main


;
;   Print string to screen
;   Params:
;       -   ds:si pointing to the string
;
puts:
    push si
    push ax

.loop:
    lodsb   ;loads next character (load a byte/word/double word from ds:si to al)
    or al, al   ;checks if the character is 0 (change flag)

    jz .done ; checks if flag is 0

    mov ah, 0x0E
    mov bh, 0
    int 10h

    jmp .loop

.done:
    pop ax
    pop si
    ret

main:

    mov ax, 0 ;can't write directly into ds and es
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00 ;start of the program, stack grows downard, so we don't want it to overwrite our program


    ; read data from floppy disk
    mov [ebr_drive_number], dl
    mov ax, 1                       ;LDA = 1 (second sector of the disk)
    mov cl, 1                       ;1 sector to read
    mov bx, 0x7E00                  ;data should be after the bootloader

    call disk_read

    mov si, msg_hello
    call puts

    cli
    hlt

;
; Error handlers
;

floppy_error:
    mov si, msg_disk_error_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h         ;wait for keypress
    jmp 0FFFFh:0    ;jumps at the beginning of the BIOS, should restart

.halt:
    cli             ;disable interrupts, can't get out of "halt" status
    jmp .halt


;
; Disk routines
;

;
; Converts lba address to chs address
; Parameters:
;  - ax: LBA address
; Returns:
;  - cx [bits 0-6]: sector number
;  - cx [bits 6-15]: cylinder
;  - dh: head
;
lba_to_chs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack
    inc dx                              ; dx = LBA % SectorsPerTrack + 1 = sector
    mov cx, dx

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads
                                        ; dx = (LBA / SectorsPerTrack) % Heads

    mov dh, dl ;head
    mov ch, al ;cylinder
    shl ah,  6 ;shift to the left by 6 positions
    or  cl, ah ;put upper 2 bits of the cylinder in cl

    pop ax
    mov dl, al
    pop ax

    ret

;
; Reads from disk
; Parameters:
;  - ax: LBA address
;  - cl: number of sectors to read (up to 128)
;  - dl: drive number
;  - es:bx: memory address where we store data
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx

    call lba_to_chs
    pop ax

    mov ah, 02h

    mov di, 3

.retry:
    pusha               ;save all the registers, we don't know what bios modifies
    stc                 ;set the carry flag, some BIOS don't set it themselves
    int 13h
    jnc .done           ;if the carry flag is cleared, the operation has succeeded

    ;read failed
    popa                ;pop all the registers
    call disk_reset

    dec di              ;decrement di
    test di, di         
    jnz .retry          ;if di != 0, retry

.fail:
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

;
; Resets disk controller
; Parameters:
;  - dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret




msg_hello: db 'Starting Pruneau OS...', ENDL, 0
msg_disk_error_failed: db 'Reading from floppy disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h ;Signature to confirm the BIOS that this is the Operating System he wants to load