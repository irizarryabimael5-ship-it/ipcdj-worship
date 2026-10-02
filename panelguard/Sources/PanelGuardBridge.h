#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int PGDisplayPowerAPISupported(void);
int PGRequestDisplayIdle(int shouldSleep);

#ifdef __cplusplus
}
#endif
