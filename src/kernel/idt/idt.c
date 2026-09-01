#include <stdint.h>

#include "../memory/string.h"

struct idt_entry {
    uint16_t offset_1; // 16 lower bits of the offset
    uint16_t segment_selector;
    uint8_t ist; // bits 0-2 ist; bits 7-3 are 0 (reserved)
    uint8_t type_attributes;
    uint16_t offset_2;
    uint32_t offset_3;
    uint32_t zeros; // reserved

} __attribute__((packed));

struct idt_ptr
{
    unsigned short limit;
    void* base;
} __attribute__((packed));

static struct idt_entry _idt[256];
struct idt_ptr _idtp;

extern void _idt_load();

void idt_set_gate(unsigned char num, uint64_t offset, uint16_t sel, uint8_t flags)
{
    _idt[num].type_attributes = flags;
    _idt[num].ist = 0;
    _idt[num].zeros = 0;
    _idt[num].segment_selector = sel;

    _idt[num].offset_1 = (uint16_t)offset;
    _idt[num].offset_2 = (uint16_t)(offset >> 16);
    _idt[num].offset_3 = (uint32_t)(offset >> 32);
}

#pragma region ISR_DECLARATIONS

extern void isr0(void);
extern void isr1(void);
extern void isr2(void);
extern void isr3(void);
extern void isr4(void);
extern void isr5(void);
extern void isr6(void);
extern void isr7(void);
extern void isr8(void);
extern void isr9(void);
extern void isr10(void);
extern void isr11(void);
extern void isr12(void);
extern void isr13(void);
extern void isr14(void);
extern void isr15(void);
extern void isr16(void);
extern void isr17(void);
extern void isr18(void);
extern void isr19(void);
extern void isr20(void);
extern void isr21(void);
extern void isr22(void);
extern void isr23(void);
extern void isr24(void);
extern void isr25(void);
extern void isr26(void);
extern void isr27(void);
extern void isr28(void);
extern void isr29(void);
extern void isr30(void);
extern void isr31(void);

#pragma endregion

void (*isr_tables[256])(void) = {
    isr0,
    isr1,
    isr2,
    isr3,
    isr4,
    isr5,
    isr6,
    isr7,
    isr8,
    isr9,
    isr10,
    isr11,
    isr12,
    isr13,
    isr14,
    isr15,
    isr16,
    isr17,
    isr18,
    isr19,
    isr20,
    isr21,
    isr22,
    isr23,
    isr24,
    isr25,
    isr26,
    isr27,
    isr28,
    isr29,
    isr30,
    isr31
};

void idt_install()
{
    _idtp.limit = (sizeof(struct idt_entry) * 256) - 1;
    _idtp.base = &_idt;

    memset(&_idt, 0, sizeof(struct idt_entry) * 256);

    for(int i = 0; i < 32; ++i)
    {
        idt_set_gate(i, (uint64_t)isr_tables[i], 0x08, 0b10001110); // Non initialized idts (as if I implemented nothing)
    }

    _idt_load();
}