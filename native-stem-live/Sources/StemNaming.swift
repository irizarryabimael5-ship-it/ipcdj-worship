import Foundation

enum StemNaming {
    private static let genericSongTitles = ["new song", "untitled", "song"]

    private static let instrumentRules: [(tokens: [String], name: String, route: StemRoute)] = [
        (["full mix", "fullmix", "original", "master", "reference", "ref"], "Full Mix", .reference),
        (["click", "metronome"], "Click", .click),
        (["cue", "cues", "guide"], "Cues", .click),
        (["drums", "drum", "kit"], "Drums", .music),
        (["percussion", "perc"], "Percussion", .music),
        (["bass"], "Bass", .music),
        (["acoustic guitar", "ac gtr", "acoustic", "agtr"], "Acoustic Guitar", .music),
        (["electric guitar", "el gtr", "electric", "egtr", "guitar", "gtr"], "Electric Guitar", .music),
        (["piano"], "Piano", .music),
        (["keys", "keyboard", "keyboards"], "Keys", .music),
        (["synth", "synths"], "Synth", .music),
        (["strings", "string"], "Strings", .music),
        (["lead vocal", "lead vox", "leadvox", "lvoc", "vocal lead"], "Lead Vocal", .music),
        (["backing vocals", "background vocals", "bgv", "bGV", "backing vox", "choir"], "Backing Vocals", .music),
        (["vocals", "vocal", "vox"], "Vocals", .music),
        (["organ", "hammond"], "Organ", .music),
        (["brass", "horns", "horn"], "Brass", .music),
        (["tracks", "track"], "Tracks", .music)
    ]

    struct Suggestion: Sendable {
        var displayName: String
        var route: StemRoute
    }

    static func suggestion(for fileName: String) -> Suggestion {
        let base = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let normalized = searchable(base)

        for rule in instrumentRules {
            if rule.tokens.contains(where: { token in normalized.contains(searchable(token)) }) {
                return Suggestion(displayName: rule.name, route: rule.route)
            }
        }

        return Suggestion(displayName: professionalize(base), route: .music)
    }

    static func suggestedSongTitle(from fileNames: [String]) -> String? {
        guard !fileNames.isEmpty else { return nil }
        var candidates: [String] = []

        for fileName in fileNames {
            let base = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            var cleaned = base

            // Remove common export metadata and the detected stem/instrument label.
            let suggestion = suggestion(for: fileName)
            let removalTokens = instrumentRules.flatMap(\.tokens) + [suggestion.displayName]
            for token in removalTokens {
                cleaned = removeToken(token, from: cleaned)
            }
            cleaned = cleaned.replacingOccurrences(
                of: #"(?i)\b\d{2,3}(?:\.\d+)?\s*bpm\b|\b(?:44\.1|48|88\.2|96|176\.4|192)\s*k(?:hz)?\b|\b(?:16|24|32)\s*bit\b|\b(?:stem|stems|multitrack|multitracks|trackout|trackouts)\b"#,
                with: " ",
                options: .regularExpression
            )
            cleaned = cleanupSeparators(cleaned)
            if cleaned.count >= 2 { candidates.append(cleaned) }
        }

        guard !candidates.isEmpty else { return nil }

        // Prefer a normalized title shared by most stems. If filenames vary,
        // use the longest common word-prefix instead of inventing metadata.
        let normalizedGroups = Dictionary(grouping: candidates, by: { searchable($0) })
        if let group = normalizedGroups.max(by: { $0.value.count < $1.value.count }),
           group.value.count >= max(1, fileNames.count / 2) {
            let title = professionalize(group.value[0])
            return genericSongTitles.contains(title.lowercased()) ? nil : title
        }

        let words = candidates.map { $0.split(separator: " ").map(String.init) }
        guard var prefix = words.first else { return nil }
        for row in words.dropFirst() {
            var length = 0
            while length < min(prefix.count, row.count),
                  searchable(prefix[length]) == searchable(row[length]) {
                length += 1
            }
            prefix = Array(prefix.prefix(length))
            if prefix.isEmpty { break }
        }

        let title = cleanupSeparators(prefix.joined(separator: " "))
        guard title.count >= 2, !genericSongTitles.contains(title.lowercased()) else { return nil }
        return professionalize(title)
    }

    static func uniqueDisplayNames(for fileNames: [String]) -> [String] {
        var counts: [String: Int] = [:]
        return fileNames.map { fileName in
            let base = suggestion(for: fileName).displayName
            counts[base, default: 0] += 1
            let n = counts[base] ?? 1
            return n == 1 ? base : "\(base) \(n)"
        }
    }

    static func isGenericSongTitle(_ title: String) -> Bool {
        genericSongTitles.contains(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func searchable(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeToken(_ token: String, from value: String) -> String {
        guard !token.isEmpty else { return value }
        return value.replacingOccurrences(of: token, with: " ", options: [.caseInsensitive])
    }

    private static func cleanupSeparators(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"[_\-–—|]+|\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "._-–—|()[]{}")))
    }

    private static func professionalize(_ value: String) -> String {
        let cleaned = cleanupSeparators(value)
        guard !cleaned.isEmpty else { return "Stem" }
        // Preserve deliberate capitalization when it already contains lowercase.
        if cleaned.rangeOfCharacter(from: .lowercaseLetters) != nil { return cleaned }
        return cleaned.capitalized
    }
}
