#include <stdint.h>

#include "../vga/vga.h"

struct registers {
    uint64_t r15, r14, r13, r12, r11, r10, r9, r8;
    uint64_t rbp, rsp, rdi, rsi, rdx, rcx, rbx, rax;

    uint64_t int_no, err_code;
    uint64_t rip, cs, rflags, ss;
} __attribute__((packed));


static const char *exception_names[32] = {
    "Divide-by-zero Error",
    "Debug",
    "Non-Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 Floating-Point Exception",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Control Protection Exception",
    "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved",
    "Hypervisor Injection Exception",
    "VMM Communication Exception",
    "Security Exception",
    "Reserved",
};

void isr_handler(struct registers *regs)
{
    if (regs->int_no == 3) { // Exception 3: breakpoint (used by debuggers, so not fatal)
        vga_print_line("Breakpoint hit (int3) -- resuming execution.");
        return;
    }
 
    vga_clear();
    vga_print_line("*** UNHANDLED CPU EXCEPTION ***");
    vga_print_line(exception_names[regs->int_no]);
    vga_print_kv("Vector",     regs->int_no);
    vga_print_kv("Error code", regs->err_code);
    vga_print_kv("RIP",        regs->rip);
    vga_print_kv("CS",         regs->cs);
    vga_print_kv("RFLAGS",     regs->rflags);
    vga_print_kv("RSP",        regs->rsp);
 
    for (;;) {
        __asm__ __volatile__("cli; hlt");
    }
}
