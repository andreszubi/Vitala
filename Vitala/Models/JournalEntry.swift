import Foundation

/// A free-form reflection with a mood, written on its own or after a
/// mindful session.
struct JournalEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var mood: Mood
    var text: String
    /// The session this entry followed, if any.
    var sessionId: String? = nil
    var sessionTitle: String? = nil

    enum Mood: String, Codable, CaseIterable, Identifiable {
        case great, good, calm, okay, tired, anxious, stressed, sad, frustrated
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        /// How light or heavy the mood is, from 1 (low) to 5 (great), so
        /// days can be averaged and compared. Several moods share a score:
        /// it places a mood on a scale, it doesn't rank one person's feelings.
        var score: Int {
            switch self {
            case .great: 5
            case .good, .calm: 4
            case .okay: 3
            case .tired, .anxious, .stressed: 2
            case .sad, .frustrated: 1
            }
        }

        var icon: String {
            switch self {
            case .great: "sun.max.fill"
            case .good: "face.smiling"
            case .calm: "leaf.fill"
            case .okay: "cloud.sun.fill"
            case .tired: "moon.zzz.fill"
            case .anxious: "wind"
            case .stressed: "bolt.fill"
            case .sad: "cloud.rain.fill"
            case .frustrated: "flame.fill"
            }
        }
    }

    /// The first line of the entry, for lists.
    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        guard !firstLine.isEmpty else { return "No notes" }
        return firstLine.count > 80 ? firstLine.prefix(79) + "…" : firstLine
    }
}
