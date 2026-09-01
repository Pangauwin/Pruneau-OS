#ifndef STRING_HEADER
#define STRING_HEADER

void* memset(void *ptr, int val, unsigned long size);
void* memcpy(void *b, void *a, unsigned long size);
void* memmove(void* to, const void* from, unsigned long size);
int memcmp(void* a, void* b, unsigned long size);


#endif