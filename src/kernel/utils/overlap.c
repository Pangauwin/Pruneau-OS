#include "overlap.h"

bool_t overlaps(uint64_t a, uint64_t size_a, uint64_t b, uint64_t size_b)
{
    return a < b + size_b && b < a + size_a;
}
