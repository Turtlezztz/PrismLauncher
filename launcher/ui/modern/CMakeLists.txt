# Prism Launcher — modern Qt Quick frontend
#
# Everything in this directory is picked up automatically:
#   *.cpp / *.h            -> C++ bridge classes (use QML_ELEMENT / QML_SINGLETON to expose them)
#   qml/**/*.qml           -> QML types (file basename == type name, must be unique)
#   qml/singletons/*.qml   -> QML singletons (must start with `pragma Singleton`)
#   qml/icons/*.svg        -> icons, usable via `Icon { name: "play" }`
#
# Re-run cmake (or just build; CONFIGURE_DEPENDS handles it) after adding files.

set(CMAKE_AUTOMOC ON)

file(GLOB_RECURSE MODERN_CPP CONFIGURE_DEPENDS
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/*.h)
file(GLOB_RECURSE MODERN_QML CONFIGURE_DEPENDS
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml)
file(GLOB_RECURSE MODERN_SINGLETONS CONFIGURE_DEPENDS
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/singletons/*.qml)
file(GLOB_RECURSE MODERN_ASSETS CONFIGURE_DEPENDS
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/icons/*.svg
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/assets/*)

set_source_files_properties(${MODERN_SINGLETONS} PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_library(Launcher_modern STATIC)
qt_add_qml_module(Launcher_modern
    URI PrismModern
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    SOURCES ${MODERN_CPP}
    QML_FILES ${MODERN_QML}
    RESOURCES ${MODERN_ASSETS}
)

target_include_directories(Launcher_modern PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
# the generated QML type registration includes headers by file name only, so every bridge sub-directory
# (instance/, newinstance/, ...) has to be on the include path
set(MODERN_BRIDGE_DIRS "")
foreach(src ${MODERN_CPP})
    get_filename_component(dir ${CMAKE_CURRENT_SOURCE_DIR}/${src} DIRECTORY)
    list(APPEND MODERN_BRIDGE_DIRS ${dir})
endforeach()
list(REMOVE_DUPLICATES MODERN_BRIDGE_DIRS)
target_include_directories(Launcher_modern PRIVATE ${MODERN_BRIDGE_DIRS})
target_link_libraries(Launcher_modern PUBLIC
    Launcher_logic
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Svg
)
