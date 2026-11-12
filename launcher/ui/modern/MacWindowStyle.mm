#include "MacWindowStyle.h"

#include <QGuiApplication>
#include <QWindow>

#import <AppKit/AppKit.h>

namespace MacWindowStyle {
void integrateTitleBar(QWindow* window)
{
    // only the real Cocoa platform has an NSView behind winId() (not "offscreen"/"minimal")
    if (!window || QGuiApplication::platformName() != QLatin1String("cocoa")) {
        return;
    }
    auto* view = reinterpret_cast<NSView*>(window->winId());
    NSWindow* nsWindow = view.window;
    if (!nsWindow) {
        return;
    }
    nsWindow.titleVisibility = NSWindowTitleHidden;
    nsWindow.titlebarAppearsTransparent = YES;
    nsWindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
    // the window background shows during resizes before QML paints; match the app background
    nsWindow.backgroundColor = [NSColor windowBackgroundColor];
}
}  // namespace MacWindowStyle
