BITS 16

%define BUFFER_SIZE 24

global get_memory_info
get_memory_info:
    pusha
    push es
    mov ebx, 0
    mov ax, 0x2000
    mov es, ax ;begin_ard_addr/16 or right shift 4 bits
    mov di, 0

.call_interrupt:
    mov eax, 0xe820
    mov ecx, BUFFER_SIZE
    mov edx, 'PAMS' ;reverse of SMAP

    int 15h
    jc .error

    inc byte [entry_count]
    cmp ebx, 0
    je .done

    add word [current_offset], BUFFER_SIZE
    mov di, [current_offset]
    
    jmp .call_interrupt

.done:
    pop es
    popa

    ret

.error:
    ;if error -- for the moment nothing // TODO: implement here
    jmp .done

global entry_count
global begin_ard_addr
global entry_size

section .data
begin_ard_addr dd 0x20000
current_offset dd 0
entry_size db BUFFER_SIZE

section .bss
entry_count resb 1 ;resb stands for reserve byte