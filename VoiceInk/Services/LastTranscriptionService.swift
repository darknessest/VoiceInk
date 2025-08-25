import Foundation
import SwiftData

class LastTranscriptionService: ObservableObject {
    
    static func getLastTranscription(from modelContext: ModelContext) -> Transcription? {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        do {
            let transcriptions = try modelContext.fetch(descriptor)
            return transcriptions.first
        } catch {
            print("Error fetching last transcription: \(error)")
            return nil
        }
    }
    
    static func copyLastTranscription(from modelContext: ModelContext) {
        guard let lastTranscription = getLastTranscription(from: modelContext) else {
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "No transcription available",
                    type: .error
                )
            }
            return
        }
        
        let success = ClipboardManager.copyToClipboard(lastTranscription.enhancedText?.isEmpty == false ? lastTranscription.enhancedText! : lastTranscription.text)
        
        Task { @MainActor in
            if success {
                NotificationManager.shared.showNotification(
                    title: "Last transcription copied",
                    type: .success
                )
            } else {
                NotificationManager.shared.showNotification(
                    title: "Failed to copy transcription",
                    type: .error
                )
            }
        }
    }

    static func pasteLastTranscription(from modelContext: ModelContext) {
        guard let lastTranscription = getLastTranscription(from: modelContext) else {
            Task { @MainActor in
                NotificationManager.shared.showNotification(
                    title: "No transcription available",
                    type: .error
                )
            }
            return
        }
        
        // Use enhanced text if available and not empty, otherwise use original text
        let textToPaste: String
        if let enhancedText = lastTranscription.enhancedText, !enhancedText.isEmpty {
            textToPaste = enhancedText
        } else {
            textToPaste = lastTranscription.text
        }
        
        // Delay to give the user time to release modifier keys (especially Control)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CursorPaster.pasteAtCursor(textToPaste + " ")
        }
    }
    
    static func retryLastTranscription(from modelContext: ModelContext, whisperState: WhisperState) {
        Task { @MainActor in
            guard let lastTranscription = getLastTranscription(from: modelContext),
                  let audioURLString = lastTranscription.audioFileURL,
                  let audioURL = URL(string: audioURLString),
                  FileManager.default.fileExists(atPath: audioURL.path) else {
                NotificationManager.shared.showNotification(
                    title: "Cannot retry: Audio file not found",
                    type: .error
                )
                return
            }
            
            guard let currentModel = whisperState.currentTranscriptionModel else {
                NotificationManager.shared.showNotification(
                    title: "No transcription model selected",
                    type: .error
                )
                return
            }
            
            let transcriptionService = AudioTranscriptionService(modelContext: modelContext, whisperState: whisperState)
            do {
                let newTranscription = try await transcriptionService.retranscribeAudio(from: audioURL, using: currentModel)
                
                let textToCopy = newTranscription.enhancedText?.isEmpty == false ? newTranscription.enhancedText! : newTranscription.text
                ClipboardManager.copyToClipboard(textToCopy)
                
                NotificationManager.shared.showNotification(
                    title: "Copied to clipboard",
                    type: .success
                )
            } catch {
                NotificationManager.shared.showNotification(
                    title: "Retry failed: \(error.localizedDescription)",
                    type: .error
                )
            }
        }
    }
} 