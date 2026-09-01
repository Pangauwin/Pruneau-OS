/* kernel.c
 *
 * This is freestanding C: there is no libc, no runtime, no OS underneath
 * us providing malloc/printf/etc -- WE are the OS. The compiler is told
 * this explicitly via -ffreestanding, and the linker is told not to expect
 * a normal C runtime via -nostdlib.
 *
 * kmain() is called by the assembly _start stub in entry.asm once the CPU
 * is in 64-bit long mode with a stack set up, using the standard System V
 * x86-64 calling convention -- from C's point of view this is just a
 * normal function call.
 */

#include <stdint.h>

#include "vga/vga.h"
#include "idt/idt.h"


/* kmain: the C-level entry point of the kernel.
 * Returning from here would fall back into entry.asm's ".hang" loop
 * (cli; hlt; jmp .hang), so in practice this function should never return.
 */
void kmain(void)
{
    vga_clear();
    vga_print_line("Entering kernel");
    vga_print_line("PruneauOS - loading...");

    vga_print_line("loading idts...");
    idt_install();
    vga_print_line("IDTs loaded!");

    // Exception tests

    /*vga_print_line("Testing IDT Vector 3...");
    __asm__ __volatile__("int3");
    vga_print_line("Resume after breakpoint! Success");

    __asm__ __volatile__(
    "xor %%edx, %%edx\n"
    "mov $10, %%eax\n"
    "xor %%ecx, %%ecx\n"
    "div %%ecx\n"
    :
    :
    : "rax", "rcx", "rdx"
    );*/ 

    vga_print_line("End of program");

    while (1) {
        __asm__ __volatile__("hlt");
    }
}