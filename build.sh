#!/bin/bash

set -e

echo "🚀 Building VoiceInk with whisper.cpp"

# Initialize submodules if they haven't been initialized
if [ ! -f "whisper.cpp/README.md" ]; then
    echo "📦 Initializing submodules..."
    git submodule update --init --recursive
fi

# Build whisper.cpp XCFramework
echo "🔨 Building whisper.cpp XCFramework..."
cd whisper.cpp

# Make the build script executable
chmod +x build-xcframework.sh

# Build the XCFramework
./build-xcframework.sh

# Go back to the root directory
cd ..

# Verify that the XCFramework was built
if [ ! -d "whisper.cpp/build-apple/whisper.xcframework" ]; then
    echo "❌ Error: whisper.xcframework was not built successfully"
    exit 1
fi

echo "✅ whisper.xcframework built successfully"

# Build VoiceInk
echo "🔨 Building VoiceInk..."

# Use xcodebuild to build the project
xcodebuild -project VoiceInk.xcodeproj \
    -scheme VoiceInk \
    -configuration Debug \
    -derivedDataPath build \
    build

echo "✅ VoiceInk built successfully!"
echo "📦 Build artifacts:"
echo "   - App: build/Build/Products/Debug/VoiceInk.app"
echo "   - XCFramework: whisper.cpp/build-apple/whisper.xcframework" 