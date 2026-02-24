#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace windows_ink_plugin {

/// Win32 platform channel plugin for Surface Pen ink input.
/// Reads pressure (0–1024), tilt X/Y, and twist from WM_POINTER messages.
/// Delivers events via MethodChannel("sheetshow/ink") and
/// EventChannel("sheetshow/ink/events").
class WindowsInkPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  WindowsInkPlugin(flutter::PluginRegistrarWindows* registrar);
  virtual ~WindowsInkPlugin();

  // Prevent copying
  WindowsInkPlugin(const WindowsInkPlugin&) = delete;
  WindowsInkPlugin& operator=(const WindowsInkPlugin&) = delete;

 private:
  flutter::PluginRegistrarWindows* registrar_;

  /// Handle MethodChannel calls from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  /// Win32 window subclass procedure — intercepts WM_POINTER messages.
  static LRESULT CALLBACK WndSubclassProc(HWND hWnd, UINT uMsg,
                                           WPARAM wParam, LPARAM lParam,
                                           UINT_PTR uIdSubclass,
                                           DWORD_PTR dwRefData);
};

}  // namespace windows_ink_plugin
