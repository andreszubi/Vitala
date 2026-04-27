import Foundation

struct WaterEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var amountMl: Int
    var loggedAt: Date
    var icon: String = "drop.fill"
}

extension WaterEntry {
    static let quickAmounts: [Int] = [150, 250, 350, 500, 750]
}
