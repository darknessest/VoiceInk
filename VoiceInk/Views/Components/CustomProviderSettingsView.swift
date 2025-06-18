import SwiftUI
import AppKit

/// Independent view used inside `APIKeyManagementView` to configure the **Custom** AI provider.
/// The user can change the base URL or model _even when an API key is already saved_.
/// The view keeps all changes local until the user explicitly presses **Save**.
///
/// NOTE: This file is self-contained and does not alter any existing service behaviour –
/// it only updates the `AIService` bindings that already exist.
struct CustomProviderSettingsView: View {
    @EnvironmentObject private var aiService: AIService

    // Local editable copies so the user can cancel their changes.
    @State private var draftBaseURL: String = ""
    @State private var draftModel: String = ""
    @State private var isEditingConfig: Bool = false

    // Local state for API-key interaction (mirrors the existing pattern)
    @State private var apiKeyInput: String = ""
    @State private var isVerifying: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    // Manager handling multiple presets
    @StateObject private var providerManager = CustomAIProviderManager.shared

    // Sheet toggles for adding/editing provider presets
    @State private var isAddingProvider: Bool = false
    @State private var providerToEdit: CustomAIProvider? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Provider Configuration")
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Requires OpenAI-compatible API endpoint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Configuration section (Base URL & Model)
            configSection

            Divider()
                .padding(.vertical, 4)

            // API-key management (unchanged from original logic)
            apiKeySection

            // Preset picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Preset")
                    Spacer()
                    Button(action: { isAddingProvider = true }) {
                        Image(systemName: "plus")
                    }
                    .help("Add new preset")
                    .buttonStyle(.borderless)
                }

                Picker("Preset", selection: Binding(
                    get: { providerManager.selectedProviderId ?? UUID() },
                    set: { newId in
                        providerManager.selectedProviderId = newId
                        if let sel = providerManager.selectedProvider {
                            aiService.customBaseURL = sel.baseURL
                            aiService.customModel   = sel.model
                        }
                    })) {
                    ForEach(providerManager.providers, id: \.id) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .pickerStyle(.menu)

                if let selected = providerManager.selectedProvider {
                    HStack(spacing: 12) {
                        Button("Edit") { providerToEdit = selected }
                            .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            providerManager.deleteProvider(selected)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(12)
        .onAppear {
            // Initialise drafts with current persisted values.
            draftBaseURL = aiService.customBaseURL
            draftModel   = aiService.customModel
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $isAddingProvider) {
            ProviderPresetEditorView(mode: .add)
        }
        .sheet(item: $providerToEdit) { provider in
            ProviderPresetEditorView(mode: .edit(provider))
        }
    }
}

// MARK: ‑ Sub-views
private extension CustomProviderSettingsView {
    var configSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingConfig {
                TextField("Base URL (e.g., https://api.example.com/v1/chat/completions)", text: $draftBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                TextField("Model Name (e.g., gpt-4o-mini)", text: $draftModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack {
                    Button("Save") {
                        aiService.customBaseURL = draftBaseURL
                        aiService.customModel   = draftModel
                        isEditingConfig = false
                        if let selected = providerManager.selectedProvider {
                            let updated = CustomAIProvider(id: selected.id, name: selected.name, baseURL: draftBaseURL, model: draftModel)
                            providerManager.updateProvider(updated)
                        }
                    }
                    .disabled(draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              draftModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Cancel") {
                        // Revert drafts to persisted values
                        draftBaseURL = aiService.customBaseURL
                        draftModel   = aiService.customModel
                        isEditingConfig = false
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(aiService.customBaseURL)
                        .font(.system(.body, design: .monospaced))
                        .contextMenu {
                            Button(action: { NSPasteboard.general.setString(aiService.customBaseURL, forType: .string) }) {
                                Text("Copy")
                                Image(systemName: "doc.on.doc")
                            }
                        }

                    Text("Model")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(aiService.customModel)
                        .font(.system(.body, design: .monospaced))
                        .contextMenu {
                            Button(action: { NSPasteboard.general.setString(aiService.customModel, forType: .string) }) {
                                Text("Copy")
                                Image(systemName: "doc.on.doc")
                            }
                        }

                    Button {
                        // Start in-place edit
                        draftBaseURL = aiService.customBaseURL
                        draftModel   = aiService.customModel
                        isEditingConfig = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
    }

    var apiKeySection: some View {
        Group {
            if aiService.isAPIKeyValid {
                // Display secured API-key with option to remove.
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(String(repeating: "•", count: 40))
                            .font(.system(.body, design: .monospaced))

                        Spacer()

                        Button(role: .destructive) {
                            aiService.clearAPIKey()
                        } label: {
                            Label("Remove Key", systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } else {
                // Input & verify workflow (same as original)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter your API Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    SecureField("API Key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    HStack {
                        Button {
                            isVerifying = true
                            aiService.saveAPIKey(apiKeyInput) { success in
                                isVerifying = false
                                if !success {
                                    alertMessage = "Invalid API key. Please check and try again."
                                    showAlert = true
                                }
                                apiKeyInput = ""
                            }
                        } label: {
                            HStack {
                                if isVerifying {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Verify and Save")
                            }
                        }
                        .disabled(apiKeyInput.isEmpty)

                        Spacer()
                    }
                }
            }
        }
    }
}