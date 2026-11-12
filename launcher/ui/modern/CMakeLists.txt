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

# Objective-C++ (macOS window integration)
if(APPLE)
    file(GLOB_RECURSE MODERN_OBJCXX CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/*.mm)
    list(APPEND MODERN_CPP ${MODERN_OBJCXX})
endif()

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
# per-feature subfolders (instance/, settings/, ...) must be include roots too: the generated QML type
# registrations include every QML_ELEMENT header by its bare file name
set(MODERN_SUBDIRS "")
foreach(_src ${MODERN_CPP})
    get_filename_component(_dir ${_src} DIRECTORY)
    if(_dir)
        list(APPEND MODERN_SUBDIRS ${CMAKE_CURRENT_SOURCE_DIR}/${_dir})
    endif()
endforeach()
list(REMOVE_DUPLICATES MODERN_SUBDIRS)
target_include_directories(Launcher_modern PRIVATE ${MODERN_SUBDIRS})
target_link_libraries(Launcher_modern PUBLIC
    Launcher_logic
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Svg
)
if(APPLE)
    target_link_libraries(Launcher_modern PUBLIC "-framework AppKit")
endif()
