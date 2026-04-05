# MUPhone macOS Client

## Build Instructions (on macOS)

### Prerequisites
- macOS 12+ with Xcode 14+
- Flutter SDK (same version as Windows client: 3.41.6)

### Setup

1. **Add plugin sources to Xcode project:**
   ```bash
   cd macos
   bash setup_plugin.sh
   ```

2. **Open in Xcode and add files:**
   - Open `macos/Runner.xcworkspace`
   - Right-click "Runner" group → "Add Files to Runner"
   - Select all 5 `.swift` files from `Runner/`:
     - `MuphoneNativePlugin.swift`
     - `MuphoneEngine.swift`
     - `H264Decoder.swift`
     - `PixelBufferTexture.swift`
     - `NetworkClients.swift`
   - Uncheck "Copy items" → Add

3. **Build:**
   ```bash
   cd client_macos
   flutter pub get
   flutter build macos --release
   ```

4. **Run:**
   ```bash
   flutter run -d macos
   ```
   Or open the built `.app` from `build/macos/Build/Products/Release/`

### Architecture

```
Dart UI (shared with Windows)
    ↓ MethodChannel / EventChannel
macOS Native Plugin (Swift)
    ├── MuphoneNativePlugin.swift  — Plugin registration & method dispatch
    ├── MuphoneEngine.swift        — Core engine (connects all components)
    ├── H264Decoder.swift          — VideoToolbox H.264 decoder
    ├── PixelBufferTexture.swift   — CVPixelBuffer → Flutter Texture
    └── NetworkClients.swift       — TCP video + control channels
```

### Differences from Windows Client

| Component | Windows | macOS |
|-----------|---------|-------|
| H.264 Decode | Media Foundation Transform (MFT) | VideoToolbox |
| GPU Render | D3D11 + VideoProcessor | CVPixelBuffer (Metal-backed) |
| Texture | GpuSurfaceTexture (shared DXGI handle) | FlutterTexture (CVPixelBuffer) |
| Network | WinSock | BSD sockets (CFStream) |
| Window Mgmt | Win32 API | NSWindow |
