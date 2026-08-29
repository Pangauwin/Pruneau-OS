org 0x7C00 ;location 0x7C00 is where the bios finds the first sector of our bootable device (legacy booting) => org directive offsets all of our code to this location
bits 16 ;tells the assembler to emit 16-bits code (nothing to see with 32/64 bits architecture)

%define ENDL 0x0D, 0x0A

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

    jz .pdone ; checks if flag is 0

    mov ah, 0x0E
    mov bh, 0
    int 10h

    jmp .loop

.pdone:
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

    mov si, msg_hello
    call puts

    hlt

.halt:
    hlt


msg_hello: db 'PruneauOS', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h ;Signature to confirm the BIOS that this is the Operating System he wants to load