cmake_minimum_required(VERSION 3.14)

# Windows Ink platform channel plugin for SheetShow.
# Hooks WM_POINTER messages to deliver pressure, tilt, and palm-rejection data
# to Flutter via MethodChannel("sheetshow/ink").

set(PLUGIN_NAME "windows_ink_plugin")

add_library(${PLUGIN_NAME} STATIC
  windows_ink_plugin.cpp
)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}"
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
