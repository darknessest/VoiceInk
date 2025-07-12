// MARK: - Temporary stub implementation until Apple releases the SpeechTranscriber / SpeechAnalyzer APIs

#if canImport(SpeechTranscriber) // This will evaluate to false with current SDKs

// When the new SpeechTranscriber APIs become available in the SDK, we will
// build the full implementation automatically.

#else

import Foundation
import os

/// Fallback implementation that simply throws an unsupported-OS error so the rest of the
/// application can be compiled and run on current macOS versions.
class NativeAppleTranscriptionService: TranscriptionService {
    enum ServiceError: Error, LocalizedError {
        case unsupportedOS

        var errorDescription: String? {
            "Native Apple SpeechTranscriber API is not available in this macOS SDK yet."
        }
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        throw ServiceError.unsupportedOS
    }
}

#endif // canImport(SpeechTranscriber) 
