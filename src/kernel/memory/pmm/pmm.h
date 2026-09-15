#ifndef PMM_H

#define PMM_H

#include <stdint.h>

extern uint32_t begin_ard_addr;
extern uint8_t entry_count;
extern uint8_t entry_size;

typedef struct address_range_descriptor{
    uint32_t base_addr_lo;
    uint32_t base_addr_hi;
    uint32_t length_lo;
    uint32_t length_hi;
    uint32_t type;
    uint32_t extended_attributes;
} __attribute__((packed)) address_range_descriptor; 

void init_memory(void);
#endif