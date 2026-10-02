#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int PGRawBacklightAPISupported(uint32_t displayID);

int PGRawBrightnessGet(uint32_t displayID,
                       int32_t *value,
                       int32_t *minValue,
                       int32_t *maxValue);
int PGRawBrightnessSet(uint32_t displayID, int32_t value);

int PGLinearBrightnessGet(uint32_t displayID,
                          int32_t *value,
                          int32_t *minValue,
                          int32_t *maxValue);
int PGLinearBrightnessSet(uint32_t displayID, int32_t value);

int PGCommitDisplayParameters(uint32_t displayID);
int PGWakeLogicalDisplay(void);

#ifdef __cplusplus
}
#endif
