#!/bin/bash
# Copies plugin sources to Runner/ and adds them to the Xcode project
# Usage: cd client_macos/macos && bash setup_plugin.sh

set -e

PLUGIN_DIR="Plugins/muphone_native/Sources"
RUNNER_DIR="Runner"

echo "Copying plugin sources to Runner..."
for f in "$PLUGIN_DIR"/*.swift; do
    cp "$f" "$RUNNER_DIR/"
    echo "  Copied: $(basename $f)"
done

echo "Adding files to Xcode project..."
gem install xcodeproj --no-document 2>/dev/null || true

ruby << 'RUBY'
require 'xcodeproj'

project = Xcodeproj::Project.open("Runner.xcodeproj")
target = project.targets.find { |t| t.name == "Runner" }
group = project.main_group.find_subpath("Runner", true)

files = %w[
  MuphoneNativePlugin.swift
  MuphoneEngine.swift
  H264Decoder.swift
  PixelBufferTexture.swift
  NetworkClients.swift
]

added = 0
files.each do |f|
  next if group.files.any? { |file| file.path == f }
  ref = group.new_file(f)
  target.source_build_phase.add_file_reference(ref)
  added += 1
  puts "  Added to project: #{f}"
end

project.save
puts "Done! Added #{added} new files."
RUBY

echo ""
echo "Setup complete. Run: flutter build macos --release"
