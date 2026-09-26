//
//  Area.swift
//  unitwise
//
//  The `area` category. Base unit: square meter (SI).
//
//  Factors are squared lengths, so every imperial value below is EXACT —
//  it is the square of an exact 1959 linear definition:
//    * ft² = 0.3048² = 0.09290304 m²
//    * in² = 0.0254² = 0.00064516 m²
//    * yd² = 0.9144²  = 0.83612736 m²
//    * acre  = 43560 ft² = 4046.8564224 m² (US survey agreement)
//    * mi²   = 5280² ft² = 2589988.110336 m²
//    * hectare = 1e4 m² exactly; nautical mile² = 1852² = 3429904 m².
//
//  Tokenizer note: the display symbols use the superscript ² (m², ft²...),
//  but "²" is not a letter, digit, or one of the parser's accepted glyphs,
//  so at the command line you type the ASCII aliases instead: m2, ft2,
//  sqft, sqmi, acre, ha... The category note says the same, so users are
//  never surprised by "unexpected character '²'".
//

// MARK: - AreaCategory

/// Builds the `area` category and exposes a few direct helpers.
public enum AreaCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "area"

    /// Exact squared factors, kept as named constants for docs and selftests.
    static let squareMetersPerSquareKilometer = 1.0e6
    static let squareMetersPerHectare = 1.0e4
    static let squareMetersPerSquareCentimeter = 1.0e-4
    static let squareMetersPerSquareMillimeter = 1.0e-6
    static let squareMetersPerSquareFoot = 0.09290304
    static let squareMetersPerSquareInch = 0.00064516
    static let squareMetersPerSquareYard = 0.83612736
    static let squareMetersPerAcre = 43560.0 * 0.09290304
    static let squareMetersPerSquareMile = 5280.0 * 5280.0 * 0.09290304
    static let squareMetersPerSquareNauticalMile = 1852.0 * 1852.0

    /// Direct acre → hectare helper (land-area math identical to conversion).
    public static func acresToHectares(_ acres: Double) -> Double {
        acres * squareMetersPerAcre / squareMetersPerHectare
    }

    /// Direct ft² → acre helper (real-estate math identical to conversion).
    public static func squareFeetToAcres(_ squareFeet: Double) -> Double {
        squareFeet * squareMetersPerSquareFoot / squareMetersPerAcre
    }

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "squaremeter",
                symbol: "m²",
                singular: "square meter",
                factor: 1,
                plural: "square meters",
                aliases: ["m2", "sqm", "sq-meter", "sqmeter", "sqmeters",
                          "square-meter", "squaremeter", "squaremeters",
                          "squaremetre", "squaremetres"],
                tags: ["si", "base"],
                definition: "SI derived unit of area; type m2 or sqm at the CLI."),
            Unit.linear(
                categoryID: categoryID,
                id: "squarekilometer",
                symbol: "km²",
                singular: "square kilometer",
                factor: squareMetersPerSquareKilometer,
                plural: "square kilometers",
                aliases: ["km2", "sqkm", "sq-km", "sqkilometer", "sqkilometers",
                          "squarekilometer", "squarekilometers",
                          "squarekilometre", "squarekilometres"],
                tags: ["si"],
                definition: "1e6 m²; cities and counties."),
            Unit.linear(
                categoryID: categoryID,
                id: "hectare",
                symbol: "ha",
                singular: "hectare",
                factor: squareMetersPerHectare,
                plural: "hectares",
                aliases: ["hectare", "hectares"],
                tags: ["si", "land"],
                definition: "1e4 m² (100 m × 100 m); farmland and forestry."),
            Unit.linear(
                categoryID: categoryID,
                id: "acre",
                symbol: "ac",
                singular: "acre",
                factor: squareMetersPerAcre,
                plural: "acres",
                aliases: ["acre", "acres"],
                tags: ["us", "imperial", "land"],
                definition: "43560 ft² = 4046.8564224 m²; US land parcels."),
            Unit.linear(
                categoryID: categoryID,
                id: "squarefoot",
                symbol: "ft²",
                singular: "square foot",
                factor: squareMetersPerSquareFoot,
                plural: "square feet",
                aliases: ["ft2", "sqft", "sq-ft", "sqfoot", "sqfeet",
                          "squarefoot", "squarefeet"],
                tags: ["us", "imperial"],
                definition: "0.09290304 m² exactly; US real estate."),
            Unit.linear(
                categoryID: categoryID,
                id: "squareinch",
                symbol: "in²",
                singular: "square inch",
                factor: squareMetersPerSquareInch,
                plural: "square inches",
                aliases: ["in2", "sqin", "sq-in", "sqinch", "sqinches",
                          "squareinch", "squareinches"],
                tags: ["us", "imperial"],
                definition: "0.00064516 m² exactly; small plates and screens."),
            Unit.linear(
                categoryID: categoryID,
                id: "squareyard",
                symbol: "yd²",
                singular: "square yard",
                factor: squareMetersPerSquareYard,
                plural: "square yards",
                aliases: ["yd2", "sqyd", "sq-yd", "sqyard", "sqyards",
                          "squareyard", "squareyards"],
                tags: ["us", "imperial"],
                definition: "0.83612736 m² exactly; carpets and concrete."),
            Unit.linear(
                categoryID: categoryID,
                id: "squaremile",
                symbol: "mi²",
                singular: "square mile",
                factor: squareMetersPerSquareMile,
                plural: "square miles",
                aliases: ["mi2", "sqmi", "sq-mi", "sqmile", "sqmiles",
                          "squaremile", "squaremiles"],
                tags: ["us", "imperial"],
                definition: "2589988.110336 m² exactly; geographies."),
            Unit.linear(
                categoryID: categoryID,
                id: "squarecentimeter",
                symbol: "cm²",
                singular: "square centimeter",
                factor: squareMetersPerSquareCentimeter,
                plural: "square centimeters",
                aliases: ["cm2", "sqcm", "sq-cm", "sqcentimeter", "sqcentimeters",
                          "squarecentimeter", "squarecentimeters",
                          "squarecentimetre", "squarecentimetres"],
                tags: ["si"],
                definition: "1e-4 m²; stamps and cross-sections."),
            Unit.linear(
                categoryID: categoryID,
                id: "squaremillimeter",
                symbol: "mm²",
                singular: "square millimeter",
                factor: squareMetersPerSquareMillimeter,
                plural: "square millimeters",
                aliases: ["mm2", "sqmm", "sq-mm", "sqmillimeter", "sqmillimeters",
                          "squaremillimeter", "squaremillimeters",
                          "squaremillimetre", "squaremillimetres"],
                tags: ["si"],
                definition: "1e-6 m²; wire gauges are rated in mm²."),
            Unit.linear(
                categoryID: categoryID,
                id: "squarenauticalmile",
                symbol: "nmi²",
                singular: "square nautical mile",
                factor: squareMetersPerSquareNauticalMile,
                plural: "square nautical miles",
                aliases: ["nmi2", "sqnmi", "sq-nmi", "sqnauticalmile",
                          "sqnauticalmiles", "squarenauticalmile",
                          "squarenauticalmiles"],
                tags: ["maritime"],
                definition: "3429904 m² (1852 m)²; sea and airspace coverage.")
        ]
        return Category(
            id: categoryID,
            displayName: "Area",
            summary: "Surfaces from square millimeters to square nautical miles.",
            baseUnitID: "squaremeter",
            aliases: ["areas", "surface", "surfaces"],
            units: units,
            note: "Symbols print with the superscript ² (m², ft²), but the CLI "
                + "tokenizer only accepts plain identifiers — type the ASCII "
                + "aliases instead: m2, ft2, sqft, sqmi, acre, ha.")
    }
}
