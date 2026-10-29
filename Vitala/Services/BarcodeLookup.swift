import Foundation

/// Barcode helpers. Retail codes come as UPC-A (12 digits), EAN-13 (13) or
/// GTIN-14, and the same product is often stored with or without leading
/// zeros, so comparisons use a canonical form.
enum Barcode {
    static func digits(_ code: String) -> String {
        code.filter(\.isNumber)
    }

    /// Digits without leading zeros: "0016459200441" and "016459200441" match.
    static func canonical(_ code: String) -> String {
        let d = digits(code)
        let trimmed = d.drop { $0 == "0" }
        return trimmed.isEmpty ? d : String(trimmed)
    }

    /// Plausible retail barcode lengths (EAN-8, UPC-E, UPC-A, EAN-13, GTIN-14).
    static func isValid(_ code: String) -> Bool {
        [8, 12, 13, 14].contains(digits(code).count) || digits(code).count == 6
    }
}

/// Looks up packaged foods on Open Food Facts (https://openfoodfacts.org),
/// a free, open database with wide barcode coverage. No key needed; their
/// rules ask apps to identify themselves in the User-Agent.
struct OpenFoodFactsClient {
    var session: URLSession = .shared

    func food(barcode: String) async throws -> FoodSearchResult? {
        let code = Barcode.digits(barcode)
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json")!
        components.queryItems = [URLQueryItem(name: "fields",
                                              value: "code,product_name,brands,nutriments,serving_size,serving_quantity")]
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("Vitala/\(AppInfo.version) (iOS; https://github.com/andreszubi/Vitala)",
                         forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return Self.parse(data, barcode: code)
        case 404: return nil
        case 429: throw FoodDatabaseClient.SearchError.rateLimited
        default: throw FoodDatabaseClient.SearchError.unavailable
        }
    }

    static func parse(_ data: Data, barcode: String) -> FoodSearchResult? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["status"] as? Int) == 1,
              let product = root["product"] as? [String: Any],
              let nutriments = product["nutriments"] as? [String: Any] else { return nil }

        func number(_ value: Any?) -> Double? {
            if let d = value as? Double { return d }
            if let i = value as? Int { return Double(i) }
            if let s = value as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
            return nil
        }
        // Prefer kcal; some products only list kJ.
        guard let kcal = number(nutriments["energy-kcal_100g"]) ?? number(nutriments["energy_100g"]).map({ $0 / 4.184 })
        else { return nil }

        let per100g = FoodSearchResult.Nutrients(
            kcal: kcal,
            protein: number(nutriments["proteins_100g"]) ?? 0,
            carbs: number(nutriments["carbohydrates_100g"]) ?? 0,
            fat: number(nutriments["fat_100g"]) ?? 0,
            fiber: number(nutriments["fiber_100g"]) ?? 0,
            sugar: number(nutriments["sugars_100g"]),
            saturatedFat: number(nutriments["saturated-fat_100g"]),
            // Sodium is listed in grams; some products only list salt (2.5 × sodium).
            sodiumMg: number(nutriments["sodium_100g"]).map { $0 * 1000 }
                ?? number(nutriments["salt_100g"]).map { $0 * 400 },
            monounsaturatedFat: number(nutriments["monounsaturated-fat_100g"]),
            polyunsaturatedFat: number(nutriments["polyunsaturated-fat_100g"]),
            transFat: number(nutriments["trans-fat_100g"]))

        var portions: [FoodSearchResult.Portion] = []
        if let grams = number(product["serving_quantity"]), grams > 0 {
            let label = (product["serving_size"] as? String).map { "1 serving (\($0))" } ?? "1 serving (\(Int(grams.rounded())) g)"
            portions.append(.init(label: label, grams: grams))
        }
        portions.append(.init(label: "100 g", grams: 100))

        let name = (product["product_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Scanned product"
        let brand = (product["brands"] as? String)?
            .split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        return FoodSearchResult(id: Int(Barcode.canonical(barcode)) ?? barcode.hashValue,
                                name: FoodDatabaseClient.tidy(name), brand: brand.map(FoodDatabaseClient.tidy),
                                isBranded: true, per100g: per100g, portions: portions, source: .openFoodFacts)
    }
}

/// Finds a product by barcode: USDA branded foods first (US labels), then
/// Open Food Facts (worldwide).
struct BarcodeLookup {
    var usda = FoodDatabaseClient()
    var openFoodFacts = OpenFoodFactsClient()

    func food(barcode: String) async throws -> FoodSearchResult? {
        var lastError: Error?
        if usda.isConfigured {
            do {
                if let found = try await usda.food(barcode: barcode) { return found }
            } catch {
                lastError = error
            }
        }
        do {
            return try await openFoodFacts.food(barcode: barcode)
        } catch {
            if let urlError = error as? URLError,
               urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                throw FoodDatabaseClient.SearchError.offline
            }
            throw lastError ?? error
        }
    }
}
