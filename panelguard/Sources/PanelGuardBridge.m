#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import "PanelGuardBridge.h"

static io_registry_entry_t pgDisplayWrangler(void) {
    return IORegistryEntryFromPath(
        kIOMasterPortDefault,
        "IOService:/IOResources/IODisplayWrangler"
    );
}

int PGDisplayPowerAPISupported(void) {
    io_registry_entry_t entry = pgDisplayWrangler();
    if (entry == MACH_PORT_NULL) return 0;
    IOObjectRelease(entry);
    return 1;
}

int PGRequestDisplayIdle(int shouldSleep) {
    io_registry_entry_t entry = pgDisplayWrangler();
    if (entry == MACH_PORT_NULL) return 1;

    CFBooleanRef value = shouldSleep ? kCFBooleanTrue : kCFBooleanFalse;
    kern_return_t result = IORegistryEntrySetCFProperty(
        entry,
        CFSTR("IORequestIdle"),
        value
    );

    IOObjectRelease(entry);
    return result == KERN_SUCCESS ? 0 : (int)result;
}
