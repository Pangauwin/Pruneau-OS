; ============================================================================
; entry.asm
;
; This is the FIRST code that runs after Stage 1 jumps to 0x8000. It is
; linked together with kernel.c into a single flat binary by linker.ld, so
; all the labels below (kmain, stack_top, etc.) are resolved by the linker,
; not guessed at as magic offsets.
;
; Execution walks straight down through four stages:
;   1. real_mode_entry   (16-bit) : enable A20, load a 32-bit GDT, enter PM
;   2. protected_mode_entry (32-bit): build page tables, enter Long Mode
;   3. long_mode_entry   (64-bit) : load a 64-bit GDT, set segment regs
;   4. _start            (64-bit) : set up the stack, call kmain()
; ============================================================================

global _start
extern kmain

; ============================================================================
; STAGE 1: 16-bit real mode
; ============================================================================
BITS 16
section .entry16

real_mode_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax          ; segments were already 0 from Stage 1, but be safe

    call enable_a20

    lgdt [gdt32.pointer]

    mov eax, cr0
    or  eax, 1              ; CR0.PE = 1 : enable Protected Mode
    mov cr0, eax

    ; A far jump is required here, not just for style: it flushes the CPU's
    ; instruction prefetch queue (which still has 16-bit-decoded bytes in
    ; it) and it loads CS with the new 32-bit code selector, which is what
    ; actually switches the CPU into 32-bit instruction decoding.
    jmp gdt32.code_seg:protected_mode_entry

; ----------------------------------------------------------------------------
; enable_a20
;
; On real 20th-century PC hardware, address line 20 (A20) was wired to
; always be zero for backwards compatibility with the 8086's 1MB wraparound
; behaviour. If we don't enable it, every address calculation silently
; wraps at 1MB and paging/64-bit addressing above that point breaks in
; extremely confusing ways. Modern BIOS/QEMU usually pre-enables it, but we
; do it ourselves to be portable. This "fast A20" method via I/O port 0x92
; is not universally supported on real vintage hardware but works on every
; emulator and essentially all machines built after the mid-90s.
; ----------------------------------------------------------------------------
enable_a20:
    in  al, 0x92
    or  al, 2
    and al, 0xFE            ; make sure we don't accidentally trigger a reset
    out 0x92, al
    ret

; ----------------------------------------------------------------------------
; 32-bit flat GDT, used only to get us into Protected Mode.
;
; Both descriptors span the entire 4GB address space (base 0, limit
; 0xFFFFF with 4K granularity = 4GB) so effectively there's no segmentation
; happening at all -- we get a flat linear address space, exactly like
; you'd expect from a "modern" OS. This GDT is temporary; stage 3 below
; will load a second, 64-bit GDT once we reach Long Mode.
; ----------------------------------------------------------------------------
align 8
gdt32:
    dq 0x0000000000000000          ; entry 0: null descriptor (required)

.code: equ $ - gdt32
    dw 0xFFFF, 0x0000
    db 0x00
    db 10011010b     ; present, ring0, code, executable, readable
    db 11001111b     ; granularity=4K, 32-bit default operand size, limit[19:16]
    db 0x00

.data: equ $ - gdt32
    dw 0xFFFF, 0x0000
    db 0x00
    db 10010010b     ; present, ring0, data, writable
    db 11001111b
    db 0x00

.end:

.pointer:
    dw .end - gdt32 - 1     ; GDT limit (size - 1)
    dd gdt32                ; GDT base address (32-bit, we're still <4GB)

.code_seg equ .code
.data_seg equ .data

; ============================================================================
; STAGE 2: 32-bit protected mode
; ============================================================================
BITS 32
section .entry32

protected_mode_entry:
    mov ax, gdt32.data_seg
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x9FC00         ; temporary stack, just below the 640K barrier

    call setup_page_tables
    call enter_long_mode

    lgdt [gdt64.pointer]

    jmp gdt64.code_seg:long_mode_entry

; ----------------------------------------------------------------------------
; setup_page_tables
;
; x86-64 paging (even the most basic identity mapping) always uses a
; 4-level page table walk: PML4 -> PDPT -> PD -> PT. To keep this simple we
; use 2MB "huge pages" at the PD level, which lets us skip the 4th level
; (PT) entirely. We place four page-aligned tables in low, known-fixed
; physical memory: PML4 at 0x1000, PDPT at 0x2000, PD at 0x3000.
;
;   PML4[0]      -> points to PDPT
;   PDPT[0]      -> points to PD
;   PD[0..511]   -> 512 entries x 2MB each = identity-map the first 1GB
;
; "Identity mapping" means virtual address X maps to physical address X --
; we're not relocating anything yet, just satisfying the CPU's hard
; requirement that paging be turned on before Long Mode can be entered.
; ----------------------------------------------------------------------------
PML4_ADDR equ 0x1000
PDPT_ADDR equ 0x2000
PD_ADDR   equ 0x3000

setup_page_tables:
    ; zero out all three tables (3 pages = 0x3000 bytes starting at 0x1000)
    mov edi, PML4_ADDR
    mov ecx, 0x3000 / 4
    xor eax, eax
    rep stosd

    ; PML4[0] = address of PDPT, present + writable
    mov dword [PML4_ADDR], PDPT_ADDR | 0b11

    ; PDPT[0] = address of PD, present + writable
    mov dword [PDPT_ADDR], PD_ADDR | 0b11

    ; fill all 512 entries of the PD with consecutive 2MB pages:
    ;   flags = present(bit0) + writable(bit1) + page-size(bit7, =2MB page)
    mov edi, PD_ADDR
    mov eax, 0b10000011
    mov ecx, 512
.fill:
    mov [edi], eax
    add eax, 0x200000        ; next 2MB-aligned physical address
    add edi, 8                ; each PD entry is 8 bytes
    loop .fill

    ret

; ----------------------------------------------------------------------------
; enter_long_mode
;
; The official sequence (Intel SDM Vol 3, section on IA-32e mode
; activation) is:
;   1. Enable PAE           (CR4.PAE = 1)   -- required for 64-bit paging
;   2. Point CR3 at the PML4
;   3. Set IA32_EFER.LME    (via the EFER MSR) -- "Long Mode Enable"
;   4. Enable paging        (CR0.PG = 1)
; The moment step 4 executes, the CPU is technically already in Long Mode,
; but in its 32-bit "compatibility" sub-mode, because CS still refers to
; our old 32-bit code descriptor. We only reach full 64-bit mode after the
; far jump that follows this function, once CS points at a descriptor with
; the 64-bit "L" (long) bit set.
; ----------------------------------------------------------------------------
enter_long_mode:
    mov eax, cr4
    or  eax, 1 << 5           ; CR4.PAE
    mov cr4, eax

    mov eax, PML4_ADDR
    mov cr3, eax

    mov ecx, 0xC0000080       ; IA32_EFER MSR
    rdmsr
    or  eax, 1 << 8           ; EFER.LME
    wrmsr

    mov eax, cr0
    or  eax, 1 << 31          ; CR0.PG
    mov cr0, eax

    ret

; ----------------------------------------------------------------------------
; 64-bit GDT. Segmentation is essentially vestigial in Long Mode -- base
; and limit are ignored for code/data segments and the CPU always treats
; memory as flat -- but you still need valid descriptors with the right
; bits set (particularly the "L" long-mode bit on the code segment) purely
; so the CPU knows to interpret instructions as 64-bit.
; ----------------------------------------------------------------------------
align 8
gdt64:
    dq 0x0000000000000000

.code: equ $ - gdt64
    dq (1<<43) | (1<<44) | (1<<47) | (1<<53)
    ; bit 43 = executable, bit 44 = code/data descriptor (not system),
    ; bit 47 = present, bit 53 = "L" long-mode (64-bit) code segment

.data: equ $ - gdt64
    dq (1<<41) | (1<<44) | (1<<47)
    ; bit 41 = writable, bit 44 = code/data, bit 47 = present

.end:

.pointer:
    dw .end - gdt64 - 1
    dd gdt64

.code_seg equ .code
.data_seg equ .data

; ============================================================================
; STAGE 3: 64-bit long mode
; ============================================================================
BITS 64
section .entry64

long_mode_entry:
    mov ax, gdt64.data_seg
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ; note: in 64-bit mode CS is loaded implicitly by the far jump that got
    ; us here, and there is no way to `mov cs, ax` -- that's normal.

_start:
    ; ------------------------------------------------------------------
    ; This is the "stub" you asked about: the hand-off point from raw
    ; boot assembly into your C kernel. By the time we're here the CPU
    ; is fully in 64-bit long mode with paging enabled, so this is just
    ; ordinary 64-bit code following the System V x86-64 calling
    ; convention that your C compiler also uses.
    ; ------------------------------------------------------------------
    mov rsp, stack_top       ; give the C code its own, dedicated stack
    xor rbp, rbp             ; zero the frame pointer (marks "end of stack"
                              ; for stack unwinders/debuggers)

    call kmain                ; hand off to C -- this never returns

.hang:
    cli
    hlt
    jmp .hang                ; safety net in case kmain() ever returns


; ============================================================================
; The kernel's stack. .bss is zero-initialized and takes no space in the
; file on disk (the linker script places it after everything else and the
; loader doesn't need to read it from disk at all), so a generous size here
; costs nothing on disk.
; ============================================================================
section .bss
align 16
stack_bottom:
    resb 16384                ; 16 KB kernel stack
stack_top: