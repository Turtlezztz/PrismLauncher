#include "MacWindowStyle.h"

#include <QtGlobal>

#ifndef Q_OS_MACOS
namespace MacWindowStyle {
void integrateTitleBar(QWindow*) {}
}  // namespace MacWindowStyle
#endif
