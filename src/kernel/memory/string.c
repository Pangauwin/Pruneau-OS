#include "string.h"

void* memset(void *ptr, int val, unsigned long size)
{
    for (unsigned long i = 0; i < size; ++i) {
    *(char*)(ptr + i) = (char)val;
        }

    return ptr;
}

void* memcpy(void *b, void *a, unsigned long size)
{
    for(unsigned long i = 0; i < size; ++i)
        {
    *(char*)(b + i) = *(char*)(a + i);
        }

    return b;
}

void* memmove(void* to, const void* from, unsigned long size)
{
    if(to == from) return to;
    else if (to < from)
    {
        for(unsigned long i = 0; i < size; ++i)
        {
            *(char*)(to + i) = *(char*)(from + i);
        }
    }
    else {
        void* end_to = to + size - 1;
        const void* end_from = from + size - 1;

        for(unsigned long i = 0; i < size; ++i)
        {
            *(char*)(end_to - i) = *(char*)(end_from - i);
        }
    }

    return to;
}

int memcmp(void* a, void* b, unsigned long size)
{
    for(unsigned long i = 0; i < size; ++i)
    {
        if(*(unsigned char*)(a + i) == *(unsigned char*)(b + i)) continue;
        else if(*(unsigned char*)(a + i) > *(unsigned char*)(b + i)) return 1;
        else return -1;
    }

    return 0;
}