#pragma once

class QWindow;

namespace MacWindowStyle {
/// macOS: hide the native title text and make the title bar fully transparent so the QML content
/// (which extends under it via Qt::ExpandedClientAreaHint) looks like one integrated window.
/// No-op on other platforms.
void integrateTitleBar(QWindow* window);
}  // namespace MacWindowStyle
