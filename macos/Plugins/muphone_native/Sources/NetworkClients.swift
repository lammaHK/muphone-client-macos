import Foundation

// MARK: - Control Client (JSON over TCP with length-prefixed framing)

class ControlClient {
    private let host: String
    private let port: Int
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var recvThread: Thread?
    private var running = false

    var onMessage: (([String: Any]) -> Void)?
    var onDisconnect: (() -> Void)?

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    func connect() -> Bool {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port), &readStream, &writeStream)

        guard let input = readStream?.takeRetainedValue() as? InputStream,
              let output = writeStream?.takeRetainedValue() as? OutputStream else {
            return false
        }

        input.open()
        output.open()

        // Wait for connection
        var attempts = 0
        while input.streamStatus != .open && attempts < 50 {
            Thread.sleep(forTimeInterval: 0.1)
            attempts += 1
        }

        if input.streamStatus != .open {
            input.close()
            output.close()
            return false
        }

        self.inputStream = input
        self.outputStream = output
        self.running = true

        recvThread = Thread { [weak self] in self?.recvLoop() }
        recvThread?.start()

        return true
    }

    func disconnect() {
        running = false
        inputStream?.close()
        outputStream?.close()
        inputStream = nil
        outputStream = nil
    }

    func send(_ msg: [String: Any]) {
        guard let output = outputStream,
              let jsonData = try? JSONSerialization.data(withJSONObject: msg) else { return }

        // Length-prefixed frame: 4 bytes big-endian length + JSON bytes
        var length = UInt32(jsonData.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)

        output.write([UInt8](lengthData), maxLength: 4)
        output.write([UInt8](jsonData), maxLength: jsonData.count)
    }

    private func recvLoop() {
        guard let input = inputStream else { return }

        while running {
            // Read 4-byte length header
            var lengthBuf = [UInt8](repeating: 0, count: 4)
            let headerRead = readExact(input, buffer: &lengthBuf, count: 4)
            if headerRead != 4 { break }

            let length = Int(UInt32(bigEndian: Data(lengthBuf).withUnsafeBytes { $0.load(as: UInt32.self) }))
            if length <= 0 || length > 1_000_000 { continue }

            // Read JSON body
            var bodyBuf = [UInt8](repeating: 0, count: length)
            let bodyRead = readExact(input, buffer: &bodyBuf, count: length)
            if bodyRead != length { break }

            // Parse JSON
            if let json = try? JSONSerialization.jsonObject(with: Data(bodyBuf)) as? [String: Any] {
                // Handle ping internally
                if json["type"] as? String == "ping" {
                    let pong: [String: Any] = ["type": "pong", "timestamp": json["timestamp"] ?? 0]
                    send(pong)
                    continue
                }
                DispatchQueue.main.async { [weak self] in
                    self?.onMessage?(json)
                }
            }
        }

        if running {
            running = false
            DispatchQueue.main.async { [weak self] in
                self?.onDisconnect?()
            }
        }
    }

    private func readExact(_ stream: InputStream, buffer: inout [UInt8], count: Int) -> Int {
        var totalRead = 0
        while totalRead < count {
            let n = stream.read(&buffer[totalRead], maxLength: count - totalRead)
            if n <= 0 { return totalRead }
            totalRead += n
        }
        return totalRead
    }
}

// MARK: - Video Client (TCP video stream receiver)

class VideoClient {
    private let host: String
    private let port: Int
    private var subscribers: [Int: (Data, Bool, Bool) -> Void] = [:]  // deviceId -> callback(data, isConfig, isKeyframe)
    private var connections: [Int: VideoReceiver] = [:]

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    func subscribe(deviceId: Int, callback: @escaping (Data, Bool, Bool) -> Void) {
        subscribers[deviceId] = callback

        let receiver = VideoReceiver(host: host, port: port, deviceId: deviceId, onNal: callback)
        connections[deviceId] = receiver
        receiver.start()
    }

    func unsubscribe(deviceId: Int) {
        connections[deviceId]?.stop()
        connections.removeValue(forKey: deviceId)
        subscribers.removeValue(forKey: deviceId)
    }

    func disconnect() {
        for (_, receiver) in connections {
            receiver.stop()
        }
        connections.removeAll()
        subscribers.removeAll()
    }
}

// MARK: - Video Receiver (per-device TCP connection for H.264 NAL stream)

class VideoReceiver {
    private let host: String
    private let port: Int
    private let deviceId: Int
    private let onNal: (Data, Bool, Bool) -> Void
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var thread: Thread?
    private var running = false

    init(host: String, port: Int, deviceId: Int, onNal: @escaping (Data, Bool, Bool) -> Void) {
        self.host = host
        self.port = port
        self.deviceId = deviceId
        self.onNal = onNal
    }

    func start() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port), &readStream, &writeStream)

        guard let input = readStream?.takeRetainedValue() as? InputStream,
              let output = writeStream?.takeRetainedValue() as? OutputStream else { return }

        input.open()
        output.open()

        // Wait for connection
        var attempts = 0
        while input.streamStatus != .open && attempts < 50 {
            Thread.sleep(forTimeInterval: 0.1)
            attempts += 1
        }

        if input.streamStatus != .open { return }

        self.inputStream = input
        self.outputStream = output

        // Send subscription header: 4 bytes device_id (big-endian)
        var devId = UInt32(deviceId).bigEndian
        let devData = Data(bytes: &devId, count: 4)
        output.write([UInt8](devData), maxLength: 4)

        running = true
        thread = Thread { [weak self] in self?.receiveLoop() }
        thread?.start()
    }

    func stop() {
        running = false
        inputStream?.close()
        outputStream?.close()
    }

    private func receiveLoop() {
        guard let input = inputStream else { return }

        while running {
            // Read frame header: 4 bytes length + 2 bytes flags + 2 bytes timestamp
            var header = [UInt8](repeating: 0, count: 8)
            let n = readExact(input, buffer: &header, count: 8)
            if n != 8 { break }

            let length = Int(UInt32(bigEndian: Data(header[0..<4]).withUnsafeBytes { $0.load(as: UInt32.self) }))
            let flags = UInt16(bigEndian: Data(header[4..<6]).withUnsafeBytes { $0.load(as: UInt16.self) })

            if length <= 0 || length > 10_000_000 { continue }

            var payload = [UInt8](repeating: 0, count: length)
            let payloadRead = readExact(input, buffer: &payload, count: length)
            if payloadRead != length { break }

            let isKeyframe = (flags & 0x01) != 0
            let isConfig = (flags & 0x02) != 0

            onNal(Data(payload), isConfig, isKeyframe)
        }
    }

    private func readExact(_ stream: InputStream, buffer: inout [UInt8], count: Int) -> Int {
        var totalRead = 0
        while totalRead < count {
            let n = stream.read(&buffer[totalRead], maxLength: count - totalRead)
            if n <= 0 { return totalRead }
            totalRead += n
        }
        return totalRead
    }
}
