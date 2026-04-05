#!/bin/bash
# Run this on macOS to add plugin sources to the Xcode project
# Usage: cd client_macos/macos && bash setup_plugin.sh

PLUGIN_DIR="Plugins/muphone_native/Sources"
RUNNER_DIR="Runner"

echo "Copying plugin sources to Runner..."
cp "$PLUGIN_DIR/MuphoneNativePlugin.swift" "$RUNNER_DIR/"
cp "$PLUGIN_DIR/MuphoneEngine.swift" "$RUNNER_DIR/"
cp "$PLUGIN_DIR/H264Decoder.swift" "$RUNNER_DIR/"
cp "$PLUGIN_DIR/PixelBufferTexture.swift" "$RUNNER_DIR/"
cp "$PLUGIN_DIR/NetworkClients.swift" "$RUNNER_DIR/"

echo "Done! Now open Runner.xcworkspace in Xcode and:"
echo "1. Right-click Runner group -> Add Files to Runner"
echo "2. Select all 5 .swift files"
echo "3. Make sure 'Copy items' is UNCHECKED and target Runner is checked"
echo "4. Build and run"
echo ""
echo "OR use: flutter build macos --release"
