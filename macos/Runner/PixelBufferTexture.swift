import Foundation
import FlutterMacOS
import CoreVideo

class PixelBufferTexture: NSObject, FlutterTexture {
    private var pixelBuffer: CVPixelBuffer?
    private let lock = NSLock()
    var textureId: Int64?

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let pb = pixelBuffer else { return nil }
        return Unmanaged.passRetained(pb)
    }

    func updatePixelBuffer(_ buffer: CVPixelBuffer) {
        lock.lock()
        pixelBuffer = buffer
        lock.unlock()
    }
}
