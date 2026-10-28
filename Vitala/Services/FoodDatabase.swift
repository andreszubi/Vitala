import Foundation

/// A food from USDA FoodData Central, with nutrients per 100 g and the
/// portions people actually eat ("1 banana", "2 Tbsp").
struct FoodSearchResult: Identifiable, Hashable {
    struct Portion: Hashable, Identifiable {
        let label: String
        let grams: Double
        var id: String { "\(label)-\(grams)" }
    }

    struct Nutrients: Hashable {
        var kcal: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
    }

    let id: Int            // FDC id
    let name: String
    let brand: String?
    let isBranded: Bool
    let per100g: Nutrients
    let portions: [Portion]

    var defaultPortion: Portion { portions.first ?? Portion(label: "100 g", grams: 100) }

    /// Nutrients for `quantity` × `portion`.
    func nutrients(for portion: Portion, quantity: Double) -> Nutrients {
        let factor = portion.grams * quantity / 100
        return Nutrients(kcal: per100g.kcal * factor, protein: per100g.protein * factor,
                         carbs: per100g.carbs * factor, fat: per100g.fat * factor,
                         fiber: per100g.fiber * factor)
    }

    /// A loggable item for `quantity` × `portion`.
    func foodItem(portion: Portion, quantity: Double) -> FoodItem {
        let n = nutrients(for: portion, quantity: quantity)
        let amount = quantity == 1 ? portion.label : "\(quantity.formatted()) × \(portion.label)"
        return FoodItem(name: name,
                        brand: brand,
                        servingSize: "\(amount) (\(Int((portion.grams * quantity).rounded())) g)",
                        calories: Int(n.kcal.rounded()),
                        proteinG: (n.protein * 10).rounded() / 10,
                        carbsG: (n.carbs * 10).rounded() / 10,
                        fatG: (n.fat * 10).rounded() / 10,
                        fiberG: (n.fiber * 10).rounded() / 10,
                        icon: isBranded ? "barcode" : "leaf.fill")
    }
}

/// Searches USDA FoodData Central (https://fdc.nal.usda.gov). Data is public
/// domain; only the words typed are sent, with no user identifiers.
struct FoodDatabaseClient {
    enum SearchError: LocalizedError {
        case notConfigured, rateLimited, offline, unavailable

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Online food search isn't set up in this build."
            case .rateLimited: "The food database is busy. Try again in a few minutes."
            case .offline: "You're offline. Showing foods saved on this iPhone."
            case .unavailable: "Couldn't reach the food database. Try again shortly."
            }
        }
    }

    var apiKey: String? = FoodDatabaseClient.configuredKey
    var session: URLSession = .shared

    /// The key from Config/Secrets.xcconfig, passed through Info.plist.
    /// Debug builds without a key use USDA's shared, rate-limited DEMO_KEY.
    static var configuredKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "USDAAPIKey") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if !key.isEmpty && !key.hasPrefix("$(") { return key }
        #if DEBUG
        return "DEMO_KEY"
        #else
        return nil
        #endif
    }

    var isConfigured: Bool { apiKey != nil }

    func search(_ query: String, pageSize: Int = 25) async throws -> [FoodSearchResult] {
        guard let apiKey else { throw SearchError.notConfigured }
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // POST so the "Survey (FNDDS)" data type (household portions) can be
        // requested; its parentheses are rejected in a query string.
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "dataType": ["Survey (FNDDS)", "Foundation", "SR Legacy", "Branded"],
            "pageSize": pageSize,
            "requireAllWords": true
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw SearchError.offline
        } catch {
            throw SearchError.unavailable
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 429: throw SearchError.rateLimited
        default: throw SearchError.unavailable
        }
        return try Self.parse(data)
    }

    // MARK: Parsing

    private struct Response: Decodable {
        let foods: [Food]
    }

    private struct Food: Decodable {
        let fdcId: Int
        let description: String
        let dataType: String?
        let brandOwner: String?
        let brandName: String?
        let servingSize: Double?
        let servingSizeUnit: String?
        let householdServingFullText: String?
        let foodNutrients: [Nutrient]?
        let foodMeasures: [Measure]?
    }

    private struct Nutrient: Decodable {
        let nutrientId: Int?
        let value: Double?
    }

    private struct Measure: Decodable {
        let disseminationText: String?
        let gramWeight: Double?
    }

    static func parse(_ data: Data) throws -> [FoodSearchResult] {
        let foods = try JSONDecoder().decode(Response.self, from: data).foods
        let results = foods.compactMap(result(from:))
        // Generic foods first: "Banana, raw" beats a peanut butter called BANANA.
        return results.filter { !$0.isBranded } + results.filter(\.isBranded)
    }

    private static func result(from food: Food) -> FoodSearchResult? {
        var values: [Int: Double] = [:]
        for n in food.foodNutrients ?? [] {
            if let id = n.nutrientId, let v = n.value { values[id] = v }
        }
        // Energy is 1008 (kcal) for most foods; Foundation foods may only
        // report the Atwater factors 2047 / 2048.
        guard let kcal = values[1008] ?? values[2047] ?? values[2048] else { return nil }
        let per100g = FoodSearchResult.Nutrients(kcal: kcal, protein: values[1003] ?? 0,
                                                 carbs: values[1005] ?? 0, fat: values[1004] ?? 0,
                                                 fiber: values[1079] ?? 0)
        let isBranded = food.dataType == "Branded"

        var portions: [FoodSearchResult.Portion] = []
        if isBranded, let size = food.servingSize, size > 0,
           let unit = food.servingSizeUnit?.lowercased(), ["g", "grm", "ml", "mlt"].contains(unit) {
            let household = food.householdServingFullText.map(tidy)?.lowercased()
            let label = household.map { "\($0) (\(Int(size.rounded())) \(unit.hasPrefix("m") ? "ml" : "g"))" }
                ?? "1 serving"
            portions.append(.init(label: label, grams: size))
        }
        for m in food.foodMeasures ?? [] {
            guard let raw = m.disseminationText, let grams = m.gramWeight, grams > 0,
                  raw != "Quantity not specified" else { continue }
            // "NFS" is USDA shorthand for "not further specified".
            let text = raw.replacingOccurrences(of: ", NFS", with: "")
                .replacingOccurrences(of: " (NFS)", with: "")
            guard !portions.contains(where: { $0.label == text }) else { continue }
            portions.append(.init(label: text, grams: grams))
        }
        portions.append(.init(label: "100 g", grams: 100))

        let brand = [food.brandName, food.brandOwner].compactMap { $0 }.first.map(tidy)
        return FoodSearchResult(id: food.fdcId, name: tidy(food.description), brand: brand,
                                isBranded: isBranded, per100g: per100g, portions: portions)
    }

    /// Branded names arrive in capitals ("PEANUT BUTTER"); make them readable.
    static func tidy(_ text: String) -> String {
        let letters = text.filter(\.isLetter)
        guard !letters.isEmpty, letters == letters.uppercased() else { return text }
        let lower = text.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }
}
