#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int PGDisplayPowerAPISupported(void);
int PGRequestDisplayIdle(int shouldSleep);
int PGWakeDisplay(void);

#ifdef __cplusplus
}
#endif
