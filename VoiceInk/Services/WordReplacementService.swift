import Foundation

class WordReplacementService {
    static let shared = WordReplacementService()
    
    private init() {}
    
    func applyReplacements(to text: String) -> String {
        guard let replacements = UserDefaults.standard.dictionary(forKey: "wordReplacements") as? [String: String],
              !replacements.isEmpty else {
            return text // No replacements to apply
        }
        
        var modifiedText = text
        
        // Apply replacements (case-insensitive)
        for (original, replacement) in replacements {
            let isPhrase = original.contains(" ") || original.trimmingCharacters(in: .whitespacesAndNewlines) != original

            if isPhrase || !usesWordBoundaries(for: original) {
                modifiedText = modifiedText.replacingOccurrences(of: original, with: replacement, options: .caseInsensitive)
            } else {
                // Use word boundaries for spaced languages
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: original))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(modifiedText.startIndex..., in: modifiedText)
                    modifiedText = regex.stringByReplacingMatches(
                        in: modifiedText,
                        options: [],
                        range: range,
                        withTemplate: replacement
                    )
                }
            }
        }
        
        return modifiedText
    }

    private func usesWordBoundaries(for text: String) -> Bool {
        // Returns false for languages without spaces (CJK, Thai), true for spaced languages
        let nonSpacedScripts: [ClosedRange<UInt32>] = [
            0x3040...0x309F, // Hiragana
            0x30A0...0x30FF, // Katakana
            0x4E00...0x9FFF, // CJK Unified Ideographs
            0xAC00...0xD7AF, // Hangul Syllables
            0x0E00...0x0E7F, // Thai
        ]

        for scalar in text.unicodeScalars {
            for range in nonSpacedScripts {
                if range.contains(scalar.value) {
                    return false
                }
            }
        }

        return true
    }
}
