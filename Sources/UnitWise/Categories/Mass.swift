//
//  Mass.swift
//  unitwise
//
//  The `mass` category. Base unit: kilogram (SI).
//
//  Factors are exact by definition or agreement:
//    * pound = 0.45359237 kg  (exact, 1959 agreement)
//    * ounce = pound / 16, stone = 14 pounds
//    * short (US) ton = 2000 lb, long (imperial) ton = 2240 lb
//    * carat = 0.0002 kg, grain = 64.79891 mg (both exact)
//    * dalton: 2018 CODATA value 1.66053906660e-27 kg
//
//  The bare word "ton" resolves to the US short ton; ask for "longton"
//  or "metricton" (tonne) explicitly when that is what you mean.
//

// MARK: - MassCategory

/// Builds the `mass` category for `CategoryRegistry`.
public enum MassCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "mass"

    /// Exact agreed factors, kept as named constants for docs and selftests.
    static let kilogramsPerPound = 0.45359237
    static let kilogramsPerOunce = 0.45359237 / 16.0
    static let kilogramsPerStone = 14.0 * 0.45359237
    static let kilogramsPerShortTon = 2000.0 * 0.45359237
    static let kilogramsPerLongTon = 2240.0 * 0.45359237
    static let kilogramsPerCarat = 0.0002
    static let kilogramsPerGrain = 0.00006479891
    static let kilogramsPerSlug = 14.59390294
    static let kilogramsPerDalton = 1.66053906660e-27

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "kilogram",
                symbol: "kg",
                singular: "kilogram",
                factor: 1,
                plural: "kilograms",
                aliases: ["kilogramme", "kilogrammes"],
                tags: ["si", "base"],
                definition: "SI base unit of mass, defined via Planck's constant."),
            Unit.linear(
                categoryID: categoryID,
                id: "gram",
                symbol: "g",
                singular: "gram",
                factor: 0.001,
                plural: "grams",
                aliases: ["gramme", "grammes"],
                tags: ["si"],
                definition: "One thousandth of a kilogram."),
            Unit.linear(
                categoryID: categoryID,
                id: "milligram",
                symbol: "mg",
                singular: "milligram",
                factor: 1e-6,
                plural: "milligrams",
                aliases: [],
                tags: ["si"],
                definition: "One millionth of a kilogram; medication doses."),
            Unit.linear(
                categoryID: categoryID,
                id: "microgram",
                symbol: "µg",
                singular: "microgram",
                factor: 1e-9,
                plural: "micrograms",
                aliases: ["ug", "mcg"],
                tags: ["si"],
                definition: "One billionth of a kilogram; vitamins and lab work."),
            Unit.linear(
                categoryID: categoryID,
                id: "tonne",
                symbol: "t",
                singular: "tonne",
                factor: 1000,
                plural: "tonnes",
                aliases: ["metricton", "metrictons"],
                tags: ["si"],
                definition: "Metric ton: 1000 kilograms."),
            Unit.linear(
                categoryID: categoryID,
                id: "pound",
                symbol: "lb",
                singular: "pound",
                factor: kilogramsPerPound,
                plural: "pounds",
                aliases: ["lbs", "lbm"],
                tags: ["imperial", "us"],
                definition: "Exactly 0.45359237 kg since 1959."),
            Unit.linear(
                categoryID: categoryID,
                id: "ounce",
                symbol: "oz",
                singular: "ounce",
                factor: kilogramsPerOunce,
                plural: "ounces",
                aliases: [],
                tags: ["imperial", "us"],
                definition: "One sixteenth of a pound (avoirdupois)."),
            Unit.linear(
                categoryID: categoryID,
                id: "stone",
                symbol: "st",
                singular: "stone",
                factor: kilogramsPerStone,
                plural: "stone",
                aliases: ["stones"],
                tags: ["imperial"],
                definition: "14 pounds; British body weight."),
            Unit.linear(
                categoryID: categoryID,
                id: "shortton",
                symbol: "ton",
                singular: "short ton",
                factor: kilogramsPerShortTon,
                plural: "short tons",
                aliases: ["tons", "shorttons", "uston", "ustons"],
                tags: ["us"],
                definition: "US ton: 2000 pounds."),
            Unit.linear(
                categoryID: categoryID,
                id: "longton",
                symbol: "longton",
                singular: "long ton",
                factor: kilogramsPerLongTon,
                plural: "long tons",
                aliases: ["longtons", "imperialton", "imperialtons", "ukton", "uktons"],
                tags: ["imperial"],
                definition: "Imperial ton: 2240 pounds."),
            Unit.linear(
                categoryID: categoryID,
                id: "carat",
                symbol: "ct",
                singular: "carat",
                factor: kilogramsPerCarat,
                plural: "carats",
                aliases: [],
                tags: ["trade"],
                definition: "Gem mass: 200 milligrams."),
            Unit.linear(
                categoryID: categoryID,
                id: "grain",
                symbol: "gr",
                singular: "grain",
                factor: kilogramsPerGrain,
                plural: "grains",
                aliases: [],
                tags: ["legacy"],
                definition: "64.79891 mg; bullets and archery."),
            Unit.linear(
                categoryID: categoryID,
                id: "slug",
                symbol: "slug",
                singular: "slug",
                factor: kilogramsPerSlug,
                plural: "slugs",
                aliases: ["geepound"],
                tags: ["us", "physics"],
                definition: "Mass accelerated at 1 ft/s² by one pound-force."),
            Unit.linear(
                categoryID: categoryID,
                id: "dalton",
                symbol: "Da",
                singular: "dalton",
                factor: kilogramsPerDalton,
                plural: "daltons",
                aliases: ["amu", "u"],
                tags: ["physics"],
                definition: "Atomic mass unit: 1/12 of a carbon-12 atom.")
        ]
        return Category(
            id: categoryID,
            displayName: "Mass",
            summary: "Weights from micrograms to long tons, metric and imperial.",
            baseUnitID: "kilogram",
            aliases: ["weight", "wt", "weights"],
            units: units)
    }
}
