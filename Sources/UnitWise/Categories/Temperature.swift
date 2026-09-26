//
//  Temperature.swift
//  unitwise
//
//  The `temperature` category. Base unit: kelvin.
//
//  Every scale here is AFFINE, not linear: converting a temperature maps
//  through kelvin with `base = value·scale + offset`, so the zero points
//  are handled correctly on both legs. The classic mistake — treating °F
//  like a plain factor — is impossible with this encoding:
//
//      °C  → K:  K = °C + 273.15
//      °F  → K:  K = (°F + 459.67) × 5/9
//      °R  → K:  K = °R × 5/9
//      °De → K:  K = 373.15 − °De × 2/3      (inverted scale, negative factor)
//      °N  → K:  K = °N × 100/33 + 273.15
//      °Ré → K:  K = °Ré × 5/4 + 273.15
//      °Rø → K:  K = (°Rø − 7.5) × 40/21 + 273.15
//
//  Sanity anchors used by the selftests: 0 °C = 273.15 K, 100 °C = 212 °F,
//  −40 °C = −40 °F, 150 °De = 0 °C, 33 °N = 100 °C, 80 °Ré = 100 °C,
//  60 °Rø = 100 °C, 491.67 °R = 273.15 K.
//

// MARK: - TemperatureCategory

/// Builds the `temperature` category and exposes direct scale helpers.
public enum TemperatureCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "temperature"

    /// Affine constants (kelvin = value·scale + offset), kept as named
    /// constants so the unit table and the docs cannot drift apart.
    static let kelvinOffset = 273.15
    static let fahrenheitScale = 5.0 / 9.0
    static let fahrenheitOffset = 459.67 * 5.0 / 9.0
    static let rankineScale = 5.0 / 9.0
    static let delisleScale = -2.0 / 3.0
    static let delisleOffset = 373.15
    static let newtonScale = 100.0 / 33.0
    static let reaumurScale = 5.0 / 4.0
    static let romerScale = 40.0 / 21.0
    static let romerOffset = 273.15 - 7.5 * 40.0 / 21.0

    /// Direct °C → °F helper (identical math to the affine conversion).
    public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9.0 / 5.0 + 32.0
    }

    /// Direct °F → °C helper (identical math to the affine conversion).
    public static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        (fahrenheit - 32.0) * 5.0 / 9.0
    }

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.affine(
                categoryID: categoryID,
                id: "kelvin",
                symbol: "K",
                singular: "kelvin",
                scale: 1,
                offset: 0,
                plural: "kelvins",
                aliases: ["k"],
                tags: ["si", "base"],
                definition: "SI base unit; 0 K is absolute zero."),
            Unit.affine(
                categoryID: categoryID,
                id: "celsius",
                symbol: "°C",
                singular: "celsius",
                scale: 1,
                offset: kelvinOffset,
                plural: "celsius",
                aliases: ["c", "centigrade", "degc", "degreecelsius", "degreescelsius"],
                tags: ["si"],
                definition: "0° = water freezing, 100° = water boiling at 1 atm."),
            Unit.affine(
                categoryID: categoryID,
                id: "fahrenheit",
                symbol: "°F",
                singular: "fahrenheit",
                scale: fahrenheitScale,
                offset: fahrenheitOffset,
                plural: "fahrenheit",
                aliases: ["f", "degf", "degreefahrenheit"],
                tags: ["us"],
                definition: "32° = freezing, 212° = boiling."),
            Unit.affine(
                categoryID: categoryID,
                id: "rankine",
                symbol: "°R",
                singular: "rankine",
                scale: rankineScale,
                offset: 0,
                plural: "rankine",
                aliases: ["r", "degr", "degreerankine"],
                tags: ["us", "engineering"],
                definition: "Absolute zero like kelvin, degree size like fahrenheit."),
            Unit.affine(
                categoryID: categoryID,
                id: "delisle",
                symbol: "°De",
                singular: "delisle",
                scale: delisleScale,
                offset: delisleOffset,
                plural: "delisle",
                aliases: ["de", "degde", "degreedelisle"],
                tags: ["historic"],
                definition: "Inverted historic scale: 0° = boiling, 150° = freezing."),
            Unit.affine(
                categoryID: categoryID,
                id: "newton",
                symbol: "°N",
                singular: "newton degree",
                scale: newtonScale,
                offset: kelvinOffset,
                plural: "newton degrees",
                aliases: ["n", "degn", "degreenewton"],
                tags: ["historic"],
                definition: "Isaac Newton's scale: 0° = freezing, 33° = boiling."),
            Unit.affine(
                categoryID: categoryID,
                id: "reaumur",
                symbol: "°Ré",
                singular: "réaumur",
                scale: reaumurScale,
                offset: kelvinOffset,
                plural: "réaumur",
                aliases: ["re", "degre", "°re", "°ré", "degreaumur"],
                tags: ["historic"],
                definition: "0° = freezing, 80° = boiling; Alpine dairies still use it."),
            Unit.affine(
                categoryID: categoryID,
                id: "romer",
                symbol: "°Rø",
                singular: "rømer",
                scale: romerScale,
                offset: romerOffset,
                plural: "rømer",
                aliases: ["ro", "degro", "°ro", "°rø", "degreomer"],
                tags: ["historic"],
                definition: "Ole Rømer's 1701 scale: 7.5° = freezing, 60° = boiling.")
        ]
        return Category(
            id: categoryID,
            displayName: "Temperature",
            summary: "Offset-correct temperature scales from kelvin to rømer.",
            baseUnitID: "kelvin",
            aliases: ["temp", "temperatures"],
            units: units,
            note: "All scales convert through kelvin with affine mapping "
                + "(base = value·scale + offset), so freezing/boiling anchors "
                + "hold in every direction.")
    }
}
