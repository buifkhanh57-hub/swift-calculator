//
//  Energy.swift
//  unitwise
//
//  The `energy` category. Base unit: joule (SI).
//
//  Factor provenance, because energy units are a zoo of agreements:
//    * calorie (thermochemical) = 4.184 J exactly — the value used by
//      chemistry tables. The International Table calorie (4.1868 J) is
//      deliberately NOT registered, to avoid silent near-duplicates.
//    * kilocalorie (food calorie) = 1000 thermochemical calories = 4184 J.
//      The nutrition-label alias "Cal" (capital C) resolves here while the
//      lowercase "cal" stays with the small calorie — exact-case alias
//      matching in UnitResolver keeps the two apart.
//    * watt-hour = 3600 J exactly (1 watt sustained for 3600 seconds).
//    * BTU is the International Table value: 1055.05585262 J, exact since
//      the 1956 International Conference on the Properties of Steam.
//    * foot-pound = 0.3048 m × 4.4482216152605 lbf = 1.3558179483314004 J
//      (built from the exact 1959 foot and pound definitions).
//    * electronvolt = 1.602176634e-19 J exactly (2019 SI revision).
//    * therm (US) = 100000 BTU_IT = 105505585.262 J; gas billing.
//    * horsepower-hour = 550 ft·lbf/s × 3600 s = 2684519.5376961727 J.
//
//  Sanity anchors used by the selftests: 1 kcal = 4184 J, 1 kWh = 3.6e6 J,
//  1 BTU = 1055.05585262 J, 1 ft·lbf = 1.3558179483314004 J.
//

// MARK: - EnergyCategory

/// Builds the `energy` category and exposes a few direct helpers.
public enum EnergyCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "energy"

    /// Exact or agreed factors, kept as named constants for docs and selftests.
    static let joulesPerKilojoule = 1000.0
    static let joulesPerMegajoule = 1.0e6
    static let joulesPerCalorie = 4.184
    static let joulesPerKilocalorie = 4184.0
    static let joulesPerWattHour = 3600.0
    static let joulesPerKilowattHour = 3.6e6
    static let joulesPerMegawattHour = 3.6e9
    static let joulesPerBTU = 1055.05585262
    static let joulesPerFootPound = 0.3048 * 4.4482216152605
    static let joulesPerElectronvolt = 1.602176634e-19
    static let joulesPerTherm = 100000.0 * 1055.05585262
    static let joulesPerHorsepowerHour = 550.0 * 0.3048 * 4.4482216152605 * 3600.0

    /// Direct kcal → J helper (identical math to the canonical conversion).
    public static func kilocaloriesToJoules(_ kilocalories: Double) -> Double {
        kilocalories * joulesPerKilocalorie
    }

    /// Direct J → kcal helper (identical math to the canonical conversion).
    public static func joulesToKilocalories(_ joules: Double) -> Double {
        joules / joulesPerKilocalorie
    }

    /// Direct kWh → J helper (identical math to the canonical conversion).
    public static func kilowattHoursToJoules(_ kilowattHours: Double) -> Double {
        kilowattHours * joulesPerKilowattHour
    }

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "joule",
                symbol: "J",
                singular: "joule",
                factor: 1,
                plural: "joules",
                aliases: ["j", "joules"],
                tags: ["si", "base"],
                definition: "SI derived unit: 1 newton-meter of work."),
            Unit.linear(
                categoryID: categoryID,
                id: "kilojoule",
                symbol: "kJ",
                singular: "kilojoule",
                factor: joulesPerKilojoule,
                plural: "kilojoules",
                aliases: ["kj", "kilojoules"],
                tags: ["si"],
                definition: "1000 joules; food labels outside the US."),
            Unit.linear(
                categoryID: categoryID,
                id: "megajoule",
                symbol: "MJ",
                singular: "megajoule",
                factor: joulesPerMegajoule,
                plural: "megajoules",
                aliases: ["mj", "megajoules"],
                tags: ["si"],
                definition: "1e6 joules; vehicle crash energy, gas meters."),
            Unit.linear(
                categoryID: categoryID,
                id: "calorie",
                symbol: "cal",
                singular: "calorie",
                factor: joulesPerCalorie,
                plural: "calories",
                aliases: ["calories", "cals"],
                tags: ["chemistry"],
                definition: "Thermochemical calorie: exactly 4.184 J."),
            Unit.linear(
                categoryID: categoryID,
                id: "kilocalorie",
                symbol: "kcal",
                singular: "kilocalorie",
                factor: joulesPerKilocalorie,
                plural: "kilocalories",
                aliases: ["Cal", "kcalories", "foodcalorie", "foodcalories", "kilocalories"],
                tags: ["nutrition"],
                definition: "Food calorie: 1000 cal = 4184 J; 'Cal' also accepted."),
            Unit.linear(
                categoryID: categoryID,
                id: "watthour",
                symbol: "Wh",
                singular: "watt-hour",
                factor: joulesPerWattHour,
                plural: "watt-hours",
                aliases: ["wh", "whr", "watthour", "watthours"],
                tags: ["electricity"],
                definition: "1 watt for 1 hour: exactly 3600 J."),
            Unit.linear(
                categoryID: categoryID,
                id: "kilowatthour",
                symbol: "kWh",
                singular: "kilowatt-hour",
                factor: joulesPerKilowattHour,
                plural: "kilowatt-hours",
                aliases: ["kwh", "kwhr", "kilowatthour", "kilowatthours"],
                tags: ["electricity"],
                definition: "Electricity billing unit: exactly 3.6e6 J."),
            Unit.linear(
                categoryID: categoryID,
                id: "megawatthour",
                symbol: "MWh",
                singular: "megawatt-hour",
                factor: joulesPerMegawattHour,
                plural: "megawatt-hours",
                aliases: ["mwh", "megawatthour", "megawatthours"],
                tags: ["electricity"],
                definition: "1e9 J; grid-scale production."),
            Unit.linear(
                categoryID: categoryID,
                id: "btu",
                symbol: "BTU",
                singular: "British thermal unit",
                factor: joulesPerBTU,
                plural: "British thermal units",
                aliases: ["btu", "btus", "btuit", "britishthermalunit", "britishthermalunits"],
                tags: ["us", "hvac"],
                definition: "International Table BTU: 1055.05585262 J; HVAC ratings."),
            Unit.linear(
                categoryID: categoryID,
                id: "footpound",
                symbol: "ftlb",
                singular: "foot-pound",
                factor: joulesPerFootPound,
                plural: "foot-pounds",
                aliases: ["ftlbf", "ft-lb", "ft-lbf", "footpound", "footpounds"],
                tags: ["us", "mechanics"],
                definition: "Torque/work in US units: 1.3558179483314004 J."),
            Unit.linear(
                categoryID: categoryID,
                id: "electronvolt",
                symbol: "eV",
                singular: "electronvolt",
                factor: joulesPerElectronvolt,
                plural: "electronvolts",
                aliases: ["ev", "electronvolts"],
                tags: ["physics"],
                definition: "Energy of one electron across one volt: 1.602176634e-19 J."),
            Unit.linear(
                categoryID: categoryID,
                id: "therm",
                symbol: "thm",
                singular: "therm",
                factor: joulesPerTherm,
                plural: "therms",
                aliases: ["thm", "therms", "ustherm", "ustherms"],
                tags: ["us", "trade"],
                definition: "US gas billing: 100000 BTU = 105505585.262 J."),
            Unit.linear(
                categoryID: categoryID,
                id: "horsepowerhour",
                symbol: "hph",
                singular: "horsepower-hour",
                factor: joulesPerHorsepowerHour,
                plural: "horsepower-hours",
                aliases: ["hph", "hp-h", "horsepowerhour", "horsepowerhours"],
                tags: ["mechanics"],
                definition: "Mechanical horsepower sustained for one hour.")
        ]
        return Category(
            id: categoryID,
            displayName: "Energy",
            summary: "Work and heat from electronvolts to megawatt-hours.",
            baseUnitID: "joule",
            aliases: ["energies", "work", "heat"],
            units: units,
            note: "The calorie registered here is the thermochemical calorie "
                + "(4.184 J exactly) and the BTU is the International Table "
                + "value (1055.05585262 J); the IT calorie is intentionally "
                + "not offered as a separate unit.")
    }
}
