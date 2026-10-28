import UIKit

/// Small wrapper so logging actions feel acknowledged.
enum Haptics {
    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
