import Foundation

/// A GLP-1 medicine that can be picked when logging a dose. Brand names are
/// used only as labels, so a dose can be logged under the name on the box.
/// The doses listed are the strengths the medicines are sold in, offered as
/// shortcuts; Vitala never suggests which one to take.
struct GLP1Medication: Identifiable, Hashable {
    enum Schedule: String, Hashable {
        case weekly, daily, twiceDaily

        /// The usual gap between doses.
        var interval: TimeInterval {
            switch self {
            case .weekly: 7 * 86_400
            case .daily: 86_400
            case .twiceDaily: 43_200
            }
        }

        var label: String {
            switch self {
            case .weekly: "Once a week"
            case .daily: "Once a day"
            case .twiceDaily: "Twice a day"
            }
        }
    }

    enum Form: String, Hashable {
        case injection, tablet
    }

    let id: String
    let brand: String
    let generic: String
    let unit: String
    let strengths: [Double]
    let schedule: Schedule
    let form: Form

    /// "Wegovy (semaglutide)"
    var name: String { "\(brand) (\(generic))" }

    static let all: [GLP1Medication] = [
        .init(id: "wegovy", brand: "Wegovy", generic: "semaglutide", unit: "mg",
              strengths: [0.25, 0.5, 1, 1.7, 2.4], schedule: .weekly, form: .injection),
        .init(id: "ozempic", brand: "Ozempic", generic: "semaglutide", unit: "mg",
              strengths: [0.25, 0.5, 1, 2], schedule: .weekly, form: .injection),
        .init(id: "rybelsus", brand: "Rybelsus", generic: "semaglutide tablets", unit: "mg",
              strengths: [3, 7, 14], schedule: .daily, form: .tablet),
        .init(id: "zepbound", brand: "Zepbound", generic: "tirzepatide", unit: "mg",
              strengths: [2.5, 5, 7.5, 10, 12.5, 15], schedule: .weekly, form: .injection),
        .init(id: "mounjaro", brand: "Mounjaro", generic: "tirzepatide", unit: "mg",
              strengths: [2.5, 5, 7.5, 10, 12.5, 15], schedule: .weekly, form: .injection),
        .init(id: "saxenda", brand: "Saxenda", generic: "liraglutide", unit: "mg",
              strengths: [0.6, 1.2, 1.8, 2.4, 3], schedule: .daily, form: .injection),
        .init(id: "victoza", brand: "Victoza", generic: "liraglutide", unit: "mg",
              strengths: [0.6, 1.2, 1.8], schedule: .daily, form: .injection),
        .init(id: "trulicity", brand: "Trulicity", generic: "dulaglutide", unit: "mg",
              strengths: [0.75, 1.5, 3, 4.5], schedule: .weekly, form: .injection),
        .init(id: "bydureon", brand: "Bydureon BCise", generic: "exenatide", unit: "mg",
              strengths: [2], schedule: .weekly, form: .injection),
        .init(id: "byetta", brand: "Byetta", generic: "exenatide", unit: "mcg",
              strengths: [5, 10], schedule: .twiceDaily, form: .injection),
    ]

    /// For a medicine that isn't listed: the user types its name and dose.
    static let other = GLP1Medication(id: "other", brand: "Other", generic: "type the name", unit: "mg",
                                      strengths: [], schedule: .weekly, form: .injection)

    static func find(_ id: String) -> GLP1Medication? {
        id == other.id ? other : all.first { $0.id == id }
    }
}

/// One dose the user took.
struct GLP1Dose: Codable, Identifiable, Hashable {
    enum Site: String, Codable, CaseIterable, Identifiable {
        case abdomen, thigh, upperArm
        var id: String { rawValue }
        var label: String {
            switch self {
            case .abdomen: "Abdomen"
            case .thigh: "Thigh"
            case .upperArm: "Upper arm"
            }
        }
    }

    var id: String = UUID().uuidString
    var takenAt: Date
    /// A `GLP1Medication.id`, or "other".
    var medicationID: String
    /// Kept with the dose, so the log reads the same if the list changes.
    var medicationName: String
    var amount: Double
    var unit: String
    /// Nil for tablets, or when the user didn't say.
    var site: Site? = nil
    var notes: String? = nil

    /// "0.5 mg", "2.5 mg", "10 mcg": no trailing zeros.
    var amountText: String { Self.text(amount, unit: unit) }

    static func text(_ amount: Double, unit: String) -> String {
        "\(amount.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }

    var schedule: GLP1Medication.Schedule {
        GLP1Medication.find(medicationID)?.schedule ?? .weekly
    }
}

/// How the user felt: one or more symptoms, how strong, and any notes.
struct SideEffectEntry: Codable, Identifiable, Hashable {
    enum Symptom: String, Codable, CaseIterable, Identifiable {
        case nausea, vomiting, diarrhea, constipation, stomachPain, heartburn, bloating
        case lowAppetite, fatigue, headache, dizziness, injectionSite, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .nausea: "Nausea"
            case .vomiting: "Vomiting"
            case .diarrhea: "Diarrhea"
            case .constipation: "Constipation"
            case .stomachPain: "Stomach pain"
            case .heartburn: "Heartburn or reflux"
            case .bloating: "Bloating or gas"
            case .lowAppetite: "Low appetite"
            case .fatigue: "Tiredness"
            case .headache: "Headache"
            case .dizziness: "Dizziness"
            case .injectionSite: "Injection-site reaction"
            case .other: "Something else"
            }
        }
    }

    enum Severity: String, Codable, CaseIterable, Identifiable {
        case mild, moderate, severe
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var id: String = UUID().uuidString
    var date: Date
    var symptoms: [Symptom]
    var severity: Severity
    var notes: String? = nil

    /// "Nausea, Tiredness", in the order of the symptom list.
    var summary: String {
        let chosen = Symptom.allCases.filter(symptoms.contains).map(\.label)
        return chosen.isEmpty ? "No symptoms chosen" : chosen.joined(separator: ", ")
    }
}

/// What the doses logged so far say: the latest one, and when the next is
/// due on that medicine's usual schedule. Pure, so it can be tested.
enum GLP1Schedule {
    enum Due: Equatable {
        /// Due later: in this many whole days (0 means later today).
        case upcoming(days: Int)
        case today
        case overdue(days: Int)

        var text: String {
            switch self {
            case .today: "Next dose due today"
            case .upcoming(let days) where days <= 0: "Next dose due later today"
            case .upcoming(1): "Next dose due tomorrow"
            case .upcoming(let days): "Next dose due in \(days) days"
            case .overdue(1): "Next dose was due yesterday"
            case .overdue(let days): "Next dose was due \(days) days ago"
            }
        }
    }

    static func latest(_ doses: [GLP1Dose]) -> GLP1Dose? {
        doses.max { $0.takenAt < $1.takenAt }
    }

    /// When the next dose is due after the latest one logged.
    static func nextDue(after doses: [GLP1Dose]) -> Date? {
        guard let last = latest(doses) else { return nil }
        return last.takenAt.addingTimeInterval(last.schedule.interval)
    }

    /// For a weekly medicine the day matters, not the hour: a dose taken on
    /// Monday morning is due "today" all of next Monday.
    static func due(after doses: [GLP1Dose], now: Date = .now, calendar: Calendar = .current) -> Due? {
        guard let last = latest(doses), let next = nextDue(after: doses) else { return nil }
        if last.schedule != .weekly {
            if next > now { return .upcoming(days: 0) }
            let late = calendar.dateComponents([.day], from: calendar.startOfDay(for: next),
                                               to: calendar.startOfDay(for: now)).day ?? 0
            return late == 0 ? .today : .overdue(days: late)
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: next)).day ?? 0
        if days == 0 { return .today }
        return days > 0 ? .upcoming(days: days) : .overdue(days: -days)
    }
}
