import Cocoa
import FlutterMacOS

public class MuphoneNativePlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private var engine: MuphoneEngine?

    init(channel: FlutterMethodChannel, eventChannel: FlutterEventChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.eventChannel = eventChannel
        super.init()
        self.engine = MuphoneEngine(registrar: registrar, emitEvent: { [weak self] event in
            DispatchQueue.main.async { self?.eventSink?(event) }
        })
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "muphone_native", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "muphone_native/events", binaryMessenger: registrar.messenger)
        let instance = MuphoneNativePlugin(channel: channel, eventChannel: eventChannel, registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let engine = engine else { result(FlutterError(code: "NOT_INIT", message: "Engine not initialized", details: nil)); return }

        switch call.method {
        case "init":
            let info = engine.initialize()
            result(info)

        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let host = args["host"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing host", details: nil)); return
            }
            let videoPort = args["video_port"] as? Int ?? 28200
            let controlPort = args["control_port"] as? Int ?? 28201
            engine.connect(host: host, videoPort: videoPort, controlPort: controlPort)
            result(true)

        case "disconnect":
            engine.disconnect()
            result(true)

        case "subscribe_device":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["device_id"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing device_id", details: nil)); return
            }
            let w = args["width"] as? Int ?? 1080
            let h = args["height"] as? Int ?? 1920
            let textureId = engine.subscribeDevice(deviceId: deviceId, width: w, height: h)
            if textureId >= 0 {
                result(["texture_id": textureId])
            } else {
                result(FlutterError(code: "SUBSCRIBE_FAILED", message: "Failed to subscribe", details: nil))
            }

        case "unsubscribe_device":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["device_id"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing device_id", details: nil)); return
            }
            engine.unsubscribeDevice(deviceId: deviceId)
            result(true)

        case "send_input":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil)); return
            }
            engine.sendInput(args: args)
            result(true)

        case "set_fps_profile":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["device_id"] as? Int,
                  let profile = args["profile"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil)); return
            }
            engine.setFpsProfile(deviceId: deviceId, profile: profile)
            result(true)

        case "set_window_title":
            if let title = call.arguments as? String {
                NSApp.mainWindow?.title = title
            }
            result(true)

        case "get_window_rect":
            if let window = NSApp.mainWindow ?? NSApp.windows.first {
                let frame = window.frame
                result([
                    "x": Int(frame.origin.x.rounded()),
                    "y": Int(frame.origin.y.rounded()),
                    "width": Int(frame.size.width.rounded()),
                    "height": Int(frame.size.height.rounded())
                ])
            } else {
                result(nil)
            }

        case "set_window_rect":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil)); return
            }
            let x = args["x"] as? Double ?? Double(args["x"] as? Int ?? 0)
            let y = args["y"] as? Double ?? Double(args["y"] as? Int ?? 0)
            let width = args["width"] as? Double ?? Double(args["width"] as? Int ?? 0)
            let height = args["height"] as? Double ?? Double(args["height"] as? Int ?? 0)
            if width > 0, height > 0, let window = NSApp.mainWindow ?? NSApp.windows.first {
                let frame = NSRect(x: x, y: y, width: width, height: height)
                window.setFrame(frame, display: true, animate: false)
            }
            result(true)

        case "set_window_size":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil)); return
            }
            let width = args["width"] as? Double ?? Double(args["width"] as? Int ?? 0)
            let height = args["height"] as? Double ?? Double(args["height"] as? Int ?? 0)
            if width > 0, height > 0, let window = NSApp.mainWindow ?? NSApp.windows.first {
                var frame = window.frame
                frame.size = NSSize(width: width, height: height)
                window.setFrame(frame, display: true, animate: false)
            }
            result(true)

        case "lock_aspect_ratio":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil)); return
            }
            let num = args["num"] as? Double ?? Double(args["num"] as? Int ?? 0)
            let den = args["den"] as? Double ?? Double(args["den"] as? Int ?? 0)
            if num > 0, den > 0, let window = NSApp.mainWindow ?? NSApp.windows.first {
                window.contentAspectRatio = NSSize(width: num, height: den)
            }
            result(true)

        case "get_display_bounds":
            let screen = (NSApp.mainWindow ?? NSApp.windows.first)?.screen ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                result([
                    "x": Int(visible.origin.x.rounded()),
                    "y": Int(visible.origin.y.rounded()),
                    "width": Int(visible.size.width.rounded()),
                    "height": Int(visible.size.height.rounded())
                ])
            } else {
                result(nil)
            }

        case "set_main_window":
            result(true)

        case "confirm_exit":
            NSApp.terminate(nil)
            result(true)

        case "detach_device":
            // macOS: open new window (simplified)
            result(FlutterError(code: "NOT_SUPPORTED", message: "Detach not yet supported on macOS", details: nil))

        case "attach_device":
            result(true)

        case "get_frame_stats":
            result(engine.getFrameStats())

        case "update_cell_rect", "adb_command":
            // Window management - basic stubs for macOS
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension MuphoneNativePlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
