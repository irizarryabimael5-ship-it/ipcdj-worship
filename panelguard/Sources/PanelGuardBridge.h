#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int PGVirtualDisplayAPISupported(void);
void *PGCreateVirtualDisplay(uint32_t pixelWidth,
                             uint32_t pixelHeight,
                             double refreshRate,
                             uint32_t *outDisplayID);
void PGDestroyVirtualDisplay(void *handle);

#ifdef __cplusplus
}
#endif
