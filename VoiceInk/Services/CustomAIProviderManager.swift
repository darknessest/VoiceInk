import Foundation
import Combine
import SwiftUI

@MainActor
final class CustomAIProviderManager: ObservableObject {
    static let shared = CustomAIProviderManager()

    // MARK: - Published properties
    @Published private(set) var providers: [CustomAIProvider] = []
    @Published var selectedProviderId: UUID? {
        didSet { saveSelectedId(); applyToAIService() }
    }

    // MARK: - Private
    private let providersKey = "customAIProviders"
    private let selectedKey  = "selectedCustomAIProviderId"
    private weak var aiService: AIService?

    private init() {
        loadProviders()
        loadSelectedId()
        migrateLegacySingleProviderIfNeeded()
        applyToAIService() // Ensure AIService has initial values on launch
    }

    // MARK: - Public helpers
    func bind(to aiService: AIService) {
        self.aiService = aiService
        applyToAIService()
    }

    func addProvider(name: String, baseURL: String, model: String) {
        let new = CustomAIProvider(name: name, baseURL: baseURL, model: model)
        providers.append(new)
        persist()
        selectProvider(new)
    }

    func updateProvider(_ provider: CustomAIProvider) {
        guard let idx = providers.firstIndex(where: { $0.id == provider.id }) else { return }
        providers[idx] = provider
        persist()
        // Re-sync if the updated provider is selected.
        if provider.id == selectedProviderId { applyToAIService() }
    }

    func deleteProvider(_ provider: CustomAIProvider) {
        providers.removeAll { $0.id == provider.id }
        persist()
        if selectedProviderId == provider.id {
            selectedProviderId = providers.first?.id // fallback
        }
    }

    func selectProvider(_ provider: CustomAIProvider) {
        selectedProviderId = provider.id
    }

    var selectedProvider: CustomAIProvider? {
        providers.first { $0.id == selectedProviderId }
    }

    // MARK: - Persistence
    private func persist() {
        if let data = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(data, forKey: providersKey)
        }
    }

    private func loadProviders() {
        if let data = UserDefaults.standard.data(forKey: providersKey),
           let decoded = try? JSONDecoder().decode([CustomAIProvider].self, from: data) {
            self.providers = decoded
        }
    }

    private func saveSelectedId() {
        UserDefaults.standard.set(selectedProviderId?.uuidString, forKey: selectedKey)
    }

    private func loadSelectedId() {
        if let idStr = UserDefaults.standard.string(forKey: selectedKey),
           let uuid = UUID(uuidString: idStr) {
            selectedProviderId = uuid
        }
    }

    // MARK: - Legacy migration
    private func migrateLegacySingleProviderIfNeeded() {
        guard providers.isEmpty else { return }
        let legacyURL = UserDefaults.standard.string(forKey: "customProviderBaseURL") ?? ""
        let legacyModel = UserDefaults.standard.string(forKey: "customProviderModel") ?? ""
        guard !legacyURL.isEmpty && !legacyModel.isEmpty else { return }
        let legacyProvider = CustomAIProvider(name: "Default", baseURL: legacyURL, model: legacyModel)
        providers = [legacyProvider]
        selectedProviderId = legacyProvider.id
        persist()
    }

    // MARK: - AIService sync
    private func applyToAIService() {
        guard let aiService = aiService, let provider = selectedProvider else { return }
        aiService.customBaseURL = provider.baseURL
        aiService.customModel   = provider.model
    }
}