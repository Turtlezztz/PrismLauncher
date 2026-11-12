# Prism Launcher — Modern UI (Qt Quick)

A new frontend for Prism Launcher written in QML on top of the existing C++ core.
It replaces the widget-based `MainWindow`, `InstanceWindow` and the global settings dialog.
The classic UI is still compiled in. To get it back, set `UseClassicUI=true` in the config or run with `PRISM_CLASSIC_UI=1`.

## Why Qt Quick?
- It reuses 100% of Prism's backend: auth, launch, mod platforms, Java and metadata. Nothing is rewritten.
- The scene graph is GPU-accelerated, so animations stay smooth while using far less memory than Electron.
- It ships as one native binary with no extra runtime.

## Layout
```
ui/modern/
  CMakeLists.txt         globs everything below (no manual registration needed)
  *.cpp / *.h            C++ bridges exposed to QML via QML_ELEMENT / QML_SINGLETON
  <area>/*.cpp/*.h       per-feature bridges (instance/, settings/, accounts/, newinstance/, resources/...)
  qml/Main.qml           window + sidebar + StackView + global hosts
  qml/singletons/        Theme, Router, Toasts, Dialogs, InstanceActions   (pragma Singleton)
  qml/components/        shared design-system components (P* prefix)
  qml/pages/<Name>Page.qml  top-level pages reachable via Router
  qml/pages/<area>/      sub-pages / tabs of a feature area
  qml/dialogs/           modal dialogs (PDialog based)
  qml/icons/*.svg        Lucide icons (ISC). Use `Icon { name: "play" }`. Add more from
                         https://cdn.jsdelivr.net/npm/lucide-static@0.460.0/icons/<name>.svg
```
QML type names = file basenames. **They must be unique across the whole module.** Prefix area-specific files (e.g. `InstModsTab.qml`, `SettingsJavaPage.qml`).

## Core ↔ frontend
- `ModernFrontendInterface.h` (in Launcher_logic) is implemented by `ModernFrontend` (`Shell` singleton in QML).
- `Application::showMainWindow/showInstanceWindow/ShowGlobalSettings/showLogWindow` and URL imports are routed to it.
- First-run setup steps are exposed as `Shell.setupSteps`, and `Main.qml` routes to the `Onboarding` page.
- C++ bridges access the core through `APPLICATION->...`, the same way the classic pages do.
- When a core class shows widget dialogs itself (e.g. `LaunchController`, `InstanceImportTask`), add a small hook so the modern UI handles the interaction in QML. Keep the classic path working.

## Design rules
- All colors, radii, spacing, font sizes and **animation durations** come from `Theme`. Never hardcode them. Use `Theme.dur*`, which drop to 0 when reduce-motion is on.
- Animate only cheap properties (opacity, x/y, scale, color). No continuous animations unless something is actually happening, e.g. a spinner while loading.
- Use `PButton`, `IconButton`, `PTextField`, `SearchField`, `PComboBox`, `PSwitch`, `PCheckBox`, `PRadioButton`, `PSlider`, `PSpinBox`, `PTextArea`, `PMenu`/`PMenuItem`, `PDialog`, `Card`, `Badge`, `PTabBar`, `SegmentedControl`, `FormRow`, `SectionHeader`, `EmptyState`, `PageScaffold`, `PProgressBar`, `Spinner`, `PToolTip`, `PScrollBar`.
- Use `Dialogs.confirm/prompt/message` for simple dialogs, `Toasts.show(msg, kind, action)` for feedback, and `Router.go/push/back` for navigation.
- Text is English only. Wrap it in `qsTr()` anyway.
- **Never name a QML property `onSomething`.** QML parses names like that as signal handlers.

## Build & visual test
```
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH="/opt/homebrew/opt/qt;/opt/homebrew/opt/libarchive;/opt/homebrew/opt/zlib" \
  -DJava_JAVAC_EXECUTABLE=/opt/homebrew/opt/openjdk@17/bin/javac -DJava_JAR_EXECUTABLE=/opt/homebrew/opt/openjdk@17/bin/jar \
  -DENABLE_LTO=OFF -DBUILD_TESTING=OFF -DLauncher_ENABLE_UPDATER=OFF
ninja -C build
tools/modern-ui/make-test-data.sh /tmp/prism-test
tools/modern-ui/shot.sh build /tmp/prism-test /tmp/shot.png Settings   # screenshot of a page + QML warnings
```
`PRISM_MODERN_PAGE=<Page>` opens a page at startup. `PRISM_MODERN_SCREENSHOT=<png>` grabs the window and quits.
