//
//  Speed.swift
//  unitwise
//
//  The `speed` category. Base unit: meter per second.
//
//  Notes on the tricky members:
//    * knot = 1 nautical mile per hour = 1852 m / 3600 s (exact)
//    * mach uses 340.29 m/s (dry air at sea level, 15 °C). Mach number
//      depends on temperature/pressure, so this is a reference value,
//      not a physical constant — the category note says so.
//    * the speed of light is registered under the alias "c". That token
//      is also an alias of celsius, which is exactly why the parser's
//      mutual-anchoring exists: "72F to c" is celsius, "0.5c to mps"
//      is lightspeed.
//

// MARK: - SpeedCategory

/// Builds the `speed` category for `CategoryRegistry`.
public enum SpeedCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "speed"

    /// Reference factors, kept as named constants for docs and selftests.
    static let metersPerSecondPerKilometerPerHour = 1000.0 / 3600.0
    static let metersPerSecondPerMilePerHour = 0.44704
    static let metersPerSecondPerKnot = 1852.0 / 3600.0
    static let metersPerSecondPerFootPerSecond = 0.3048
    static let metersPerSecondPerMach = 340.29
    static let speedOfLight = 299792458.0

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "mps",
                symbol: "m/s",
                singular: "meter per second",
                factor: 1,
                plural: "meters per second",
                aliases: ["mps", "m/sec", "meterspersecond", "meters/second"],
                tags: ["si", "base"],
                definition: "SI derived unit of speed."),
            Unit.linear(
                categoryID: categoryID,
                id: "kmh",
                symbol: "km/h",
                singular: "kilometer per hour",
                factor: metersPerSecondPerKilometerPerHour,
                plural: "kilometers per hour",
                aliases: ["kmh", "kph", "kmph", "kilometersperhour", "kilometresperhour"],
                tags: ["si"],
                definition: "Road speeds almost everywhere."),
            Unit.linear(
                categoryID: categoryID,
                id: "mph",
                symbol: "mph",
                singular: "mile per hour",
                factor: metersPerSecondPerMilePerHour,
                plural: "miles per hour",
                aliases: ["mi/h", "milesperhour"],
                tags: ["us"],
                definition: "Road speeds in the US and UK."),
            Unit.linear(
                categoryID: categoryID,
                id: "knot",
                symbol: "kn",
                singular: "knot",
                factor: metersPerSecondPerKnot,
                plural: "knots",
                aliases: ["kt", "kts", "knots"],
                tags: ["maritime"],
                definition: "One nautical mile per hour."),
            Unit.linear(
                categoryID: categoryID,
                id: "ftps",
                symbol: "ft/s",
                singular: "foot per second",
                factor: metersPerSecondPerFootPerSecond,
                plural: "feet per second",
                aliases: ["fps", "ftps", "feetpersecond"],
                tags: ["us"],
                definition: "Ballistics and airspeed in US units."),
            Unit.linear(
                categoryID: categoryID,
                id: "mach",
                symbol: "M",
                singular: "mach",
                factor: metersPerSecondPerMach,
                plural: "mach",
                aliases: ["mach", "machs", "machnumber"],
                tags: ["aviation"],
                definition: "Reference mach 1: 340.29 m/s at sea level, 15 °C."),
            Unit.linear(
                categoryID: categoryID,
                id: "lightspeed",
                symbol: "c",
                singular: "speed of light",
                factor: speedOfLight,
                plural: "speeds of light",
                aliases: ["lightspeed", "speedoflight"],
                tags: ["physics"],
                definition: "Exactly 299792458 m/s in vacuum.")
        ]
        return Category(
            id: categoryID,
            displayName: "Speed",
            summary: "Velocities from knots to the speed of light.",
            baseUnitID: "mps",
            aliases: ["velocity", "pace", "speeds"],
            units: units,
            note: "Mach uses the reference value 340.29 m/s (sea level, 15 °C); "
                + "the real mach number varies with air temperature and pressure.")
    }
}
