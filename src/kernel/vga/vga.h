#ifndef VGA_HEADER
#define VGA_HEADER

#include <stdint.h>

void vga_clear(void);
void vga_print_line(const char* _message);
void vga_print_kv(const char* _message, uint64_t _int);

#endif