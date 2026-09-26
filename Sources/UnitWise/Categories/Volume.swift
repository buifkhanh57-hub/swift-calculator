//
//  Volume.swift
//  unitwise
//
//  The `volume` category. Base unit: liter.
//
//  US customary factors are exact definitions:
//    * US gallon = 3.785411784 L, imperial gallon = 4.54609 L (both exact)
//    * US fluid ounce = 1/128 US gallon, tablespoon = 1/2 fl oz
//    * oil barrel = 42 US gallons = 158.987294928 L
//  The cup is the US customary cup (236.5882365 mL), not the 250 mL
//  metric cup used elsewhere.
//

// MARK: - VolumeCategory

/// Builds the `volume` category for `CategoryRegistry`.
public enum VolumeCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "volume"

    /// Exact agreed factors, kept as named constants for docs and selftests.
    static let litersPerUSGallon = 3.785411784
    static let litersPerImperialGallon = 4.54609
    static let litersPerCubicInch = 0.016387064
    static let litersPerCubicFoot = 28.316846592
    static let litersPerOilBarrel = 42.0 * litersPerUSGallon

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "liter",
                symbol: "L",
                singular: "liter",
                factor: 1,
                plural: "liters",
                aliases: ["l", "litre", "litres"],
                tags: ["si", "base"],
                definition: "One cubic decimeter; SI-accepted volume unit."),
            Unit.linear(
                categoryID: categoryID,
                id: "milliliter",
                symbol: "ml",
                singular: "milliliter",
                factor: 0.001,
                plural: "milliliters",
                aliases: ["mL", "millilitre", "millilitres"],
                tags: ["si"],
                definition: "One thousandth of a liter; equals 1 cm³."),
            Unit.linear(
                categoryID: categoryID,
                id: "cubicmeter",
                symbol: "m3",
                singular: "cubic meter",
                factor: 1000,
                plural: "cubic meters",
                aliases: ["m³", "cbm", "cubicmetre", "cubicmetres"],
                tags: ["si"],
                definition: "SI volume: 1000 liters; utility billing."),
            Unit.linear(
                categoryID: categoryID,
                id: "cubiccentimeter",
                symbol: "cm3",
                singular: "cubic centimeter",
                factor: 0.001,
                plural: "cubic centimeters",
                aliases: ["cm³", "cc", "cubiccentimetre", "cubiccentimetres"],
                tags: ["si"],
                definition: "Engine displacement; equals 1 milliliter."),
            Unit.linear(
                categoryID: categoryID,
                id: "cubicinch",
                symbol: "in3",
                singular: "cubic inch",
                factor: litersPerCubicInch,
                plural: "cubic inches",
                aliases: ["in³", "cuin", "cubicinch", "cubicinches"],
                tags: ["us"],
                definition: "Classic US engine displacement unit."),
            Unit.linear(
                categoryID: categoryID,
                id: "cubicfoot",
                symbol: "ft3",
                singular: "cubic foot",
                factor: litersPerCubicFoot,
                plural: "cubic feet",
                aliases: ["ft³", "cuft", "cubicfoot", "cubicfeet"],
                tags: ["us"],
                definition: "Shipping and HVAC volumes."),
            Unit.linear(
                categoryID: categoryID,
                id: "usgallon",
                symbol: "gal",
                singular: "US gallon",
                factor: litersPerUSGallon,
                plural: "US gallons",
                aliases: ["gallon", "gallons", "usgal", "usgallon", "usgallons"],
                tags: ["us"],
                definition: "Exactly 3.785411784 liters."),
            Unit.linear(
                categoryID: categoryID,
                id: "impgallon",
                symbol: "impgal",
                singular: "imperial gallon",
                factor: litersPerImperialGallon,
                plural: "imperial gallons",
                aliases: ["imperialgallon", "imperialgallons", "ukgal", "ukgallon", "ukgallons"],
                tags: ["imperial"],
                definition: "UK fuel economy gallon: exactly 4.54609 liters."),
            Unit.linear(
                categoryID: categoryID,
                id: "quart",
                symbol: "qt",
                singular: "quart",
                factor: litersPerUSGallon / 4.0,
                plural: "quarts",
                aliases: ["usqt", "quarts"],
                tags: ["us"],
                definition: "One quarter of a US gallon."),
            Unit.linear(
                categoryID: categoryID,
                id: "pint",
                symbol: "pt",
                singular: "pint",
                factor: litersPerUSGallon / 8.0,
                plural: "pints",
                aliases: ["uspt", "pints"],
                tags: ["us"],
                definition: "One eighth of a US gallon (16 fl oz)."),
            Unit.linear(
                categoryID: categoryID,
                id: "cup",
                symbol: "cup",
                singular: "cup",
                factor: 0.2365882365,
                plural: "cups",
                aliases: ["cups"],
                tags: ["us", "cooking"],
                definition: "US customary cup: 8 fl oz."),
            Unit.linear(
                categoryID: categoryID,
                id: "fluidounce",
                symbol: "floz",
                singular: "fluid ounce",
                factor: litersPerUSGallon / 128.0,
                plural: "fluid ounces",
                aliases: ["usfloz", "fluidounce", "fluidounces"],
                tags: ["us"],
                definition: "1/128 US gallon; drink sizes."),
            Unit.linear(
                categoryID: categoryID,
                id: "impfluidounce",
                symbol: "impfloz",
                singular: "imperial fluid ounce",
                factor: litersPerImperialGallon / 160.0,
                plural: "imperial fluid ounces",
                aliases: ["ukfloz", "imperialfluidounce", "imperialfluidounces"],
                tags: ["imperial"],
                definition: "1/160 imperial gallon (about 28.41 mL)."),
            Unit.linear(
                categoryID: categoryID,
                id: "tablespoon",
                symbol: "tbsp",
                singular: "tablespoon",
                factor: litersPerUSGallon / 256.0,
                plural: "tablespoons",
                aliases: ["tbs", "tbsps", "tablespoons"],
                tags: ["us", "cooking"],
                definition: "3 teaspoons; 1/2 US fluid ounce."),
            Unit.linear(
                categoryID: categoryID,
                id: "teaspoon",
                symbol: "tsp",
                singular: "teaspoon",
                factor: litersPerUSGallon / 768.0,
                plural: "teaspoons",
                aliases: ["tsps", "teaspoons"],
                tags: ["us", "cooking"],
                definition: "About 4.93 mL; recipe unit."),
            Unit.linear(
                categoryID: categoryID,
                id: "barrel",
                symbol: "bbl",
                singular: "oil barrel",
                factor: litersPerOilBarrel,
                plural: "oil barrels",
                aliases: ["barrel", "barrels", "oilbarrel", "oilbarrels"],
                tags: ["trade"],
                definition: "Petroleum barrel: 42 US gallons.")
        ]
        return Category(
            id: categoryID,
            displayName: "Volume",
            summary: "Liters, cubic measures, and US/imperial kitchen units.",
            baseUnitID: "liter",
            aliases: ["volumes", "capacity"],
            units: units,
            note: "US customary cups/quarts/pints differ from imperial ones; "
                + "this category follows the 1959 US definitions and keeps the "
                + "imperial gallon/fluid ounce as separate units.")
    }
}
