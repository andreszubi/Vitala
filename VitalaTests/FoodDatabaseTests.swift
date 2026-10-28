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
