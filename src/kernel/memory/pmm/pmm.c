#include "pmm.h"

#include <stdint.h>

#include "../../types.h"
#include "../../utils/overlap.h"

#define MAX_TRACKED_PAGES 4096
#define MEMORY_PAGE_SIZE 4096

static address_range_descriptor* memory_descriptors;

extern uint8_t _kernel_start[];
extern uint8_t _kernel_end[];

static uint64_t kernel_start;
static uint64_t kernel_size;

/* 
    Memory pages

    Memory will be split in 4kb pages
*/
typedef struct memory_page {
    uint64_t phys_adress;
} memory_page;

static memory_page memory_pages[MAX_TRACKED_PAGES];
static uint64_t freed_memory_pages_address[MAX_TRACKED_PAGES];
static uint64_t next_memory_page_address;
static uint32_t memory_pages_size;
static uint32_t freed_memory_pages_address_size;

static uint64_t last_address;

bool_t is_memory_page_available(uint64_t address)
{
    if(overlaps(address, MEMORY_PAGE_SIZE, kernel_start, kernel_size))
    {
        return FALSE;   
    }

    if(overlaps(address, MEMORY_PAGE_SIZE, begin_ard_addr, entry_size * entry_count))
    {
        return FALSE;   
    }

    for (int i = 0; i < entry_count; ++i) {
        uint64_t memory_descriptor_base_address = memory_descriptors[i].base_addr_lo | ((uint64_t)memory_descriptors[i].base_addr_hi << 32); 
        uint64_t memory_descriptor_length= memory_descriptors[i].length_lo | ((uint64_t)memory_descriptors[i].length_hi << 32); 
        if(overlaps(address, MEMORY_PAGE_SIZE, memory_descriptor_base_address, memory_descriptor_length))
        {
            if(memory_descriptors[i].type != 1) return FALSE;

            for(int j = 0; j < memory_pages_size; ++j)
            {
                if(overlaps(address, MEMORY_PAGE_SIZE, memory_pages[j].phys_adress, MEMORY_PAGE_SIZE))
                {
                    return FALSE;
                }
            }

            return TRUE;
        }
    }

    // case where address is outside of memory descriptors bounds
    return FALSE;
}

void init_memory(void)
{
    memory_descriptors = (address_range_descriptor*)begin_ard_addr; // Legit warning as we initialize the ard addresses when we are still in 16-bit real mode
    
    kernel_start = (uint64_t)_kernel_start;
    kernel_size = (uint64_t)_kernel_end - kernel_start;

    memory_pages_size = 0;

    for (int i = 0; i < entry_count; ++i) {
        if(memory_descriptors[i].type != 1) continue;
        uint64_t memory_descriptor_base_address = memory_descriptors[i].base_addr_lo | ((uint64_t)memory_descriptors[i].base_addr_hi << 32); 

        if(is_memory_page_available(memory_descriptor_base_address))
        {
            next_memory_page_address = memory_descriptor_base_address;

            if(next_memory_page_address == 0) next_memory_page_address = MEMORY_PAGE_SIZE; // Just in case the first address is 0, I would like to make sure that doesn't cause allocate_new_page to break
        
            break;
        }
    }

    uint64_t max_address = 0;
    uint64_t max_length = 0;

    for (int i = 0; i < entry_count; ++i) { // Skipping the first entry as it would be the one referenced just up
        uint64_t memory_descriptor_addr = memory_descriptors[i].base_addr_lo | ((uint64_t)memory_descriptors[i].base_addr_hi << 32);
        if(memory_descriptor_addr > max_address)
        {
            max_address = memory_descriptor_addr;
            max_length = memory_descriptors[i].length_lo | ((uint64_t)memory_descriptors[i].length_hi << 32);
        }
    }

    last_address = max_address + max_length;
}


uint64_t get_next_available_memory_page_address()
{
    if(is_memory_page_available(next_memory_page_address + MEMORY_PAGE_SIZE))
    {
        return next_memory_page_address + MEMORY_PAGE_SIZE;
    }

    uint64_t next_address = next_memory_page_address + 2 * MEMORY_PAGE_SIZE;

    while(!is_memory_page_available(next_address))
    {
        next_address += MEMORY_PAGE_SIZE;

        if(next_address > last_address) return 0;
    }

    return next_address;
}

uint64_t allocate_new_page()
{
    if(memory_pages_size >= MAX_TRACKED_PAGES || next_memory_page_address == 0) return 0;

    if(freed_memory_pages_address_size > 0)
    {
        memory_pages[memory_pages_size].phys_adress = freed_memory_pages_address[freed_memory_pages_address_size - 1];
        freed_memory_pages_address_size -= 1;

        memory_pages_size += 1;
        return memory_pages[memory_pages_size - 1].phys_adress;
    }

    memory_pages[memory_pages_size].phys_adress = next_memory_page_address;
    next_memory_page_address = get_next_available_memory_page_address();
    memory_pages_size += 1;

    return memory_pages[memory_pages_size - 1].phys_adress;
}

void free_memory_page(uint64_t address)
{
    for (int i = 0; i < memory_pages_size; ++i) {
        if(memory_pages[i].phys_adress == address)
        {
            if(freed_memory_pages_address_size < MAX_TRACKED_PAGES)
            {
                freed_memory_pages_address[freed_memory_pages_address_size] = address;
                freed_memory_pages_address_size += 1;
            }

            for(int j = i + 1; j < memory_pages_size; ++j)
            {
                memory_pages[j-1].phys_adress = memory_pages[j].phys_adress;
            }
            memory_pages_size -= 1;
            break;
        }
    }
}