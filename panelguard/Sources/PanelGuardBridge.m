#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "PanelGuardBridge.h"

extern io_service_t CGDisplayIOServicePort(CGDirectDisplayID display)
    __attribute__((weak_import));

static io_service_t pgServiceForDisplay(uint32_t displayID) {
    if (CGDisplayIOServicePort == NULL) return MACH_PORT_NULL;
    return CGDisplayIOServicePort((CGDirectDisplayID)displayID);
}

int PGRawBacklightAPISupported(uint32_t displayID) {
    io_service_t service = pgServiceForDisplay(displayID);
    if (service == MACH_PORT_NULL) return 0;

    SInt32 value = 0, minValue = 0, maxValue = 0;
    IOReturn result = IODisplayGetIntegerRangeParameter(
        service,
        kNilOptions,
        CFSTR(kIODisplayBrightnessKey),
        &value,
        &minValue,
        &maxValue
    );

    return result == kIOReturnSuccess ? 1 : 0;
}

int PGRawBrightnessGet(uint32_t displayID,
                       int32_t *value,
                       int32_t *minValue,
                       int32_t *maxValue) {
    io_service_t service = pgServiceForDisplay(displayID);
    if (service == MACH_PORT_NULL) return (int)kIOReturnUnsupported;

    SInt32 v = 0, minV = 0, maxV = 0;
    IOReturn result = IODisplayGetIntegerRangeParameter(
        service,
        kNilOptions,
        CFSTR(kIODisplayBrightnessKey),
        &v,
        &minV,
        &maxV
    );

    if (result == kIOReturnSuccess) {
        if (value) *value = v;
        if (minValue) *minValue = minV;
        if (maxValue) *maxValue = maxV;
    }

    return (int)result;
}

int PGRawBrightnessSet(uint32_t displayID, int32_t value) {
    io_service_t service = pgServiceForDisplay(displayID);
    if (service == MACH_PORT_NULL) return (int)kIOReturnUnsupported;

    IOReturn result = IODisplaySetIntegerParameter(
        service,
        kNilOptions,
        CFSTR(kIODisplayBrightnessKey),
        (SInt32)value
    );

    return (int)result;
}

int PGLinearBrightnessGet(uint32_t displayID,
                          int32_t *value,
                          int32_t *minValue,
                          int32_t *maxValue) {
    io_service_t service = pgServiceForDisplay(displayID);
    if (service == MACH_PORT_NULL) return (int)kIOReturnUnsupported;

    SInt32 v = 0, minV = 0, maxV = 0;
    IOReturn result = IODisplayGetIntegerRangeParameter(
        service,
        kNilOptions,
        CFSTR(kIODisplayLinearBrightnessKey),
        &v,
        &minV,
        &maxV
    );

    if (result == kIOReturnSuccess) {
        if (value) *value = v;
        if (minValue) *minValue = minV;
        if (maxValue) *maxValue = maxV;
    }

    return (int)result;
}

int PGLinearBrightnessSet(uint32_t displayID, int32_t value) {
    io_service_t service = pgServiceForDisplay(displayID);
    if (service == MACH_PORT_NULL) return (int)kIOReturnUnsupported;

    IOReturn result = IODisplaySetIntegerParameter(
        service,
        kNilOptions,
        CFSTR(kIODisplayLinearBrightnessKey),
        (SInt32)value
    );

    return (int)result;
}

int PGCommitDisplayParameters(uint32_t displayID) {
    io_service_t service = pgServiceForDisplay(displayID);
    if (service == MACH_PORT_NULL) return (int)kIOReturnUnsupported;
    return (int)IODisplayCommitParameters(service, kNilOptions);
}

int PGWakeLogicalDisplay(void) {
    IOPMAssertionID assertionID = kIOPMNullAssertionID;

    IOReturn result = IOPMAssertionDeclareUserActivity(
        CFSTR("PanelGuard logical display wake"),
        kIOPMUserActiveLocal,
        &assertionID
    );

    return result == kIOReturnSuccess ? 0 : (int)result;
}
