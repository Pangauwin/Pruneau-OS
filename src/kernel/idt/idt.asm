BITS 64

;
; Loads IDTs into CPU
; declared in C as 'extern void idt_load()'
;
global _idt_load
extern _idtp
_idt_load:
    lidt [_idtp]
    ret