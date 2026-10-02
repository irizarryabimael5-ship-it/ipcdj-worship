#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <unistd.h>
#import "PanelGuardBridge.h"

static SEL pgSel(const char *name) { return sel_registerName(name); }

static BOOL pgMakeDisplayIndependent(CGDirectDisplayID virtualID,
                                     CGDirectDisplayID previousMain) {
    CGDisplayConfigRef config = NULL;
    if (CGBeginDisplayConfiguration(&config) != kCGErrorSuccess || !config) {
        return NO;
    }

    // A newly created virtual display can inherit a stale mirroring preference.
    // Removing the virtual display from the mirror set is safe and session-scoped.
    if (CGDisplayIsInMirrorSet(virtualID)) {
        CGError mirrorErr = CGConfigureDisplayMirrorOfDisplay(
            config,
            virtualID,
            kCGNullDirectDisplay
        );
        if (mirrorErr != kCGErrorSuccess) {
            CGCancelDisplayConfiguration(config);
            return NO;
        }
    }

    // If WindowServer unexpectedly promoted the virtual display to main,
    // restore the previous main display to the canonical 0,0 origin.
    if (CGMainDisplayID() == virtualID &&
        previousMain != kCGNullDirectDisplay &&
        previousMain != virtualID) {
        CGError originErr = CGConfigureDisplayOrigin(config, previousMain, 0, 0);
        if (originErr != kCGErrorSuccess) {
            CGCancelDisplayConfiguration(config);
            return NO;
        }
    }

    CGError complete = CGCompleteDisplayConfiguration(config, kCGConfigureForAppOnly);
    if (complete != kCGErrorSuccess) return NO;

    usleep(150000);
    return CGDisplayIsInMirrorSet(virtualID) == 0;
}

int PGVirtualDisplayAPISupported(void) {
    return NSClassFromString(@"CGVirtualDisplay") &&
           NSClassFromString(@"CGVirtualDisplayDescriptor") &&
           NSClassFromString(@"CGVirtualDisplaySettings") &&
           NSClassFromString(@"CGVirtualDisplayMode");
}

void *PGCreateVirtualDisplay(uint32_t pixelWidth,
                             uint32_t pixelHeight,
                             double refreshRate,
                             uint32_t vendorID,
                             uint32_t productID,
                             uint32_t serialNum,
                             uint32_t *outDisplayID) {
    @autoreleasepool {
        if (!PGVirtualDisplayAPISupported() || pixelWidth == 0 || pixelHeight == 0) {
            return NULL;
        }

        CGDirectDisplayID previousMain = CGMainDisplayID();

        Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
        Class displayClass = NSClassFromString(@"CGVirtualDisplay");
        Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
        Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");

        id descriptor = ((id (*)(id, SEL))objc_msgSend)(
            ((id (*)(id, SEL))objc_msgSend)((id)descriptorClass, pgSel("alloc")),
            pgSel("init")
        );
        if (!descriptor) return NULL;

        ((void (*)(id, SEL, dispatch_queue_t))objc_msgSend)(
            descriptor, pgSel("setDispatchQueue:"), dispatch_get_main_queue()
        );
        ((void (*)(id, SEL, id))objc_msgSend)(
            descriptor, pgSel("setName:"), @"PanelGuard Remote Display"
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setMaxPixelsWide:"), pixelWidth
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setMaxPixelsHigh:"), pixelHeight
        );
        ((void (*)(id, SEL, CGSize))objc_msgSend)(
            descriptor, pgSel("setSizeInMillimeters:"), CGSizeMake(597.0, 336.0)
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setVendorID:"), vendorID
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setProductID:"), productID
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setSerialNum:"), serialNum
        );

        if ([descriptor respondsToSelector:pgSel("setTerminationHandler:")]) {
            void (^handler)(id, id) = ^(id a, id b) {
                _exit(0);
            };
            ((void (*)(id, SEL, id))objc_msgSend)(
                descriptor, pgSel("setTerminationHandler:"), handler
            );
        }

        id displayAlloc = ((id (*)(id, SEL))objc_msgSend)(
            (id)displayClass, pgSel("alloc")
        );
        id display = ((id (*)(id, SEL, id))objc_msgSend)(
            displayAlloc, pgSel("initWithDescriptor:"), descriptor
        );
        if (!display) return NULL;

        id modeAlloc = ((id (*)(id, SEL))objc_msgSend)(
            (id)modeClass, pgSel("alloc")
        );
        id mode = ((id (*)(id, SEL, NSUInteger, NSUInteger, CGFloat))objc_msgSend)(
            modeAlloc,
            pgSel("initWithWidth:height:refreshRate:"),
            (NSUInteger)pixelWidth,
            (NSUInteger)pixelHeight,
            (CGFloat)refreshRate
        );
        if (!mode) return NULL;

        id settings = ((id (*)(id, SEL))objc_msgSend)(
            ((id (*)(id, SEL))objc_msgSend)((id)settingsClass, pgSel("alloc")),
            pgSel("init")
        );
        if (!settings) return NULL;

        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            settings, pgSel("setHiDPI:"), 1
        );
        ((void (*)(id, SEL, id))objc_msgSend)(
            settings, pgSel("setModes:"), @[mode]
        );

        BOOL applied = ((BOOL (*)(id, SEL, id))objc_msgSend)(
            display, pgSel("applySettings:"), settings
        );
        if (!applied) return NULL;

        uint32_t displayID = ((uint32_t (*)(id, SEL))objc_msgSend)(
            display, pgSel("displayID")
        );
        if (displayID == 0) return NULL;

        if (!pgMakeDisplayIndependent(displayID, previousMain)) {
            return NULL;
        }

        if (outDisplayID) *outDisplayID = displayID;
        return (__bridge_retained void *)display;
    }
}

void PGDestroyVirtualDisplay(void *handle) {
    if (!handle) return;
    @autoreleasepool {
        id display = (__bridge_transfer id)handle;
        (void)display;
    }
}
