/* linker.ld
 *
 * Ties everything together: it tells the linker WHERE in memory this
 * kernel image will physically live (0x8000 -- this MUST match
 * KERNEL_LOAD_OFFSET in boot.asm), and in what order to lay out the
 * sections from entry.asm and kernel.c.
 *
 * ENTRY(_start) just records _start as the "official" entry point in the
 * ELF header metadata for tools/debuggers; since we later objcopy this to
 * a raw flat binary, what actually matters for execution is that _start
 * (via the .entry16/.entry32/.entry64 chain) is placed first in the file.
 */

ENTRY(_start)

SECTIONS
{
    . = 0x8000;

    /* The three staged entry sections from entry.asm, placed first and in
       order, so the raw binary begins with real_mode_entry exactly at
       physical address 0x8000, matching where Stage 1 jumps to. */
    .entry16 : { *(.entry16) }
    .entry32 : { *(.entry32) }
    .entry64 : { *(.entry64) }

    /* Ordinary compiled C code and read-only data. */
    .text   : { *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }

    /* Initialized global/static data. */
    .data   : { *(.data .data.*) }

    /* Zero-initialized data (includes our 16KB kernel stack). This needs
       to exist in memory but doesn't need to be read from disk, so we
       could optimize disk space with NOLOAD -- kept simple here since our
       kernel is tiny. */
    .bss : { *(.bss .bss.*) *(COMMON) }

    /* Discard metadata sections we don't need in the final flat binary. */
    /DISCARD/ : { *(.comment) *(.eh_frame) *(.note.*) }
}
