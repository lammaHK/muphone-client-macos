import Cocoa
import FlutterMacOS
import VideoToolbox
import CoreVideo

class MuphoneEngine {
    private let registrar: FlutterPluginRegistrar
    private let emitEvent: ([String: Any]) -> Void
    private var textureRegistry: FlutterTextureRegistry?
    private var videoClient: VideoClient?
    private var controlClient: ControlClient?
    private var decoders: [Int: H264Decoder] = [:]
    private var textures: [Int: PixelBufferTexture] = [:]
    private var connected = false

    init(registrar: FlutterPluginRegistrar, emitEvent: @escaping ([String: Any]) -> Void) {
        self.registrar = registrar
        self.emitEvent = emitEvent
        self.textureRegistry = registrar.textures
    }

    func initialize() -> [String: Any] {
        return [
            "adapter": "Apple GPU",
            "vram_mb": 2048
        ]
    }

    func connect(host: String, videoPort: Int, controlPort: Int) {
        disconnect()

        emitEvent(["event": "server_connection_state", "state": "connecting"])

        controlClient = ControlClient(host: host, port: controlPort)
        controlClient?.onMessage = { [weak self] json in
            self?.handleControlMessage(json)
        }
        controlClient?.onDisconnect = { [weak self] in
            self?.connected = false
            self?.emitEvent(["event": "server_connection_state", "state": "disconnected"])
        }

        videoClient = VideoClient(host: host, port: videoPort)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.controlClient?.connect() == true {
                self.connected = true
                self.emitEvent(["event": "server_connection_state", "state": "connected"])
            } else {
                self.emitEvent(["event": "server_connection_state", "state": "disconnected"])
            }
        }
    }

    func disconnect() {
        connected = false
        controlClient?.disconnect()
        controlClient = nil

        for (id, _) in decoders {
            unsubscribeDevice(deviceId: id)
        }

        videoClient?.disconnect()
        videoClient = nil
    }

    func subscribeDevice(deviceId: Int, width: Int, height: Int) -> Int64 {
        guard let textureRegistry = textureRegistry else { return -1 }

        // Create pixel buffer texture for Flutter
        let texture = PixelBufferTexture()
        let textureId = textureRegistry.register(texture)
        textures[deviceId] = texture

        // Create H.264 decoder
        let decoder = H264Decoder { [weak self, weak texture] pixelBuffer in
            guard let self = self, let texture = texture else { return }
            texture.updatePixelBuffer(pixelBuffer)
            DispatchQueue.main.async {
                self.textureRegistry?.textureFrameAvailable(textureId)
            }
        }
        decoders[deviceId] = decoder

        // Start receiving video for this device
        videoClient?.subscribe(deviceId: deviceId) { [weak self] nalData, isConfig, isKeyframe in
            guard let self = self else { return }

            if isConfig {
                let nalType = nalData.count > 4 ? nalData[4] & 0x1F : 0
                if nalType == 7 { // SPS
                    self.decoders[deviceId]?.setSPS(nalData)
                } else if nalType == 8 { // PPS
                    self.decoders[deviceId]?.setPPS(nalData)
                }
                // Also feed to decoder for STREAM_CHANGE handling
                self.decoders[deviceId]?.decode(nalData: nalData)
                return
            }

            self.decoders[deviceId]?.decode(nalData: nalData)
        }

        return textureId
    }

    func unsubscribeDevice(deviceId: Int) {
        videoClient?.unsubscribe(deviceId: deviceId)

        if let texture = textures[deviceId] {
            textureRegistry?.unregisterTexture(texture.textureId ?? 0)
        }
        textures.removeValue(forKey: deviceId)
        decoders.removeValue(forKey: deviceId)
    }

    func sendInput(args: [String: Any]) {
        guard connected, let controlClient = controlClient else { return }
        guard let type = args["type"] as? String else { return }

        var msg: [String: Any] = [:]

        switch type {
        case "key":
            msg["type"] = "key_event"
            msg["device_id"] = args["device_id"]
            msg["keycode"] = args["keycode"]

        case "tap":
            msg["type"] = "touch_event"
            msg["device_id"] = args["device_id"]
            msg["action"] = "tap"
            msg["x"] = args["x"]
            msg["y"] = args["y"]

        case "touch_down", "touch_move", "touch_up":
            msg["type"] = "touch_event"
            msg["device_id"] = args["device_id"]
            msg["action"] = type == "touch_down" ? "down" : type == "touch_move" ? "move" : "up"
            msg["x"] = args["x"]
            msg["y"] = args["y"]

        case "scroll":
            msg["type"] = "touch_event"
            msg["device_id"] = args["device_id"]
            let delta = args["delta"] as? Double ?? 0
            msg["action"] = delta > 0 ? "scroll_down" : "scroll_up"
            msg["x"] = args["x"]
            msg["y"] = args["y"]

        case "swipe":
            msg["type"] = "touch_sequence"
            msg["device_id"] = args["device_id"]
            msg["events"] = [
                ["action": "down", "x": args["x1"], "y": args["y1"], "delay_ms": 0],
                ["action": "up", "x": args["x2"], "y": args["y2"], "delay_ms": args["duration_ms"] ?? 200]
            ]

        case "text":
            msg["type"] = "key_event"
            msg["device_id"] = args["device_id"]
            msg["keycode"] = -1
            msg["text"] = args["text"]

        default:
            return
        }

        controlClient.send(msg)
    }

    func setFpsProfile(deviceId: Int, profile: String) {
        guard connected, let controlClient = controlClient else { return }
        let msg: [String: Any] = [
            "type": "fps_hint",
            "hints": [["device_id": deviceId, "profile": profile]]
        ]
        controlClient.send(msg)
    }

    func getFrameStats() -> [String: Any] {
        return [:]
    }

    private func handleControlMessage(_ json: [String: Any]) {
        guard let type = json["type"] as? String else { return }

        switch type {
        case "device_list":
            guard let devices = json["devices"] as? [[String: Any]] else { return }
            var list: [[String: Any]] = []
            for d in devices {
                list.append([
                    "device_id": d["id"] ?? -1,
                    "serial": d["serial"] ?? "",
                    "width": d["width"] ?? 1080,
                    "height": d["height"] ?? 1920,
                    "physical_width": d["physical_width"] ?? 0,
                    "physical_height": d["physical_height"] ?? 0,
                    "phase": d["phase"] ?? "offline"
                ])
            }
            emitEvent(["event": "device_list", "devices": list])

        case "fps_hint_ack":
            guard let results = json["results"] as? [[String: Any]] else { return }
            for r in results {
                emitEvent([
                    "event": "fps_update",
                    "device_id": r["device_id"] ?? -1,
                    "profile": r["applied"] ?? "",
                    "restarting": r["restarting"] ?? false
                ])
            }

        case "lock_status":
            emitEvent([
                "event": "lock_status",
                "device_id": json["device_id"] ?? -1,
                "owner": json["owner"] ?? ""
            ])

        default:
            break
        }
    }
}
