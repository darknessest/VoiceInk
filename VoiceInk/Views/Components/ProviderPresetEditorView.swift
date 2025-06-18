import SwiftUI

/// Editor sheet for creating or modifying a `CustomAIProvider` preset.
struct ProviderPresetEditorView: View {
    enum Mode: Identifiable {
        case add
        case edit(CustomAIProvider)

        var id: UUID {
            switch self {
            case .add:
                return UUID()
            case .edit(let provider):
                return provider.id
            }
        }
    }

    let mode: Mode

    // Manager reference
    @StateObject private var manager = CustomAIProviderManager.shared
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(modeTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Preset Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    handleSave()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || baseURL.trimmingCharacters(in: .whitespaces).isEmpty || model.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 400)
        .onAppear(perform: populateForm)
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "Add Preset"
        case .edit: return "Edit Preset"
        }
    }

    private func populateForm() {
        switch mode {
        case .add:
            break
        case .edit(let provider):
            name = provider.name
            baseURL = provider.baseURL
            model  = provider.model
        }
    }

    private func handleSave() {
        switch mode {
        case .add:
            manager.addProvider(name: name, baseURL: baseURL, model: model)
        case .edit(let provider):
            let updated = CustomAIProvider(id: provider.id, name: name, baseURL: baseURL, model: model)
            manager.updateProvider(updated)
        }
    }
}