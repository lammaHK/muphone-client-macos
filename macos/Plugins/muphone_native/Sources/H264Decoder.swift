import Foundation
import VideoToolbox
import CoreVideo

class H264Decoder {
    private var session: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var spsData: Data?
    private var ppsData: Data?
    private let onFrame: (CVPixelBuffer) -> Void

    init(onFrame: @escaping (CVPixelBuffer) -> Void) {
        self.onFrame = onFrame
    }

    deinit {
        if let session = session {
            VTDecompressionSessionInvalidate(session)
        }
    }

    func setSPS(_ data: Data) {
        // Strip Annex-B start code
        let startCodeLen = findStartCodeLength(data)
        spsData = data.subdata(in: startCodeLen..<data.count)
        tryCreateSession()
    }

    func setPPS(_ data: Data) {
        let startCodeLen = findStartCodeLength(data)
        ppsData = data.subdata(in: startCodeLen..<data.count)
        tryCreateSession()
    }

    func decode(nalData: Data) {
        guard let session = session else { return }

        // Convert Annex-B NAL to AVCC format (replace start code with 4-byte length)
        let startCodeLen = findStartCodeLength(nalData)
        let nalPayload = nalData.subdata(in: startCodeLen..<nalData.count)
        let nalLength = UInt32(nalPayload.count).bigEndian

        var avccData = Data(bytes: &withUnsafeBytes(of: nalLength) { Array($0) }, count: 4)
        avccData = withUnsafeBytes(of: nalLength) { Data($0) }
        avccData.append(nalPayload)

        // Create CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        avccData.withUnsafeMutableBytes { rawBuf in
            guard let baseAddr = rawBuf.baseAddress else { return }
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: baseAddr,
                blockLength: avccData.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: avccData.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }

        guard let block = blockBuffer, let fmt = formatDescription else { return }

        // Create CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = avccData.count
        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            formatDescription: fmt,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard let sample = sampleBuffer else { return }

        // Decode
        var flagOut: VTDecodeInfoFlags = []
        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: [._EnableAsynchronousDecompression],
            infoFlagsOut: &flagOut
        ) { [weak self] status, _, imageBuffer, _, _ in
            if status == noErr, let pixelBuffer = imageBuffer {
                self?.onFrame(pixelBuffer)
            }
        }
    }

    private func tryCreateSession() {
        guard let sps = spsData, let pps = ppsData else { return }

        // Destroy old session
        if let session = session {
            VTDecompressionSessionInvalidate(session)
            self.session = nil
        }

        // Create format description from SPS + PPS
        let parameterSets: [Data] = [sps, pps]
        let parameterSetPointers = parameterSets.map { $0.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) } }
        let parameterSetSizes = parameterSets.map { $0.count }

        var newFormat: CMFormatDescription?
        let status = parameterSetPointers.withUnsafeBufferPointer { ptrs in
            parameterSetSizes.withUnsafeBufferPointer { sizes in
                CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: ptrs.baseAddress!,
                    parameterSetSizes: sizes.baseAddress!,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &newFormat
                )
            }
        }

        guard status == noErr, let fmt = newFormat else {
            NSLog("[H264Decoder] Failed to create format description: \(status)")
            return
        }

        formatDescription = fmt

        // Get dimensions
        let dims = CMVideoFormatDescriptionGetDimensions(fmt)
        NSLog("[H264Decoder] Format: \(dims.width)x\(dims.height)")

        // Create decompression session
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        var newSession: VTDecompressionSession?
        let sessionStatus = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: fmt,
            decoderSpecification: nil,
            imageBufferAttributes: attrs as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &newSession
        )

        guard sessionStatus == noErr, let sess = newSession else {
            NSLog("[H264Decoder] Failed to create session: \(sessionStatus)")
            return
        }

        session = sess
        NSLog("[H264Decoder] Session created: \(dims.width)x\(dims.height)")
    }

    private func findStartCodeLength(_ data: Data) -> Int {
        if data.count >= 4 && data[0] == 0 && data[1] == 0 && data[2] == 0 && data[3] == 1 {
            return 4
        }
        if data.count >= 3 && data[0] == 0 && data[1] == 0 && data[2] == 1 {
            return 3
        }
        return 0
    }
}
