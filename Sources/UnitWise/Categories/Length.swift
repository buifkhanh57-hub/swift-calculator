//
//  Length.swift
//  unitwise
//
//  The `length` category. Base unit: meter (SI).
//
//  Factors below are exact by international agreement:
//    * inch  = 0.0254 m      (1959 international yard-and-pound agreement)
//    * mile  = 1609.344 m    (5280 survey-exact feet)
//    * nautical mile = 1852 m (exact since 1929)
//    * astronomical unit = 1.495978707e11 m (exact, IAU 2012 resolution)
//    * light-year and parsec use the IAU Julian-year constants.
//
//  Tokens spelled with `µ` are also accepted in their ASCII forms ("um")
//  because ExpressionParser normalizes µ → u before alias lookup.
//

// MARK: - LengthCategory

/// Builds the `length` category for `CategoryRegistry`.
public enum LengthCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "length"

    /// Exact agreed factors, kept as named constants for docs and selftests.
    static let metersPerInch = 0.0254
    static let metersPerFoot = 0.3048
    static let metersPerYard = 0.9144
    static let metersPerMile = 1609.344
    static let metersPerNauticalMile = 1852.0
    static let metersPerFurlong = 201.168
    static let metersPerFathom = 1.8288
    static let metersPerAstronomicalUnit = 1.495978707e11
    static let metersPerLightYear = 9.4607304725808e15
    static let metersPerParsec = 3.0856775814913673e16

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "meter",
                symbol: "m",
                singular: "meter",
                factor: 1,
                plural: "meters",
                aliases: ["metre", "metres"],
                tags: ["si", "base"],
                definition: "SI base unit: distance light travels in 1/299792458 of a second."),
            Unit.linear(
                categoryID: categoryID,
                id: "kilometer",
                symbol: "km",
                singular: "kilometer",
                factor: 1000,
                plural: "kilometers",
                aliases: ["kilometre", "kilometres", "kilo"],
                tags: ["si"],
                definition: "1000 meters; everyday road distances."),
            Unit.linear(
                categoryID: categoryID,
                id: "centimeter",
                symbol: "cm",
                singular: "centimeter",
                factor: 0.01,
                plural: "centimeters",
                aliases: ["centimetre", "centimetres"],
                tags: ["si"],
                definition: "One hundredth of a meter."),
            Unit.linear(
                categoryID: categoryID,
                id: "millimeter",
                symbol: "mm",
                singular: "millimeter",
                factor: 0.001,
                plural: "millimeters",
                aliases: ["millimetre", "millimetres"],
                tags: ["si"],
                definition: "One thousandth of a meter."),
            Unit.linear(
                categoryID: categoryID,
                id: "micrometer",
                symbol: "µm",
                singular: "micrometer",
                factor: 1e-6,
                plural: "micrometers",
                aliases: ["um", "micron", "microns", "micrometre"],
                tags: ["si"],
                definition: "One millionth of a meter; cell-scale lengths."),
            Unit.linear(
                categoryID: categoryID,
                id: "nanometer",
                symbol: "nm",
                singular: "nanometer",
                factor: 1e-9,
                plural: "nanometers",
                aliases: ["nanometre", "nanometres"],
                tags: ["si"],
                definition: "One billionth of a meter; wavelength scale."),
            Unit.linear(
                categoryID: categoryID,
                id: "decimeter",
                symbol: "dm",
                singular: "decimeter",
                factor: 0.1,
                plural: "decimeters",
                aliases: ["decimetre", "decimetres"],
                tags: ["si"],
                definition: "One tenth of a meter."),
            Unit.linear(
                categoryID: categoryID,
                id: "inch",
                symbol: "in",
                singular: "inch",
                factor: metersPerInch,
                plural: "inches",
                aliases: [],
                tags: ["imperial", "us"],
                definition: "Exactly 2.54 cm since 1959."),
            Unit.linear(
                categoryID: categoryID,
                id: "foot",
                symbol: "ft",
                singular: "foot",
                factor: metersPerFoot,
                plural: "feet",
                aliases: [],
                tags: ["imperial", "us"],
                definition: "12 inches; human height and aviation altitudes."),
            Unit.linear(
                categoryID: categoryID,
                id: "yard",
                symbol: "yd",
                singular: "yard",
                factor: metersPerYard,
                plural: "yards",
                aliases: [],
                tags: ["imperial", "us"],
                definition: "3 feet, exactly 0.9144 m."),
            Unit.linear(
                categoryID: categoryID,
                id: "mile",
                symbol: "mi",
                singular: "mile",
                factor: metersPerMile,
                plural: "miles",
                aliases: [],
                tags: ["imperial", "us"],
                definition: "Statute mile: 5280 feet."),
            Unit.linear(
                categoryID: categoryID,
                id: "nauticalmile",
                symbol: "nmi",
                singular: "nautical mile",
                factor: metersPerNauticalMile,
                plural: "nautical miles",
                aliases: ["nauticalmile", "nauticalmiles"],
                tags: ["maritime"],
                definition: "One arc-minute of latitude; aviation and shipping."),
            Unit.linear(
                categoryID: categoryID,
                id: "lightyear",
                symbol: "ly",
                singular: "light-year",
                factor: metersPerLightYear,
                plural: "light-years",
                aliases: ["lightyear", "lightyears", "light-year", "light-years"],
                tags: ["astronomy"],
                definition: "Distance light covers in one Julian year."),
            Unit.linear(
                categoryID: categoryID,
                id: "astronomicalunit",
                symbol: "AU",
                singular: "astronomical unit",
                factor: metersPerAstronomicalUnit,
                plural: "astronomical units",
                aliases: ["au", "astronomicalunit", "astronomicalunits"],
                tags: ["astronomy"],
                definition: "Mean Earth–Sun distance, exact since 2012."),
            Unit.linear(
                categoryID: categoryID,
                id: "parsec",
                symbol: "pc",
                singular: "parsec",
                factor: metersPerParsec,
                plural: "parsecs",
                aliases: ["parsec", "parsecs"],
                tags: ["astronomy"],
                definition: "Distance with 1 arc-second parallax; 3.26 light-years."),
            Unit.linear(
                categoryID: categoryID,
                id: "angstrom",
                symbol: "Å",
                singular: "ångström",
                factor: 1e-10,
                plural: "ångströms",
                aliases: ["angstrom", "angstroms", "a"],
                tags: ["legacy"],
                definition: "1e-10 m; atomic radii and crystallography."),
            Unit.linear(
                categoryID: categoryID,
                id: "fathom",
                symbol: "ftm",
                singular: "fathom",
                factor: metersPerFathom,
                plural: "fathoms",
                aliases: ["fathom", "fathoms"],
                tags: ["maritime"],
                definition: "6 feet; water depth."),
            Unit.linear(
                categoryID: categoryID,
                id: "furlong",
                symbol: "fur",
                singular: "furlong",
                factor: metersPerFurlong,
                plural: "furlongs",
                aliases: ["furlong", "furlongs"],
                tags: ["imperial"],
                definition: "One eighth of a mile; horse racing.")
        ]
        return Category(
            id: categoryID,
            displayName: "Length",
            summary: "Metric and imperial distances, from ångströms to parsecs.",
            baseUnitID: "meter",
            aliases: ["distance", "dist", "lengths"],
            units: units)
    }
}
