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

    @Test func usdaDetailedNutrientsScaleAndMissingOnesStayUnlisted() throws {
        let json = #"{"foods":[{"fdcId":1,"description":"OAT MILK","dataType":"Branded","brandName":"OATLY","servingSize":240,"servingSizeUnit":"ml","foodNutrients":[{"nutrientId":1008,"value":50},{"nutrientId":1003,"value":1},{"nutrientId":1004,"value":2.5},{"nutrientId":1005,"value":6.7},{"nutrientId":2000,"value":3},{"nutrientId":1258,"value":0.2},{"nutrientId":1292,"value":1.5},{"nutrientId":1293,"value":0.7},{"nutrientId":1257,"value":0},{"nutrientId":1093,"value":42}]}]}"#
        let oat = try #require(try FoodDatabaseClient.parse(Data(json.utf8)).first)
        let item = oat.foodItem(portion: oat.defaultPortion, quantity: 1)   // 240 ml
        #expect(item.sugarG == 7.2)
        #expect(item.saturatedFatG == 0.5)
        #expect(item.monounsaturatedFatG == 3.6)
        #expect(item.polyunsaturatedFatG == 1.7)
        #expect(item.transFatG == 0)
        #expect(item.sodiumMg == 101)
        #expect(item.unsaturatedFatG == 5.3)
        #expect(item.fullName == "Oatly Oat milk")

        // A food that lists none of these: unknown, not zero.
        let plain = #"{"foods":[{"fdcId":2,"description":"Banana, raw","dataType":"Foundation","foodNutrients":[{"nutrientId":1008,"value":97}]}]}"#
        let bananaFood = try #require(try FoodDatabaseClient.parse(Data(plain.utf8)).first)
        let banana = bananaFood.foodItem(portion: bananaFood.defaultPortion, quantity: 1)
        #expect(banana.sugarG == nil && banana.saturatedFatG == nil && banana.sodiumMg == nil)
        #expect(banana.unsaturatedFatG == nil)
    }

    @Test func openFoodFactsDetailedNutrients() throws {
        let json = #"{"status":1,"product":{"product_name":"Pre-biotic fiber formula","brands":"Loam","serving_quantity":10,"serving_size":"1 scoop (10 g)","nutriments":{"energy-kcal_100g":250,"proteins_100g":0,"carbohydrates_100g":80,"fat_100g":0,"fiber_100g":60,"sugars_100g":2,"saturated-fat_100g":0,"monounsaturated-fat_100g":0,"polyunsaturated-fat_100g":0,"trans-fat_100g":0,"salt_100g":0.375}}}"#
        let food = try #require(OpenFoodFactsClient.parse(Data(json.utf8), barcode: "850000000001"))
        let item = food.foodItem(portion: food.defaultPortion, quantity: 1)
        #expect(item.fullName == "Loam Pre-biotic fiber formula")
        #expect(item.fiberG == 6)
        #expect(item.sugarG == 0.2)
        #expect(item.sodiumMg == 15)              // from salt: 0.375 g × 400 per 100 g
        #expect(item.displayIcon != "barcode")
    }

    @Test func unknownProductReturnsNil() {
        let json = #"{"code":"0000","status":0,"status_verbose":"product not found"}"#
        #expect(OpenFoodFactsClient.parse(Data(json.utf8), barcode: "0000") == nil)
    }
}
