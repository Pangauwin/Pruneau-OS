; ============================================================================
; boot.asm  --  Stage 1 bootloader (the Master Boot Record)
;
; The BIOS loads exactly ONE sector (512 bytes) from the boot disk into
; memory at physical address 0x7C00, then jumps to it in 16-bit real mode
; with almost nothing set up (no stack guaranteed, DL = boot drive number).
; This code's only job is: set up a stack, load the "real" kernel image
; (which lives in the sectors right after this one) into memory, and jump
; into it. Everything else happens there.
; ============================================================================

BITS 16
ORG 0x7C00

KERNEL_LOAD_SEGMENT equ 0x0000
KERNEL_LOAD_OFFSET  equ 0x8000     ; load kernel image to physical 0x8000
KERNEL_SECTORS      equ 64         ; how many 512-byte sectors to read
                                    ; (64 sectors = 32 KB; bump this up if
                                    ; your linked kernel image grows past that
                                    ; -- see the Makefile for how this is kept
                                    ; in sync automatically)

start:
    cli                     ; no interrupts while we set segments/stack up
    xor ax, ax
    mov ds, ax              ; DS = ES = SS = 0 : we use flat "segment 0"
    mov es, ax              ;  addressing everywhere, offsets are real addrs
    mov ss, ax
    mov sp, 0x7C00          ; stack grows down from right below our own code
    sti

    mov [boot_drive], dl    ; BIOS passed the boot drive number in DL - save it

    mov si, msg_loading
    call print_string

    mov bx, KERNEL_LOAD_OFFSET
    mov dh, KERNEL_SECTORS
    mov dl, [boot_drive]
    call disk_load

    mov si, msg_jumping
    call print_string

    ; Jump into the loaded image. It starts in 16-bit real mode too, so a
    ; normal far jump is fine here.
    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

; ----------------------------------------------------------------------------
; disk_load: read sectors from disk using BIOS INT 0x13, function 0x02
;   in:  dl = drive number, dh = number of sectors to read, es:bx = buffer
;   Reads starting at cylinder 0, head 0, sector 2 (sector 1 is this boot
;   sector itself). This only works for images that fit within one
;   cylinder/track using CHS addressing -- more than enough for our needs.
; ----------------------------------------------------------------------------
disk_load:
    push dx                ; remember how many sectors we asked for

    mov ah, 0x02            ; BIOS "read sectors" function
    mov al, dh               ; number of sectors to read
    mov ch, 0x00              ; cylinder 0
    mov cl, 0x02               ; start at sector 2 (1-indexed; sector 1 = us)
    mov dh, 0x00                 ; head 0
    int 0x13

    jc disk_error             ; carry flag set => BIOS reported an error

    pop dx                   ; dh = number of sectors we originally requested
    cmp al, dh               ; BIOS returns actual sectors read in AL
    jne disk_error
    ret

disk_error:
    mov si, msg_disk_error
    call print_string
    jmp $                    ; halt forever (hang) - nothing else we can do

; ----------------------------------------------------------------------------
; print_string: prints a null-terminated string using the BIOS teletype
; interrupt.  in: ds:si = pointer to string
; ----------------------------------------------------------------------------
print_string:
    pusha
.loop:
    lodsb                    ; al = [ds:si], si++
    test al, al
    jz .done
    mov ah, 0x0E              ; BIOS "teletype output" function
    mov bh, 0x00
    int 0x10
    jmp .loop
.done:
    popa
    ret

boot_drive   db 0
msg_loading    db "Stage 1: loading kernel image...", 13, 10, 0
msg_jumping    db "Stage 1: jumping to kernel", 13, 10, 0
msg_disk_error db "Stage 1: DISK READ ERROR", 13, 10, 0

; ----------------------------------------------------------------------------
; Pad the rest of the sector with zeros and add the mandatory boot signature.
; The BIOS refuses to treat a disk as bootable unless the last two bytes of
; the first sector are 0x55, 0xAA.
; ----------------------------------------------------------------------------
times 510-($-$$) db 0
dw 0xAA55