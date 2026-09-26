//
//  Pressure.swift
//  unitwise
//
//  The `pressure` category. Base unit: pascal (SI).
//
//  Factor provenance:
//    * bar = 1e5 Pa exactly (CGPM 1879, re-affirmed by the SI brochure).
//    * standard atmosphere = 101325 Pa exactly (10th CGPM, 1954).
//    * torr = 101325/760 Pa exactly — one atmosphere divided into 760.
//    * mmHg uses the CONVENTIONAL millimetre of mercury:
//      133.322387415 Pa (density 13595.1 kg/m³ at 0 °C, g = 9.80665 m/s²).
//      It differs from the torr in the 7th significant digit; both are
//      registered separately because vacuum labs care.
//    * inHg = 25.4 conventional mmHg (exact inch conversion).
//    * psi = 4.4482216152605 lbf ÷ (0.0254 m)² = 6894.757293168361 Pa,
//      built from the exact 1959 pound and inch definitions.
//    * ksi = 1000 psi; structural engineering stresses.
//
//  Sanity anchors used by the selftests: 1 bar = 1e5 Pa, 1 atm = 101325 Pa,
//  760 Torr = 101325 Pa, 1 psi = 6894.757293168361 Pa.
//

// MARK: - PressureCategory

/// Builds the `pressure` category and exposes a few direct helpers.
public enum PressureCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "pressure"

    /// Exact or agreed factors, kept as named constants for docs and selftests.
    static let pascalsPerHectopascal = 100.0
    static let pascalsPerKilopascal = 1000.0
    static let pascalsPerMegapascal = 1.0e6
    static let pascalsPerBar = 1.0e5
    static let pascalsPerMillibar = 100.0
    static let pascalsPerAtmosphere = 101325.0
    static let pascalsPerTorr = 101325.0 / 760.0
    static let pascalsPerMillimeterMercury = 133.322387415
    static let pascalsPerInchMercury = 25.4 * 133.322387415
    static let pascalsPerPSI = 4.4482216152605 / (0.0254 * 0.0254)
    static let pascalsPerKSI = 1000.0 * 4.4482216152605 / (0.0254 * 0.0254)

    /// Direct psi → bar helper (identical math to the canonical conversion).
    public static func psiToBar(_ psi: Double) -> Double {
        psi * pascalsPerPSI / pascalsPerBar
    }

    /// Direct inHg → hPa helper (aviation altimeter setting math).
    public static func inchesMercuryToHectopascals(_ inchesMercury: Double) -> Double {
        inchesMercury * pascalsPerInchMercury / pascalsPerHectopascal
    }

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "pascal",
                symbol: "Pa",
                singular: "pascal",
                factor: 1,
                plural: "pascals",
                aliases: ["pa", "pascals"],
                tags: ["si", "base"],
                definition: "SI derived unit: 1 newton per square meter."),
            Unit.linear(
                categoryID: categoryID,
                id: "hectopascal",
                symbol: "hPa",
                singular: "hectopascal",
                factor: pascalsPerHectopascal,
                plural: "hectopascals",
                aliases: ["hpa", "hectopascals"],
                tags: ["si", "meteorology"],
                definition: "100 Pa; weather charts (identical to the millibar)."),
            Unit.linear(
                categoryID: categoryID,
                id: "kilopascal",
                symbol: "kPa",
                singular: "kilopascal",
                factor: pascalsPerKilopascal,
                plural: "kilopascals",
                aliases: ["kpa", "kilopascals"],
                tags: ["si"],
                definition: "1000 Pa; tire pressures in metric countries."),
            Unit.linear(
                categoryID: categoryID,
                id: "megapascal",
                symbol: "MPa",
                singular: "megapascal",
                factor: pascalsPerMegapascal,
                plural: "megapascals",
                aliases: ["mpa", "megapascals"],
                tags: ["si", "engineering"],
                definition: "1e6 Pa; material strengths."),
            Unit.linear(
                categoryID: categoryID,
                id: "bar",
                symbol: "bar",
                singular: "bar",
                factor: pascalsPerBar,
                plural: "bars",
                aliases: ["bars"],
                tags: ["metric"],
                definition: "Exactly 1e5 Pa; dive tables and espresso machines."),
            Unit.linear(
                categoryID: categoryID,
                id: "millibar",
                symbol: "mbar",
                singular: "millibar",
                factor: pascalsPerMillibar,
                plural: "millibars",
                aliases: ["mbar", "millibars"],
                tags: ["meteorology"],
                definition: "100 Pa; legacy meteorology unit."),
            Unit.linear(
                categoryID: categoryID,
                id: "atmosphere",
                symbol: "atm",
                singular: "standard atmosphere",
                factor: pascalsPerAtmosphere,
                plural: "standard atmospheres",
                aliases: ["atm", "atmos", "atmosphere", "atmospheres",
                          "standardatmosphere", "standardatmospheres"],
                tags: ["reference"],
                definition: "Exactly 101325 Pa by the 10th CGPM."),
            Unit.linear(
                categoryID: categoryID,
                id: "torr",
                symbol: "Torr",
                singular: "torr",
                factor: pascalsPerTorr,
                plural: "torr",
                aliases: ["torr", "torrs"],
                tags: ["vacuum"],
                definition: "1/760 atm: vacuum engineering's traditional unit."),
            Unit.linear(
                categoryID: categoryID,
                id: "mmhg",
                symbol: "mmHg",
                singular: "millimetre of mercury",
                factor: pascalsPerMillimeterMercury,
                plural: "millimetres of mercury",
                aliases: ["mmhg", "mm-mercury", "millimetersmercury",
                          "millimetresmercury", "millimetersofmercury",
                          "millimetresofmercury"],
                tags: ["medical"],
                definition: "Conventional mmHg: 133.322387415 Pa; blood pressure."),
            Unit.linear(
                categoryID: categoryID,
                id: "inhg",
                symbol: "inHg",
                singular: "inch of mercury",
                factor: pascalsPerInchMercury,
                plural: "inches of mercury",
                aliases: ["inhg", "in-mercury", "inchesmercury", "inchesofmercury"],
                tags: ["us", "aviation"],
                definition: "25.4 conventional mmHg; US altimeter settings."),
            Unit.linear(
                categoryID: categoryID,
                id: "psi",
                symbol: "psi",
                singular: "pound per square inch",
                factor: pascalsPerPSI,
                plural: "pounds per square inch",
                aliases: ["psia", "poundspersquareinch", "poundspersquareinches"],
                tags: ["us"],
                definition: "6894.757293168361 Pa; US tire and hydraulics gauges."),
            Unit.linear(
                categoryID: categoryID,
                id: "ksi",
                symbol: "ksi",
                singular: "kip per square inch",
                factor: pascalsPerKSI,
                plural: "kips per square inch",
                aliases: ["ksia", "kilopoundspersquareinch", "kipsipersquareinch"],
                tags: ["us", "engineering"],
                definition: "1000 psi; steel yield strengths.")
        ]
        return Category(
            id: categoryID,
            displayName: "Pressure",
            summary: "Force per area from pascals to kips per square inch.",
            baseUnitID: "pascal",
            aliases: ["pressures"],
            units: units,
            note: "mmHg is the conventional millimetre of mercury "
                + "(133.322387415 Pa), which differs from the torr "
                + "(101325/760 Pa) only in the seventh digit; vacuum work "
                + "should quote torr, medicine quotes mmHg.")
    }
}
