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
        /// Nil when the source doesn't list it.
        var sugar: Double? = nil
        var saturatedFat: Double? = nil
        var sodiumMg: Double? = nil
        var monounsaturatedFat: Double? = nil
        var polyunsaturatedFat: Double? = nil
        var transFat: Double? = nil
    }

    /// Where the nutrition data came from, for attribution.
    enum Source: Hashable {
        case usda, openFoodFacts

        var attribution: String {
            switch self {
            case .usda: "Nutrition data from USDA FoodData Central."
            case .openFoodFacts: "Nutrition data from Open Food Facts (openfoodfacts.org), available under the Open Database License."
            }
        }
    }

    let id: Int            // FDC id, or the barcode for Open Food Facts
    let name: String
    let brand: String?
    let isBranded: Bool
    let per100g: Nutrients
    var portions: [Portion]
    var source: Source = .usda
    /// A restaurant menu item; `brand` then names the chain.
    var isRestaurant = false

    /// USDA lists some foods (laboratory-analysed ones, including most
    /// restaurant items) per 100 g only in search results; their real
    /// servings come from a second request.
    var needsPortionLookup: Bool { source == .usda && !isBranded && portions.count <= 1 }

    var defaultPortion: Portion { portions.first ?? Portion(label: "100 g", grams: 100) }

    /// Nutrients for `quantity` × `portion`.
    func nutrients(for portion: Portion, quantity: Double) -> Nutrients {
        let factor = portion.grams * quantity / 100
        return Nutrients(kcal: per100g.kcal * factor, protein: per100g.protein * factor,
                         carbs: per100g.carbs * factor, fat: per100g.fat * factor,
                         fiber: per100g.fiber * factor,
                         sugar: per100g.sugar.map { $0 * factor },
                         saturatedFat: per100g.saturatedFat.map { $0 * factor },
                         sodiumMg: per100g.sodiumMg.map { $0 * factor },
                         monounsaturatedFat: per100g.monounsaturatedFat.map { $0 * factor },
                         polyunsaturatedFat: per100g.polyunsaturatedFat.map { $0 * factor },
                         transFat: per100g.transFat.map { $0 * factor })
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
                        icon: isRestaurant ? "takeoutbag.and.cup.and.straw.fill" : isBranded ? "basket.fill" : "leaf.fill",
                        sugarG: n.sugar.map { ($0 * 10).rounded() / 10 },
                        saturatedFatG: n.saturatedFat.map { ($0 * 10).rounded() / 10 },
                        sodiumMg: n.sodiumMg.map { $0.rounded() },
                        monounsaturatedFatG: n.monounsaturatedFat.map { ($0 * 10).rounded() / 10 },
                        polyunsaturatedFatG: n.polyunsaturatedFat.map { ($0 * 10).rounded() / 10 },
                        transFatG: n.transFat.map { ($0 * 10).rounded() / 10 })
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
        // Phones type a curly apostrophe; USDA matches the straight one.
        let query = query.replacingOccurrences(of: "’", with: "'")
        if let chain = RestaurantChain.matching(query) {
            return try await menu(of: chain)
        }
        // POST so the "Survey (FNDDS)" data type (household portions) can be
        // requested; its parentheses are rejected in a query string.
        let data = try await post([
            "query": query,
            "dataType": ["Survey (FNDDS)", "Foundation", "SR Legacy", "Branded"],
            "pageSize": pageSize,
            "requireAllWords": true
        ])
        return try Self.parse(data)
    }

    /// Everything USDA lists for one restaurant chain, A to Z.
    func menu(of chain: RestaurantChain) async throws -> [FoodSearchResult] {
        let data = try await post([
            "query": chain.searchTerm,
            "dataType": ["Survey (FNDDS)", "SR Legacy"],
            "pageSize": 200,
            "requireAllWords": true
        ])
        return Self.menu(try Self.parse(data), of: chain)
    }

    /// The real servings of a food ("1 item", "1 medium"), for results that
    /// came back per 100 g only. Empty if USDA lists none.
    func portions(forFoodID id: Int) async throws -> [FoodSearchResult.Portion] {
        guard let apiKey else { throw SearchError.notConfigured }
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/food/\(id)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        let data = try await send(URLRequest(url: components.url!, timeoutInterval: 15))
        return Self.parsePortions(data)
    }

    private func post(_ body: [String: Any]) async throws -> Data {
        guard let apiKey else { throw SearchError.notConfigured }
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw SearchError.offline
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw SearchError.unavailable
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return data
        case 429: throw SearchError.rateLimited
        default: throw SearchError.unavailable
        }
    }

    /// Looks up a packaged food by its UPC / EAN among USDA branded foods.
    func food(barcode: String) async throws -> FoodSearchResult? {
        let data = try await post([
            "query": Barcode.digits(barcode), "dataType": ["Branded"], "pageSize": 10
        ])
        return try Self.parseBarcodeMatch(data, barcode: barcode)
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
        let gtinUpc: String?
        let foodCategory: String?
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

    /// The branded food whose GTIN matches the scanned code, if any. Search
    /// can also return foods that merely mention the digits, so match exactly.
    static func parseBarcodeMatch(_ data: Data, barcode: String) throws -> FoodSearchResult? {
        let foods = try JSONDecoder().decode(Response.self, from: data).foods
        let wanted = Barcode.canonical(barcode)
        return foods.first { $0.gtinUpc.map(Barcode.canonical) == wanted }.flatMap(result(from:))
    }

    private static func result(from food: Food) -> FoodSearchResult? {
        var values: [Int: Double] = [:]
        for n in food.foodNutrients ?? [] {
            if let id = n.nutrientId, let v = n.value { values[id] = v }
        }
        // Energy is 1008 (kcal) for most foods; Foundation foods may only
        // report the Atwater factors 2047 / 2048.
        guard let kcal = values[1008] ?? values[2047] ?? values[2048] else { return nil }
        // Sugars: 2000 (total incl. NLEA) or 1063; sodium 1093 (mg); fats:
        // saturated 1258, monounsaturated 1292, polyunsaturated 1293, trans 1257.
        let per100g = FoodSearchResult.Nutrients(kcal: kcal, protein: values[1003] ?? 0,
                                                 carbs: values[1005] ?? 0, fat: values[1004] ?? 0,
                                                 fiber: values[1079] ?? 0,
                                                 sugar: values[2000] ?? values[1063],
                                                 saturatedFat: values[1258],
                                                 sodiumMg: values[1093],
                                                 monounsaturatedFat: values[1292],
                                                 polyunsaturatedFat: values[1293],
                                                 transFat: values[1257])
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

        // Restaurant items: "McDONALD'S, BIG MAC" (lab-analysed) or
        // "Big Mac (McDonalds)" (survey). Packaged foods keep their own brand.
        if !isBranded, let restaurant = RestaurantChain.parse(food.description) {
            return FoodSearchResult(id: food.fdcId, name: restaurant.item, brand: restaurant.chain.name,
                                    isBranded: false, per100g: per100g, portions: portions,
                                    isRestaurant: true)
        }
        let brand = [food.brandName, food.brandOwner].compactMap { $0 }.first.map(tidy)
        return FoodSearchResult(id: food.fdcId, name: tidy(food.description), brand: brand,
                                isBranded: isBranded, per100g: per100g, portions: portions,
                                isRestaurant: ["Fast Foods", "Restaurant Foods"].contains(food.foodCategory ?? ""))
    }

    /// One chain's items from a set of results: only that chain, one entry
    /// per item (the one with real servings wins), A to Z.
    static func menu(_ results: [FoodSearchResult], of chain: RestaurantChain) -> [FoodSearchResult] {
        var byName: [String: FoodSearchResult] = [:]
        for result in results where result.isRestaurant && result.brand == chain.name {
            let key = RestaurantChain.key(result.name)
            if let existing = byName[key], existing.portions.count >= result.portions.count { continue }
            byName[key] = result
        }
        return byName.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private struct FoodDetail: Decodable {
        struct Portion: Decodable {
            struct Unit: Decodable { let name: String? }
            let amount: Double?
            let modifier: String?
            let gramWeight: Double?
            let portionDescription: String?
            let measureUnit: Unit?
        }
        let foodPortions: [Portion]?
    }

    /// Servings from a food's detail record. Survey foods describe them in
    /// words ("1 banana"); lab-analysed ones as an amount and a unit
    /// ("1" + "item 7.6 oz").
    static func parsePortions(_ data: Data) -> [FoodSearchResult.Portion] {
        guard let detail = try? JSONDecoder().decode(FoodDetail.self, from: data) else { return [] }
        var portions: [FoodSearchResult.Portion] = []
        for p in detail.foodPortions ?? [] {
            guard let grams = p.gramWeight, grams > 0 else { continue }
            let label: String
            if let text = p.portionDescription, !text.isEmpty, text != "Quantity not specified" {
                label = text
            } else {
                let unit = [p.modifier, p.measureUnit?.name]
                    .compactMap { $0 }
                    .first { !$0.isEmpty && $0 != "undetermined" }
                guard let unit else { continue }
                let amount = (p.amount ?? 1).formatted(.number.precision(.fractionLength(0...2)))
                label = "\(amount) \(unit)"
            }
            guard !portions.contains(where: { $0.label == label }) else { continue }
            portions.append(.init(label: label, grams: grams))
        }
        return portions
    }

    /// Branded names arrive in capitals ("PEANUT BUTTER"); make them readable.
    static func tidy(_ text: String) -> String {
        let letters = text.filter(\.isLetter)
        guard !letters.isEmpty, letters == letters.uppercased() else { return text }
        let lower = text.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }
}
