import Foundation
import SwiftUI

/// Represents a user-defined AI-provider preset (base-URL + model).
struct CustomAIProvider: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var baseURL: String
    var model: String

    /// Human-friendly display title
    var displayName: String { name }

    init(id: UUID = UUID(), name: String, baseURL: String, model: String) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
    }
}