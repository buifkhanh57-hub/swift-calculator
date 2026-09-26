//
//  Time.swift
//  unitwise
//
//  The `time` category. Base unit: second (SI).
//
//  Calendar conventions, stated explicitly because they are the usual
//  source of off-by-a-lot bugs:
//    * year  = one JULIAN year = 365.25 days = 31557600 s (also what the
//      light-year is built on, which keeps length↔time consistent)
//    * month = one mean Gregorian month = 31556952 s / 12 = 2629746 s
//      (30.436875 days); real calendar months vary, so treat this as an
//      average
//    * week, day, hour, minute are exact; a fortnight is 2 weeks
//

// MARK: - TimeCategory

/// Builds the `time` category for `CategoryRegistry`.
public enum TimeCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "time"

    /// Calendar constants, kept as named constants for docs and selftests.
    static let secondsPerMinute = 60.0
    static let secondsPerHour = 3600.0
    static let secondsPerDay = 86400.0
    static let secondsPerWeek = 604800.0
    static let secondsPerJulianYear = 31557600.0
    static let secondsPerMeanMonth = 31556952.0 / 12.0

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "second",
                symbol: "s",
                singular: "second",
                factor: 1,
                plural: "seconds",
                aliases: ["sec", "secs"],
                tags: ["si", "base"],
                definition: "SI base unit, defined by the cesium-133 transition."),
            Unit.linear(
                categoryID: categoryID,
                id: "millisecond",
                symbol: "ms",
                singular: "millisecond",
                factor: 0.001,
                plural: "milliseconds",
                aliases: ["msec", "msecs"],
                tags: ["si"],
                definition: "Latency budgets and frame times."),
            Unit.linear(
                categoryID: categoryID,
                id: "microsecond",
                symbol: "µs",
                singular: "microsecond",
                factor: 1e-6,
                plural: "microseconds",
                aliases: ["us", "usec", "usecs"],
                tags: ["si"],
                definition: "Function-profile territory."),
            Unit.linear(
                categoryID: categoryID,
                id: "nanosecond",
                symbol: "ns",
                singular: "nanosecond",
                factor: 1e-9,
                plural: "nanoseconds",
                aliases: ["nsec", "nsecs"],
                tags: ["si"],
                definition: "Clock-cycle scale; light travels ~30 cm per ns."),
            Unit.linear(
                categoryID: categoryID,
                id: "minute",
                symbol: "min",
                singular: "minute",
                factor: secondsPerMinute,
                plural: "minutes",
                aliases: ["mins", "minutes"],
                tags: [],
                definition: "Exactly 60 seconds."),
            Unit.linear(
                categoryID: categoryID,
                id: "hour",
                symbol: "h",
                singular: "hour",
                factor: secondsPerHour,
                plural: "hours",
                aliases: ["hr", "hrs", "hours"],
                tags: [],
                definition: "Exactly 3600 seconds."),
            Unit.linear(
                categoryID: categoryID,
                id: "day",
                symbol: "d",
                singular: "day",
                factor: secondsPerDay,
                plural: "days",
                aliases: ["days"],
                tags: [],
                definition: "Exactly 86400 seconds (a mean solar day)."),
            Unit.linear(
                categoryID: categoryID,
                id: "week",
                symbol: "wk",
                singular: "week",
                factor: secondsPerWeek,
                plural: "weeks",
                aliases: ["wks", "weeks"],
                tags: [],
                definition: "Exactly 7 days."),
            Unit.linear(
                categoryID: categoryID,
                id: "fortnight",
                symbol: "fortnight",
                singular: "fortnight",
                factor: 2 * secondsPerWeek,
                plural: "fortnights",
                aliases: ["fortnights", "fn"],
                tags: ["legacy"],
                definition: "Two weeks; UK pay cycles."),
            Unit.linear(
                categoryID: categoryID,
                id: "month",
                symbol: "mo",
                singular: "month",
                factor: secondsPerMeanMonth,
                plural: "months",
                aliases: ["mon", "months"],
                tags: ["calendar"],
                definition: "Mean Gregorian month: 30.436875 days."),
            Unit.linear(
                categoryID: categoryID,
                id: "year",
                symbol: "yr",
                singular: "year",
                factor: secondsPerJulianYear,
                plural: "years",
                aliases: ["yrs", "years", "julianyear", "julianyears"],
                tags: ["calendar"],
                definition: "Julian year: 365.25 days; same year as the light-year."),
            Unit.linear(
                categoryID: categoryID,
                id: "decade",
                symbol: "decade",
                singular: "decade",
                factor: 10 * secondsPerJulianYear,
                plural: "decades",
                aliases: ["decades"],
                tags: ["calendar"],
                definition: "Ten Julian years."),
            Unit.linear(
                categoryID: categoryID,
                id: "century",
                symbol: "century",
                singular: "century",
                factor: 100 * secondsPerJulianYear,
                plural: "centuries",
                aliases: ["centuries"],
                tags: ["calendar"],
                definition: "One hundred Julian years."),
            Unit.linear(
                categoryID: categoryID,
                id: "millennium",
                symbol: "millennium",
                singular: "millennium",
                factor: 1000 * secondsPerJulianYear,
                plural: "millennia",
                aliases: ["millennia", "millenniums"],
                tags: ["calendar"],
                definition: "One thousand Julian years.")
        ]
        return Category(
            id: categoryID,
            displayName: "Time",
            summary: "Durations from nanoseconds to millennia.",
            baseUnitID: "second",
            aliases: ["duration", "durations", "times"],
            units: units,
            note: "Year = Julian year (365.25 d); month = mean Gregorian month "
                + "(30.436875 d). Calendar-real month arithmetic is out of scope.")
    }
}
