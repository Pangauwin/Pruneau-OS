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

#include "memory/pmm/pmm.h"


/* kmain: the C-level entry point of the kernel.
 * Returning from here would fall back into entry.asm's ".hang" loop
 * (cli; hlt; jmp .hang), so in practice this function should never return.
 */
 
void kmain(void)
{
    vga_clear();
    vga_print_line("Entered kernel");
    idt_install();
    vga_print_line("IDTs loaded!");

    vga_print_kv("Address range descriptors: ", entry_count);

    for (int i = 0; i < entry_count; ++i) 
    {
        address_range_descriptor* phys_addr = (address_range_descriptor*)(uint64_t)(begin_ard_addr + i * entry_size);
        vga_print_kv("-- NEW ENTRY -- Entry number ", i);
        vga_print_kv("length: ", phys_addr->length_lo + ((uint64_t)phys_addr->length_hi << 32));
        vga_print_kv("type: ", phys_addr->type);
    }

    vga_print_line("End of program");

    while (1) {
        __asm__ __volatile__("hlt");
    }
}