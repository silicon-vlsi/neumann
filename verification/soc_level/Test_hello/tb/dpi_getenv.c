/* DPI stub: getenvval() is imported by the rtl/peripherals rom1p1r / ram1p1rwbe (preload only).
 * Compiled by Verilator (as C++) and by Questa vlog (as C). */
#include <stdlib.h>
#ifdef __cplusplus
extern "C"
#endif
const char* getenvval(const char* n) { const char* v = getenv(n); return v ? v : ""; }
