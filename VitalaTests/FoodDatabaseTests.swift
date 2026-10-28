import Foundation
import Testing
@testable import Vitala

/// Parsing tests against a trimmed real response from USDA FoodData Central.
struct FoodDatabaseTests {
    private static let fixture = #"""
    {"totalHits":2,"foods":[{"fdcId":2012128,"description":"BANANA","dataType":"Branded","brandOwner":"Wonder Natural Foods Corp","brandName":"BETTER'N PEANUT BUTTER","servingSize":32.0,"servingSizeUnit":"g","householdServingFullText":"2 Tbsp","foodNutrients":[{"nutrientId":1003,"nutrientName":"Protein","value":12.5,"unitName":"G"},{"nutrientId":1004,"nutrientName":"Total lipid (fat)","value":6.25,"unitName":"G"},{"nutrientId":1005,"nutrientName":"Carbohydrate, by difference","value":40.6,"unitName":"G"},{"nutrientId":1008,"nutrientName":"Energy","value":312,"unitName":"KCAL"},{"nutrientId":1079,"nutrientName":"Fiber, total dietary","value":6.2,"unitName":"G"}]},{"fdcId":2709224,"description":"Banana, raw","dataType":"Survey (FNDDS)","foodNutrients":[{"nutrientId":1003,"nutrientName":"Protein","value":0.74,"unitName":"G"},{"nutrientId":1004,"nutrientName":"Total lipid (fat)","value":0.28,"unitName":"G"},{"nutrientId":1005,"nutrientName":"Carbohydrate, by difference","value":22.71,"unitName":"G"},{"nutrientId":1008,"nutrientName":"Energy","value":97,"unitName":"KCAL"},{"nutrientId":1079,"nutrientName":"Fiber, total dietary","value":1.7,"unitName":"G"}],"foodMeasures":[{"disseminationText":"1 cup, mashed","gramWeight":225},{"disseminationText":"1 banana","gramWeight":126},{"disseminationText":"1 cup","gramWeight":150},{"disseminationText":"1 slice","gramWeight":6},{"disseminationText":"Quantity not specified","gramWeight":126},{"disseminationText":"1 linear inch","gramWeight":15}]}]}
    """#

    private func results() throws -> [FoodSearchResult] {
        try FoodDatabaseClient.parse(Data(Self.fixture.utf8))
    }

    @Test func genericFoodsRankAboveBranded() throws {
        let r = try results()
        #expect(r.map(\.name) == ["Banana, raw", "Banana"])
        #expect(r[0].isBranded == false)
        #expect(r[1].isBranded == true)
    }

    @Test func householdPortionsSkipUnspecifiedAndEndWith100g() throws {
        let banana = try results()[0]
        #expect(banana.portions.map(\.label) == ["1 cup, mashed", "1 banana", "1 cup", "1 slice", "1 linear inch", "100 g"])
        #expect(banana.portions.first { $0.label == "1 banana" }?.grams == 126)
    }

    @Test func scalesNutrientsToThePortion() throws {
        let banana = try results()[0]
        let one = try #require(banana.portions.first { $0.label == "1 banana" })
        let item = banana.foodItem(portion: one, quantity: 1)
        #expect(item.calories == 122)              // 97 kcal/100 g × 126 g
        #expect(item.carbsG == 28.6)
        #expect(item.servingSize == "1 banana (126 g)")

        let two = banana.foodItem(portion: one, quantity: 2)
        #expect(two.calories == 244)
        #expect(two.servingSize == "2 × 1 banana (252 g)")
    }

    @Test func brandedUsesTheLabelServing() throws {
        let branded = try results()[1]
        #expect(branded.brand == "Better'n peanut butter")
        #expect(branded.defaultPortion.label == "2 tbsp (32 g)")
        #expect(branded.foodItem(portion: branded.defaultPortion, quantity: 1).calories == 100)
    }

    @Test func foodsWithoutEnergyAreSkipped() throws {
        let json = #"{"foods":[{"fdcId":1,"description":"Mystery","dataType":"Branded","foodNutrients":[{"nutrientId":1003,"value":2}]}]}"#
        #expect(try FoodDatabaseClient.parse(Data(json.utf8)).isEmpty)
    }

    @Test func dropsNotFurtherSpecifiedJargon() throws {
        let json = #"{"foods":[{"fdcId":7,"description":"Yogurt, Greek, with oats","dataType":"Survey (FNDDS)","foodNutrients":[{"nutrientId":1008,"value":130}],"foodMeasures":[{"disseminationText":"1 container, NFS","gramWeight":150},{"disseminationText":"1 fl oz (NFS)","gramWeight":31}]}]}"#
        let food = try #require(try FoodDatabaseClient.parse(Data(json.utf8)).first)
        #expect(food.portions.map(\.label) == ["1 container", "1 fl oz", "100 g"])
    }

    @Test func tidiesAllCapsNamesOnly() {
        #expect(FoodDatabaseClient.tidy("GREEK YOGURT") == "Greek yogurt")
        #expect(FoodDatabaseClient.tidy("Banana, raw") == "Banana, raw")
    }

    @Test func debugBuildsHaveAKey() {
        #expect(FoodDatabaseClient().isConfigured)
    }
}

/// Barcode lookups against trimmed real responses.
struct BarcodeTests {
    @Test func canonicalFormMatchesUPCAndEAN() {
        #expect(Barcode.canonical("016459200441") == Barcode.canonical("0016459200441"))
        #expect(Barcode.canonical("3017620422003") == "3017620422003")
        #expect(Barcode.isValid("016459200441"))
        #expect(!Barcode.isValid("12345"))
    }

    @Test func usdaMatchesOnlyTheExactGTIN() throws {
        let json = #"""
        {"foods":[
          {"fdcId":1,"gtinUpc":"099999999999","description":"OTHER","dataType":"Branded","foodNutrients":[{"nutrientId":1008,"value":50}]},
          {"fdcId":2012128,"gtinUpc":"016459200441","description":"BANANA","dataType":"Branded","brandName":"BETTER'N PEANUT BUTTER","brandOwner":"Wonder Natural Foods Corp","servingSize":32.0,"servingSizeUnit":"g","householdServingFullText":"2 Tbsp","foodNutrients":[{"nutrientId":1008,"value":312},{"nutrientId":1003,"value":12.5}]}
        ]}
        """#
        // Scanned as EAN-13 with a leading zero.
        let match = try #require(try FoodDatabaseClient.parseBarcodeMatch(Data(json.utf8), barcode: "0016459200441"))
        #expect(match.id == 2012128)
        #expect(match.defaultPortion.label == "2 tbsp (32 g)")
        #expect(try FoodDatabaseClient.parseBarcodeMatch(Data(json.utf8), barcode: "012345678905") == nil)
    }

    @Test func openFoodFactsProductParses() throws {
        let json = #"{"code":"3017620422003","status":1,"product":{"product_name":"Nutella","brands":"Nutella, Ferrero","nutriments":{"carbohydrates_100g":57.5,"energy-kcal_100g":539,"energy_100g":2252,"fat_100g":30.9,"fiber_100g":0,"proteins_100g":6.3}}}"#
        let food = try #require(OpenFoodFactsClient.parse(Data(json.utf8), barcode: "3017620422003"))
        #expect(food.name == "Nutella")
        #expect(food.brand == "Nutella")
        #expect(food.source == .openFoodFacts)
        #expect(food.per100g.kcal == 539)
        #expect(food.defaultPortion.label == "100 g")
    }

    @Test func openFoodFactsFallsBackToKilojoulesAndServing() throws {
        let json = #"{"status":1,"product":{"product_name":"Oat bar","serving_size":"40 g","serving_quantity":"40","nutriments":{"energy_100g":1674,"proteins_100g":"8,5"}}}"#
        let food = try #require(OpenFoodFactsClient.parse(Data(json.utf8), barcode: "12345670"))
        #expect(Int(food.per100g.kcal.rounded()) == 400)
        #expect(food.per100g.protein == 8.5)
        #expect(food.defaultPortion == .init(label: "1 serving (40 g)", grams: 40))
        #expect(food.foodItem(portion: food.defaultPortion, quantity: 1).calories == 160)
    }

    @Test func unknownProductReturnsNil() {
        let json = #"{"code":"0000","status":0,"status_verbose":"product not found"}"#
        #expect(OpenFoodFactsClient.parse(Data(json.utf8), barcode: "0000") == nil)
    }
}
