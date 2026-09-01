#include "vga.h"

static uint16_t * const VGA_BUFFER = (uint16_t *)0xB8000;
#define VGA_WIDTH  80
#define VGA_HEIGHT 25
#define VGA_COLOR_DEFAULT 0x0F

/* Tracks which row to print the next line at, so callers can just keep
 * calling vga_print_line() without managing cursor position themselves --
 * this is what lets kernel.c and isr.c both print without stepping on
 * each other's output. */
static int cursor_row = 0;

void vga_clear(void)
{
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        VGA_BUFFER[i] = ((uint16_t)VGA_COLOR_DEFAULT << 8) | ' ';
    }
    cursor_row = 0;
}

void vga_print_line(const char *str)
{
    if (cursor_row >= VGA_HEIGHT) {
        cursor_row = 0; /* wrap back to the top rather than write off-screen */
    }

    int offset = cursor_row * VGA_WIDTH;
    int col = 0;
    while (*str && col < VGA_WIDTH) {
        VGA_BUFFER[offset + col] = ((uint16_t)VGA_COLOR_DEFAULT << 8) | (uint8_t)*str;
        str++;
        col++;
    }
    cursor_row++;
}

/* Formats a 64-bit value as "0x" followed by 16 hex digits. buf must have
 * room for at least 19 bytes (2 + 16 + null terminator). */
static void uint64_to_hex(uint64_t value, char *buf)
{
    const char *digits = "0123456789ABCDEF";
    buf[0] = '0';
    buf[1] = 'x';
    for (int i = 0; i < 16; i++) {
        int shift = (15 - i) * 4;
        buf[2 + i] = digits[(value >> shift) & 0xF];
    }
    buf[18] = '\0';
}

/* Prints "label: 0x...." on its own line -- the format used throughout the
 * exception handler to dump register values. */
void vga_print_kv(const char *label, uint64_t value)
{
    char line[64];
    int pos = 0;

    while (*label && pos < 40) {
        line[pos++] = *label++;
    }
    line[pos++] = ':';
    line[pos++] = ' ';

    char hex[19];
    uint64_to_hex(value, hex);
    for (int i = 0; hex[i]; i++) {
        line[pos++] = hex[i];
    }
    line[pos] = '\0';

    vga_print_line(line);
}