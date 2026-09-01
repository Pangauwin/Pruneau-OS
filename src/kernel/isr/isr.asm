BITS 64
section .text

extern isr_handler

; A lot of exceptions don't push errcode, so this is a default one
%macro ISR_NO_ERRCODE 1

global isr%1

isr%1:
    push qword 0 ;the dummy 0 errcode
    push qword %1
    jmp isr_common_stub

%endmacro

%macro ISR_ERRCODE 1
global isr%1
isr%1:
    push qword %1
    jmp isr_common_stub
%endmacro

ISR_NO_ERRCODE 0
ISR_NO_ERRCODE 1
ISR_NO_ERRCODE 2
ISR_NO_ERRCODE 3
ISR_NO_ERRCODE 4
ISR_NO_ERRCODE 5
ISR_NO_ERRCODE 6
ISR_NO_ERRCODE 7
ISR_ERRCODE    8
ISR_NO_ERRCODE 9
ISR_ERRCODE    10
ISR_ERRCODE    11
ISR_ERRCODE    12
ISR_ERRCODE    13
ISR_ERRCODE    14
ISR_NO_ERRCODE 15
ISR_NO_ERRCODE 16
ISR_ERRCODE    17
ISR_NO_ERRCODE 18
ISR_NO_ERRCODE 19
ISR_NO_ERRCODE 20
ISR_ERRCODE    21
ISR_NO_ERRCODE 22
ISR_NO_ERRCODE 23
ISR_NO_ERRCODE 24
ISR_NO_ERRCODE 25
ISR_NO_ERRCODE 26
ISR_NO_ERRCODE 27
ISR_NO_ERRCODE 28
ISR_ERRCODE    29
ISR_ERRCODE    30
ISR_NO_ERRCODE 31

isr_common_stub:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15 ;save all registers ;)

    mov rdi, rsp ;arg 1 to isr_handler = pointer to struct registers
    call isr_handler

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    add rsp, 16          ; discard our pushed [vector, error code] pair
    iretq                ; return from interrupt: pops RIP, CS, RFLAGS,
                         ; RSP, SS and resumes execution where it left off




