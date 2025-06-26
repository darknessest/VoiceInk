#!/bin/bash

set -e

echo "🚀 Building whisper.cpp for macOS arm64 only with performance optimizations enabled"

# Navigate into the whisper.cpp submodule
cd whisper.cpp

# Check for required tools
check_required_tool() {
    local tool=$1
    local install_message=$2

    if ! command -v "$tool" &> /dev/null; then
        echo "Error: $tool is required but not found."
        echo "$install_message"
        exit 1
    fi
}

echo "🔍 Checking for required tools..."
check_required_tool "cmake" "Please install CMake 3.28.0 or later (brew install cmake)"
check_required_tool "xcodebuild" "Please install Xcode and Xcode Command Line Tools (xcode-select --install)"
check_required_tool "libtool" "Please install libtool with Xcode Command Line Tools (xcode-select --install)"
check_required_tool "dsymutil" "Please install Xcode and Xcode Command Line Tools (xcode-select --install)"

# Clean up previous builds
rm -rf build-apple build-macos

# Build options and performance flags
MACOS_MIN_OS_VERSION=13.3
BUILD_SHARED_LIBS=OFF
WHISPER_BUILD_EXAMPLES=OFF
WHISPER_BUILD_TESTS=OFF
WHISPER_BUILD_SERVER=OFF
GGML_METAL=ON
GGML_METAL_EMBED_LIBRARY=ON
GGML_METAL_USE_BF16=ON
GGML_BLAS=ON
GGML_OPENMP=ON

COMMON_C_FLAGS="-Wno-macro-redefined -Wno-shorten-64-to-32 -Wno-unused-command-line-argument -g"
COMMON_CXX_FLAGS="-Wno-macro-redefined -Wno-shorten-64-to-32 -Wno-unused-command-line-argument -g"

COMMON_CMAKE_ARGS=(
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=""
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
    -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT="dwarf-with-dsym"
    -DCMAKE_XCODE_ATTRIBUTE_GCC_GENERATE_DEBUGGING_SYMBOLS=YES
    -DCMAKE_XCODE_ATTRIBUTE_COPY_PHASE_STRIP=NO
    -DCMAKE_XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT=NO
    -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=ggml
    -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
    -DWHISPER_BUILD_EXAMPLES=${WHISPER_BUILD_EXAMPLES}
    -DWHISPER_BUILD_TESTS=${WHISPER_BUILD_TESTS}
    -DWHISPER_BUILD_SERVER=${WHISPER_BUILD_SERVER}
    -DGGML_METAL=${GGML_METAL}
    -DGGML_METAL_EMBED_LIBRARY=${GGML_METAL_EMBED_LIBRARY}
    -DGGML_METAL_USE_BF16=${GGML_METAL_USE_BF16}
    -DGGML_BLAS=${GGML_BLAS}
    -DGGML_OPENMP=${GGML_OPENMP}
    -DOpenMP_C_FLAGS="-Xpreprocessor -fopenmp -I$(brew --prefix libomp)/include"
    -DOpenMP_C_LIB_NAMES="omp"
    -DOpenMP_CXX_FLAGS="-Xpreprocessor -fopenmp -I$(brew --prefix libomp)/include"
    -DOpenMP_CXX_LIB_NAMES="omp"
    -DOpenMP_omp_LIBRARY="$(brew --prefix libomp)/lib/libomp.dylib"
)

LIBOMP_SRC="$(brew --prefix libomp)/lib/libomp.dylib"

# Function to create framework structure (macOS only)
setup_framework_structure() {
    local build_dir=$1
    local min_os_version=$2
    local framework_name="whisper"

    echo "🏗️  Creating macOS framework structure for ${build_dir}"
    mkdir -p ${build_dir}/framework/${framework_name}.framework/Versions/A/{Headers,Modules,Resources}

    ln -sf A ${build_dir}/framework/${framework_name}.framework/Versions/Current
    ln -sf Versions/Current/Headers ${build_dir}/framework/${framework_name}.framework/Headers
    ln -sf Versions/Current/Modules ${build_dir}/framework/${framework_name}.framework/Modules
    ln -sf Versions/Current/Resources ${build_dir}/framework/${framework_name}.framework/Resources
    ln -sf Versions/Current/${framework_name} ${build_dir}/framework/${framework_name}.framework/${framework_name}

    local header_path=${build_dir}/framework/${framework_name}.framework/Versions/A/Headers/
    local module_path=${build_dir}/framework/${framework_name}.framework/Versions/A/Modules/

    cp include/whisper.h           ${header_path}
    cp ggml/include/ggml.h         ${header_path}
    cp ggml/include/ggml-alloc.h   ${header_path}
    cp ggml/include/ggml-backend.h ${header_path}
    cp ggml/include/ggml-metal.h   ${header_path}
    cp ggml/include/ggml-cpu.h     ${header_path}
    cp ggml/include/ggml-blas.h    ${header_path}
    cp ggml/include/gguf.h         ${header_path}

    cat > ${module_path}module.modulemap << EOF
framework module whisper {
    header "whisper.h"
    header "ggml.h"
    header "ggml-alloc.h"
    header "ggml-backend.h"
    header "ggml-metal.h"
    header "ggml-cpu.h"
    header "ggml-blas.h"
    header "gguf.h"

    link "c++"
    link framework "Accelerate"
    link framework "Metal"
    link framework "Foundation"

    export *
}
EOF

    local plist_path="${build_dir}/framework/${framework_name}.framework/Versions/A/Resources/Info.plist"
    cat > ${plist_path} << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${framework_name}</string>
    <key>CFBundleIdentifier</key>
    <string>org.ggml.whisper</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>MinimumOSVersion</key>
    <string>${min_os_version}</string>
    <key>CFBundleSupportedPlatforms</key>
    <array><string>MacOSX</string></array>
    <key>DTPlatformName</key>
    <string>macosx</string>
    <key>DTSDKName</key>
    <string>macosx${min_os_version}</string>
</dict>
</plist>
EOF
}

# Function to combine static libs into a dynamic library (macOS only)
combine_static_libraries() {
    local build_dir="$1"
    local release_dir="$2"
    local framework_name="whisper"
    local base_dir="$(pwd)"
    local output_lib="${build_dir}/framework/${framework_name}.framework/Versions/A/${framework_name}"

    echo "🔧 Combining static libraries into a dynamic library for macOS..."
    mkdir -p "${base_dir}/${build_dir}/temp"
    libtool -static -o "${base_dir}/${build_dir}/temp/combined.a" \
        "${base_dir}/${build_dir}/src/${release_dir}/libwhisper.a" \
        "${base_dir}/${build_dir}/src/${release_dir}/libwhisper.coreml.a" \
        "${base_dir}/${build_dir}/ggml/src/${release_dir}/libggml.a" \
        "${base_dir}/${build_dir}/ggml/src/${release_dir}/libggml-base.a" \
        "${base_dir}/${build_dir}/ggml/src/${release_dir}/libggml-cpu.a" \
        "${base_dir}/${build_dir}/ggml/src/ggml-metal/${release_dir}/libggml-metal.a" \
        "${base_dir}/${build_dir}/ggml/src/ggml-blas/${release_dir}/libggml-blas.a"

    xcrun -sdk macosx clang++ -dynamiclib \
        -isysroot $(xcrun --sdk macosx --show-sdk-path) \
        -arch arm64 -mmacosx-version-min=${MACOS_MIN_OS_VERSION} \
        -Wl,-force_load,"${base_dir}/${build_dir}/temp/combined.a" \
        -framework Foundation -framework Metal -framework Accelerate -framework CoreML \
        -L$(brew --prefix libomp)/lib -lomp \
        -install_name "@rpath/whisper.framework/Versions/Current/whisper" \
        -o "${base_dir}/${output_lib}"

    mkdir -p "${base_dir}/${build_dir}/dSYMs"
    xcrun dsymutil "${base_dir}/${output_lib}" -o "${base_dir}/${build_dir}/dSYMs/whisper.dSYM"

    echo "Cleaning up temporary files..."
    rm -rf "${base_dir}/${build_dir}/temp"
}

embed_libomp() {
    local fw_root="$1/framework/whisper.framework/Versions/A"
    echo "📦 Embedding libomp.dylib inside whisper.framework"

    # Copy the libomp.dylib that we just linked against into the framework bundle
    cp "$LIBOMP_SRC" "$fw_root/libomp.dylib"

    # 1. Make the copied dylib reference itself via a relative path so that it can be located
    #    no matter where the framework ends up inside the final .app bundle.
    install_name_tool -id "@loader_path/libomp.dylib" "$fw_root/libomp.dylib"

    # 2. Tell the whisper binary inside the framework to look for that local copy instead of the
    #    Homebrew-installed one that was used at build-time.
    install_name_tool -change "$LIBOMP_SRC" "@loader_path/libomp.dylib" "$fw_root/whisper"
}

# Build for macOS arm64
echo "🔨 Configuring CMake (Xcode generator)..."
cmake -B build-macos -G Xcode \
    "${COMMON_CMAKE_ARGS[@]}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOS_MIN_OS_VERSION} \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_C_FLAGS="${COMMON_C_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${COMMON_CXX_FLAGS}" \
    -DWHISPER_COREML="ON" \
    -S .

echo "📦 Building (Release)..."
cmake --build build-macos --config Release -- -quiet

# Create framework & XCFramework
setup_framework_structure "build-macos" ${MACOS_MIN_OS_VERSION}
combine_static_libraries "build-macos" "Release"
embed_libomp "build-macos"

echo "✅ Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework $(pwd)/build-macos/framework/whisper.framework \
    -debug-symbols $(pwd)/build-macos/dSYMs/whisper.dSYM \
    -output $(pwd)/build-apple/whisper.xcframework

echo "🎉 Completed: build-apple/whisper.xcframework"

# Return to project root
echo "🔙 Returning to project root"
cd .. 