#!/bin/bash

set -e

echo "🚀 Building VoiceInk with whisper.cpp"

# Initialize submodules if they haven't been initialized
if [ ! -f "whisper.cpp/README.md" ]; then
    echo "📦 Initializing submodules..."
    git submodule update --init --recursive
fi

# Use our macOS arm64-only build script for whisper.cpp
echo "🔨 Building whisper.cpp XCFramework via local script..."
bash build-macos-arm64.sh
# Verify that the XCFramework was built
if [ ! -d "whisper.cpp/build-apple/whisper.xcframework" ]; then
    echo "❌ Error: whisper.xcframework was not built successfully"
    exit 1
fi
echo "✅ whisper.cpp XCFramework built successfully for macOS arm64"

# Build VoiceInk
echo "🔨 Building VoiceInk..."

# Check if we're on Apple Silicon
ARCH=$(uname -m)
echo "📱 Building on architecture: $ARCH"

# Use xcodebuild to build the project with Apple Silicon support
xcodebuild -project VoiceInk.xcodeproj \
    -scheme VoiceInk \
    -configuration Release \
    -derivedDataPath build \
    -destination 'platform=macOS,arch=arm64' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build

echo "✅ VoiceInk built successfully!"

# Verify the binary architecture
if [ -f "build/Build/Products/Release/VoiceInk.app/Contents/MacOS/VoiceInk" ]; then
    echo "🔍 Verifying binary architecture..."
    file build/Build/Products/Release/VoiceInk.app/Contents/MacOS/VoiceInk
    lipo -archs build/Build/Products/Release/VoiceInk.app/Contents/MacOS/VoiceInk
    
    if lipo -archs build/Build/Products/Release/VoiceInk.app/Contents/MacOS/VoiceInk | grep -q "arm64"; then
        echo "✅ Binary contains Apple Silicon (arm64) architecture"
    else
        echo "⚠️  Binary does not contain Apple Silicon (arm64) architecture"
    fi
fi

echo "📦 Build artifacts:"
echo "   - App: build/Build/Products/Release/VoiceInk.app"
echo "   - XCFramework: whisper.cpp/build-apple/whisper.xcframework" 