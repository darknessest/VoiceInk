# Building VoiceInk

This guide provides detailed instructions for building VoiceInk from source.

## Prerequisites

Before you begin, ensure you have:
- macOS 14.0 or later
- Xcode (latest version recommended)
- Swift (latest version recommended)
- CMake 3.28.0 or later (`brew install cmake`)

**Note:** The CMake requirement is for building whisper.cpp. If you're only building VoiceInk with a pre-built whisper.xcframework, CMake is not required.

## Building whisper.cpp Framework

whisper.cpp is included as a git submodule. After cloning the repository, you need to initialize and build it:

1. Initialize and update submodules:
```bash
git submodule update --init --recursive
```

2. Build whisper.cpp XCFramework:
```bash
cd whisper.cpp
./build-xcframework.sh
```
This will create the XCFramework at `whisper.cpp/build-apple/whisper.xcframework`.

## Building VoiceInk

1. Clone the VoiceInk repository with submodules:
```bash
git clone --recurse-submodules https://github.com/Beingpax/VoiceInk.git
cd VoiceInk
```

2. If you've already cloned without submodules, initialize them:
```bash
git submodule update --init --recursive
```

3. Build whisper.cpp (if not already done):
```bash
cd whisper.cpp
./build-xcframework.sh
cd ..
```

4. Add the whisper.xcframework to your project:
   - Drag and drop `whisper.cpp/build-apple/whisper.xcframework` into the project navigator, or
   - Add it manually in the "Frameworks, Libraries, and Embedded Content" section of project settings

5. Build and Run
   - **Option 1:** Use the provided Makefile:
     ```bash
     make
     ```
     Or for development workflow:
     ```bash
     make dev
     ```
   - **Option 2:** Build manually using Xcode:
     - Build the project using Cmd+B or Product > Build
     - Run the project using Cmd+R or Product > Run
   - **Option 3:** Build using xcodebuild:
     ```bash
     xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug build
     ```

### Makefile Targets

The project includes a comprehensive Makefile with the following targets:

- `make` or `make all`: Full build process (default)
- `make check`: Verify prerequisites
- `make whisper`: Initialize and build whisper.cpp
- `make build`: Build the VoiceInk project
- `make run`: Launch the built application
- `make dev`: Build and run (development workflow)
- `make clean`: Clean build artifacts
- `make help`: Show available targets

## Automated Building with GitHub Actions

The project includes a GitHub Actions workflow that automatically builds VoiceInk when changes are pushed to the repository.

The workflow:
1. Checks out the repository with all submodules
2. Sets up the latest stable Xcode version
3. Builds the whisper.cpp XCFramework
4. Builds the VoiceInk project
5. Archives the build artifacts

The workflow is triggered on:
- Push to `main` or `develop` branches
- Pull requests to `main` branch

## Development Setup

1. **Xcode Configuration**
   - Ensure you have the latest Xcode version
   - Install any required Xcode Command Line Tools

2. **Dependencies**
   - The project uses [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for transcription
   - Ensure the whisper.xcframework is properly linked in your Xcode project
   - Test the whisper.cpp installation independently before proceeding

3. **Building for Development**
   - Use the Debug configuration for development
   - Enable relevant debugging options in Xcode

4. **Testing**
   - Run the test suite before making changes
   - Ensure all tests pass after your modifications

## Troubleshooting

If you encounter any build issues:

### Common Issues

1. **CMake not found**: Install CMake with `brew install cmake`
2. **Xcode build fails**: 
   - Clean the build folder (Cmd+Shift+K)
   - Clean the build cache (Cmd+Shift+K twice)
3. **whisper.xcframework not found**: Ensure you've built whisper.cpp first using `./build-xcframework.sh` in the whisper.cpp directory
4. **Submodule issues**: Run `git submodule update --init --recursive`

### General Steps
1. Check Xcode and macOS versions
2. Verify all dependencies are properly installed
3. Make sure whisper.xcframework is properly built and linked
4. Try running: `make clean && make`

For more help, please check the [issues](https://github.com/Beingpax/VoiceInk/issues) section or create a new issue. 