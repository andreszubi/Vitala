import Foundation

/// When each entry last changed, and when entries were deleted. This is
/// what lets two devices agree: the later change to an entry wins, and a
/// deletion is remembered so the entry doesn't come back from the other side.
struct ChangeLog: Codable, Equatable {
    /// The kinds of entry that sync, and the prefix of their keys.
    enum Kind: String, CaseIterable {
        case workout, meal, water, sleep, mindfulness, journal
        case customFood, favouriteFood, savedMeal, customWorkout
        case glp1Dose, sideEffect, weight
    }

    /// Entry key ("journal/1234") to the time it was added or last edited.
    var changed: [String: Date] = [:]
    /// Entry key to the time it was deleted.
    var deleted: [String: Date] = [:]
    /// Set by "Erase all data": everything changed at or before this time
    /// is gone, on every device.
    var erasedBefore: Date? = nil

    var isEmpty: Bool { changed.isEmpty && deleted.isEmpty && erasedBefore == nil }

    static func key(_ kind: Kind, _ id: String) -> String { kind.rawValue + "/" + id }

    mutating func markChanged(_ kind: Kind, _ id: String, at date: Date = .now) {
        let key = Self.key(kind, id)
        changed[key] = date
        deleted[key] = nil
    }

    mutating func markDeleted(_ kind: Kind, _ id: String, at date: Date = .now) {
        let key = Self.key(kind, id)
        changed[key] = nil
        deleted[key] = date
    }
}
