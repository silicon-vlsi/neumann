/* minimal string.h for the -nostdlib FreeRTOS build; functions in programs/libc_stub.c */
#ifndef NEUMANN_STRING_H
#define NEUMANN_STRING_H
#include <stddef.h>
void *memset(void *d, int c, size_t n);
void *memcpy(void *d, const void *s, size_t n);
void *memmove(void *d, const void *s, size_t n);
int   memcmp(const void *a, const void *b, size_t n);
#endif
