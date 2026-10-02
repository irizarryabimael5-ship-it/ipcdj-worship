#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "PanelGuardBridge.h"

static SEL pgSel(const char *name) { return sel_registerName(name); }

int PGVirtualDisplayAPISupported(void) {
    return NSClassFromString(@"CGVirtualDisplay") &&
           NSClassFromString(@"CGVirtualDisplayDescriptor") &&
           NSClassFromString(@"CGVirtualDisplaySettings") &&
           NSClassFromString(@"CGVirtualDisplayMode");
}

void *PGCreateVirtualDisplay(uint32_t pixelWidth,
                             uint32_t pixelHeight,
                             double refreshRate,
                             uint32_t *outDisplayID) {
    @autoreleasepool {
        if (!PGVirtualDisplayAPISupported() || pixelWidth == 0 || pixelHeight == 0) {
            return NULL;
        }

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

        CGSize mm = CGSizeMake(597.0, 336.0);
        ((void (*)(id, SEL, CGSize))objc_msgSend)(
            descriptor, pgSel("setSizeInMillimeters:"), mm
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setVendorID:"), 0x5047
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setProductID:"), 0x0002
        );
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(
            descriptor, pgSel("setSerialNum:"), 0x00010002
        );

        id displayAlloc = ((id (*)(id, SEL))objc_msgSend)((id)displayClass, pgSel("alloc"));
        id display = ((id (*)(id, SEL, id))objc_msgSend)(
            displayAlloc, pgSel("initWithDescriptor:"), descriptor
        );
        if (!display) return NULL;

        id modeAlloc = ((id (*)(id, SEL))objc_msgSend)((id)modeClass, pgSel("alloc"));
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
        NSArray *modes = @[mode];
        ((void (*)(id, SEL, id))objc_msgSend)(
            settings, pgSel("setModes:"), modes
        );

        BOOL applied = ((BOOL (*)(id, SEL, id))objc_msgSend)(
            display, pgSel("applySettings:"), settings
        );
        if (!applied) return NULL;

        uint32_t displayID = ((uint32_t (*)(id, SEL))objc_msgSend)(
            display, pgSel("displayID")
        );
        if (displayID == 0) return NULL;

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
