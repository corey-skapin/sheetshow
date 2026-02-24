#include "windows_ink_plugin.h"

// Windows Ink API headers
#include <commctrl.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <optional>

// T065 + T066: Win32 platform channel plugin with palm rejection.
// Subclasses the Flutter window to intercept WM_POINTER events.
// Filters PT_TOUCH events when a pen pointer is in proximity.

namespace windows_ink_plugin {

namespace {
// The method channel name for ink data
constexpr auto kChannelName = "sheetshow/ink";
constexpr auto kEventChannelName = "sheetshow/ink/events";

// Subclass ID for SetWindowSubclass
constexpr UINT_PTR kSubclassId = 1001;
}  // namespace

// Global event sink for streaming ink events to Dart
std::optional<std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>>
    g_event_sink;

// static
void WindowsInkPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<WindowsInkPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

WindowsInkPlugin::WindowsInkPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  // Register method channel
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  // Register event channel for streaming ink events
  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), kEventChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [](const flutter::EncodableValue* arguments,
         std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        g_event_sink = std::move(events);
        return nullptr;
      },
      [](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        g_event_sink = std::nullopt;
        return nullptr;
      });

  event_channel->SetStreamHandler(std::move(handler));

  // Subclass the Flutter window to intercept WM_POINTER messages
  HWND hwnd = registrar->GetView()->GetNativeWindow();
  SetWindowSubclass(hwnd, WndSubclassProc, kSubclassId,
                    reinterpret_cast<DWORD_PTR>(this));
}

WindowsInkPlugin::~WindowsInkPlugin() {
  // Remove subclass on destruction
  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  RemoveWindowSubclass(hwnd, WndSubclassProc, kSubclassId);
}

void WindowsInkPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "isInkSupported") {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

// static
LRESULT CALLBACK WindowsInkPlugin::WndSubclassProc(HWND hWnd, UINT uMsg,
                                                    WPARAM wParam,
                                                    LPARAM lParam,
                                                    UINT_PTR uIdSubclass,
                                                    DWORD_PTR dwRefData) {
  if (uMsg == WM_POINTER || uMsg == WM_POINTERUPDATE ||
      uMsg == WM_POINTERUP) {
    UINT32 pointerId = GET_POINTERID_WPARAM(wParam);

    // T066: Palm rejection — only forward PT_PEN events
    POINTER_INPUT_TYPE pointerType;
    if (!GetPointerType(pointerId, &pointerType)) {
      return DefSubclassProc(hWnd, uMsg, wParam, lParam);
    }
    if (pointerType != PT_PEN) {
      // Reject non-pen input (touch/palm)
      return DefSubclassProc(hWnd, uMsg, wParam, lParam);
    }

    // Read pen-specific data
    POINTER_PEN_INFO penInfo;
    if (!GetPointerPenInfo(pointerId, &penInfo)) {
      return DefSubclassProc(hWnd, uMsg, wParam, lParam);
    }

    // Normalise pressure to [0,1]
    const double pressure =
        static_cast<double>(penInfo.pressure) / 1024.0;

    // Tilt X/Y in degrees [-90, 90]
    const double tiltX = static_cast<double>(penInfo.tiltX) / 90.0;
    const double tiltY = static_cast<double>(penInfo.tiltY) / 90.0;

    // Get position in window coordinates
    POINT pt = penInfo.pointerInfo.ptPixelLocation;
    ScreenToClient(hWnd, &pt);

    const bool isDown = IS_POINTER_INCONTACT_WPARAM(wParam);
    const bool isUp = (uMsg == WM_POINTERUP);

    // Send event to Dart via EventChannel
    if (g_event_sink.has_value() && g_event_sink.value() != nullptr) {
      flutter::EncodableMap event{
          {flutter::EncodableValue("type"),
           flutter::EncodableValue(isUp ? "up" : isDown ? "down" : "move")},
          {flutter::EncodableValue("x"),
           flutter::EncodableValue(static_cast<double>(pt.x))},
          {flutter::EncodableValue("y"),
           flutter::EncodableValue(static_cast<double>(pt.y))},
          {flutter::EncodableValue("pressure"),
           flutter::EncodableValue(pressure)},
          {flutter::EncodableValue("tiltX"),
           flutter::EncodableValue(tiltX)},
          {flutter::EncodableValue("tiltY"),
           flutter::EncodableValue(tiltY)},
      };
      g_event_sink.value()->Success(flutter::EncodableValue(event));
    }
  }

  return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

}  // namespace windows_ink_plugin
