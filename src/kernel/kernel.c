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

uint64_t memory_pages[2];
 
void kmain(void)
{
    vga_clear();
    vga_print_line("Entered kernel");
    idt_install();
    
    init_memory();

    vga_print_kv("last address: ", last_address);
    vga_print_kv("next address: ", next_memory_page_address);

    for (int i = 0; i < 2; ++i) {
        memory_pages[i] = allocate_new_memory_page();
        vga_print_kv("current allocation address: ", memory_pages[i]);
        vga_print_kv("next address: ", next_memory_page_address);
    }

    vga_print_line("End of program");

    while (1) {
        __asm__ __volatile__("hlt");
    }
}