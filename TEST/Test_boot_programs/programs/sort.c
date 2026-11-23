// sort.c - insertion sort of SORT_N unsigned words (.data), plus a signed sort of the
// same data (signed compare: slt/blt paths). Results: unsigned sorted, then 8 samples of
// the signed order (first 4, last 4).
#include "test.h"
#include "sort_inputs.h"

static uint32_t u[SORT_N];
static int32_t  s[SORT_N];

uint32_t main(void)
{
  for (int i = 0; i < SORT_N; i++) { u[i] = sort_in[i]; s[i] = (int32_t)sort_in[i]; }
  for (int i = 1; i < SORT_N; i++) {           // unsigned insertion sort
    uint32_t v = u[i]; int j = i - 1;
    while (j >= 0 && u[j] > v) { u[j + 1] = u[j]; j--; }
    u[j + 1] = v;
  }
  for (int i = 1; i < SORT_N; i++) {           // signed insertion sort
    int32_t v = s[i]; int j = i - 1;
    while (j >= 0 && s[j] > v) { s[j + 1] = s[j]; j--; }
    s[j + 1] = v;
  }
  int n = 0;
  for (int i = 0; i < SORT_N; i++) RESULT[n++] = u[i];
  for (int i = 0; i < 4; i++) RESULT[n++] = (uint32_t)s[i];
  for (int i = SORT_N - 4; i < SORT_N; i++) RESULT[n++] = (uint32_t)s[i];
  RESULT_N = n;
  return SIG_PASS;
}
