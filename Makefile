# Makefile for the hand-rolled x86-64 bootloader + kernel.
#
# Targets:
#   make        - build disk.img
#   make run    - build and boot disk.img in QEMU
#   make clean  - remove build artifacts

CC      = gcc
LD      = ld
NASM    = nasm
OBJCOPY = objcopy

CFLAGS  = -ffreestanding -fno-stack-protector -fno-pic -fno-pie \
          -mno-red-zone -mcmodel=kernel -m64 -Wall -Wextra -O2 \
		  -fno-tree-loop-distribute-patterns -mgeneral-regs-only

all: build/disk.img

# --- Stage 1: MBR boot sector (flat binary, must be exactly 512 bytes) ---
build/boot.bin: src/boot/boot.asm
	$(NASM) -f bin $< -o $@
	@size=$$(wc -c < $@); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: boot.bin is $$size bytes, must be exactly 512"; exit 1; \
	fi

# --- Kernel image: entry.asm (mode transitions + _start) + kernel.c ---
build/entry.o: src/kernel/entry.asm
	$(NASM) -f elf64 $< -o $@

build/vga.o: src/kernel/vga/vga.c
	$(CC) $(CFLAGS) -c $< -o $@

build/isr_asm.o: src/kernel/isr/isr.asm
	$(NASM) -f elf64 $< -o $@

build/isr.o: src/kernel/isr/isr.c
	$(CC) $(CFLAGS) -c $< -o $@

build/kernel.o: src/kernel/kernel.c
	$(CC) $(CFLAGS) -c $< -o $@

build/idt_asm.o: src/kernel/idt/idt.asm
	$(NASM) -f elf64 $< -o $@

build/idt.o: src/kernel/idt/idt.c
	$(CC) $(CFLAGS) -c $< -o $@

build/string.o: src/kernel/memory/string.c
	$(CC) $(CFLAGS) -c $< -o $@

build/kernel.elf: build/entry.o build/vga.o build/kernel.o build/idt.o build/string.o build/isr_asm.o build/isr.o build/idt_asm.o src/kernel/linker.ld
	$(LD) -n -T src/kernel/linker.ld -o $@ build/entry.o build/kernel.o build/idt.o build/string.o build/vga.o build/isr_asm.o build/isr.o build/idt_asm.o

build/kernel.bin: build/kernel.elf
	$(OBJCOPY) -O binary $< $@

# --- Final disk image: boot sector + kernel image, padded to a floppy size ---
# KERNEL_SECTORS in boot.asm must be able to hold kernel.bin -- this check
# fails loudly instead of silently truncating your kernel if it grows.
build/disk.img: build/boot.bin build/kernel.bin
	@ksize=$$(wc -c < build/kernel.bin); \
	maxbytes=$$(( 64 * 512 )); \
	if [ $$ksize -gt $$maxbytes ]; then \
		echo "ERROR: kernel.bin ($$ksize bytes) exceeds KERNEL_SECTORS budget ($$maxbytes bytes)."; \
		echo "Increase KERNEL_SECTORS in boot/boot.asm and rebuild."; \
		exit 1; \
	fi
	cat build/boot.bin build/kernel.bin > $@
	truncate -s 1474560 $@

run: build/disk.img
	qemu-system-x86_64 -drive format=raw,file=build/disk.img

clean:
	rm -f ./build/*.o ./build/*.elf ./build/*.bin ./build/*.img

.PHONY: all run clean