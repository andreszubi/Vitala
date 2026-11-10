import Foundation

/// A restaurant chain whose menu items USDA FoodData Central carries
/// (laboratory-analysed items in SR Legacy, plus survey foods in FNDDS).
/// Names are used only to label where a food comes from.
struct RestaurantChain: Identifiable, Hashable {
    /// How the chain is shown in the app.
    let name: String
    /// What to send USDA to list its items.
    let searchTerm: String
    /// Every spelling of the chain as a key: its name, what USDA is asked
    /// for, and any other spellings USDA uses.
    let keys: [String]
    /// Longest spelling first, so "Carrabba's Italian Grill" wins over "Carrabba's".
    let prefixKeys: [String]

    var id: String { name }

    init(name: String, searchTerm: String, aliases: [String] = []) {
        self.name = name
        self.searchTerm = searchTerm
        keys = ([name, searchTerm] + aliases).map(Self.key)
        prefixKeys = keys.sorted { $0.count > $1.count }
    }

    static let all: [RestaurantChain] = [
        .init(name: "McDonald's", searchTerm: "mcdonalds"),
        .init(name: "Wendy's", searchTerm: "wendys"),
        .init(name: "Burger King", searchTerm: "burger king"),
        .init(name: "Taco Bell", searchTerm: "taco bell"),
        .init(name: "KFC", searchTerm: "kfc"),
        .init(name: "Subway", searchTerm: "subway"),
        .init(name: "Pizza Hut", searchTerm: "pizza hut"),
        .init(name: "Domino's", searchTerm: "dominos"),
        .init(name: "Popeyes", searchTerm: "popeyes"),
        .init(name: "Papa John's", searchTerm: "papa johns"),
        .init(name: "Little Caesars", searchTerm: "little caesars"),
        .init(name: "Chick-fil-A", searchTerm: "chick-fil-a"),
        .init(name: "Arby's", searchTerm: "arbys"),
        .init(name: "Applebee's", searchTerm: "applebees"),
        .init(name: "Denny's", searchTerm: "dennys"),
        .init(name: "Olive Garden", searchTerm: "olive garden"),
        .init(name: "Cracker Barrel", searchTerm: "cracker barrel"),
        .init(name: "T.G.I. Friday's", searchTerm: "fridays", aliases: ["TGI Fridays", "Fridays"]),
        .init(name: "On the Border", searchTerm: "on the border"),
        .init(name: "Carrabba's", searchTerm: "carrabbas", aliases: ["Carrabba's Italian Grill"]),
    ]

    /// Letters and digits only, lowercased: "McDONALD'S" and "mcdonalds" match.
    static func key(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    /// The chain a search is asking for, when the whole query is its name.
    static func matching(_ query: String) -> RestaurantChain? {
        let wanted = key(query)
        guard !wanted.isEmpty else { return nil }
        return all.first { $0.keys.contains(wanted) }
    }

    /// Splits a USDA description into chain and item:
    /// "McDONALD'S, BIG MAC", "Big Mac (McDonalds)" and
    /// "Beverages, WENDY'S, tea, unsweetened" all name their chain.
    static func parse(_ description: String) -> (chain: RestaurantChain, item: String)? {
        // "Big Mac (McDonalds)"
        if description.hasSuffix(")"), let open = description.lastIndex(of: "(") {
            let inside = key(String(description[description.index(after: open)...]))
            if let chain = all.first(where: { $0.keys.contains(inside) }) {
                return (chain, itemName(String(description[..<open])))
            }
        }
        // "McDONALD'S, BIG MAC" and "PIZZA HUT 12" Cheese Pizza"
        for chain in all {
            for prefix in chain.prefixKeys {
                if let end = prefixEnd(of: prefix, in: description) {
                    return (chain, itemName(String(description[end...])))
                }
            }
        }
        // "Beverages, WENDY'S, tea, ready-to-drink"
        let parts = description.components(separatedBy: ", ")
        if parts.count > 2 {
            for (i, part) in parts.enumerated().dropFirst() {
                let partKey = key(part)
                if let chain = all.first(where: { $0.keys.contains(partKey) }) {
                    return (chain, itemName(parts[(i + 1)...].joined(separator: ", ")))
                }
            }
        }
        return nil
    }

    /// Where `prefix` (a key) ends in `text`, ignoring case, spaces and
    /// punctuation inside the name; nil if `text` doesn't start with it or
    /// the name runs straight on into another word.
    private static func prefixEnd(of prefix: String, in text: String) -> String.Index? {
        var remaining = Substring(prefix)
        var index = text.startIndex
        while let next = remaining.first {
            guard index < text.endIndex else { return nil }
            let character = text[index]
            if character.isLetter || character.isNumber {
                guard character.lowercased() == String(next) else { return nil }
                remaining = remaining.dropFirst()
            } else if !" '’.-".contains(character) {
                return nil
            }
            index = text.index(after: index)
        }
        // "SUBWAYS" isn't Subway, but "DOMINO'S 14"" is Domino's.
        if index < text.endIndex, text[index].isLetter { return nil }
        return index
    }

    private static let acronyms: Set<String> = ["BBQ", "BLT", "KFC", "XL"]

    /// Makes USDA's shouting readable: "BIG MAC" becomes "Big Mac",
    /// "Chicken McNUGGETS" becomes "Chicken McNuggets".
    static func itemName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
        let words = trimmed.split(separator: " ", omittingEmptySubsequences: true).map { word -> String in
            let token = String(word)
            let letters = token.filter(\.isLetter)
            guard letters.count >= 2, !acronyms.contains(letters) else { return token }
            if token.hasPrefix("Mc") {
                let rest = String(token.dropFirst(2))
                let restLetters = rest.filter(\.isLetter)
                guard restLetters.count >= 2, restLetters == restLetters.uppercased() else { return token }
                return "Mc" + capitalised(rest)
            }
            return letters == letters.uppercased() ? capitalised(token) : token
        }
        let joined = words.joined(separator: " ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    /// Lowercases a word and capitalises its first letter: "FRIDAY'S" → "Friday's".
    private static func capitalised(_ word: String) -> String {
        var result = word.lowercased()
        if let first = result.firstIndex(where: \.isLetter) {
            result.replaceSubrange(first...first, with: result[first].uppercased())
        }
        return result
    }
}
