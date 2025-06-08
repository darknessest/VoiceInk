#!/bin/bash

set -e

echo "🚀 Building VoiceInk with whisper.cpp"

# Initialize submodules if they haven't been initialized
if [ ! -f "whisper.cpp/README.md" ]; then
    echo "📦 Initializing submodules..."
    git submodule update --init --recursive
fi

# Build whisper.cpp for macOS arm64
echo "🔨 Building whisper.cpp for macOS arm64..."
cd whisper.cpp

# First build the static libraries
cmake -B build-macos -G Xcode \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DWHISPER_COREML=ON \
    -S .

cmake --build build-macos --config Release

# Create framework structure for local development  
echo "🏗️ Creating whisper framework..."
mkdir -p build-apple

# Use the official build script to create proper XCFramework
./build-xcframework.sh --enable-coreml

# Go back to the root directory
cd ..

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
    -configuration Debug \
    -derivedDataPath build \
    -destination 'platform=macOS,arch=arm64' \
    ARCHS='arm64' \
    VALID_ARCHS='arm64' \
    ONLY_ACTIVE_ARCH=NO \
    build

echo "✅ VoiceInk built successfully!"

# Verify the binary architecture
if [ -f "build/Build/Products/Debug/VoiceInk.app/Contents/MacOS/VoiceInk" ]; then
    echo "🔍 Verifying binary architecture..."
    file build/Build/Products/Debug/VoiceInk.app/Contents/MacOS/VoiceInk
    lipo -archs build/Build/Products/Debug/VoiceInk.app/Contents/MacOS/VoiceInk
    
    if lipo -archs build/Build/Products/Debug/VoiceInk.app/Contents/MacOS/VoiceInk | grep -q "arm64"; then
        echo "✅ Binary contains Apple Silicon (arm64) architecture"
    else
        echo "⚠️  Binary does not contain Apple Silicon (arm64) architecture"
    fi
fi

echo "📦 Build artifacts:"
echo "   - App: build/Build/Products/Debug/VoiceInk.app"
echo "   - XCFramework: whisper.cpp/build-apple/whisper.xcframework" 