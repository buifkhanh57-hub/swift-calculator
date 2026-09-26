//
//  DataSize.swift
//  unitwise
//
//  The `datasize` category plus the base-preference policy that governs it.
//  Base unit: byte.
//
//  Two incompatible worlds live here, and unitwise refuses to blur them:
//
//    * DECIMAL (SI):  kB = 1000 B, MB = 1e6 B, GB = 1e9 B, TB = 1e12 B, PB = 1e15 B
//    * BINARY (IEC):  KiB = 1024 B, MiB = 1024² B, GiB = 1024³ B,
//                     TiB = 1024⁴ B, PiB = 1024⁵ B
//
//  When a token is unambiguous (kB, MiB, kbit...) it always means exactly
//  what it says. The only loose tokens are kB-style abbreviations, and the
//  `--base2` / `--iec` flag decides how they are read:
//
//      unitwise 3.5 MB to KB          # decimal: 3500 kB
//      unitwise --base2 3.5 MB to KB  # binary:  3.5 MiB = 3670.016 kB
//
//  The flag is implemented as a token remap (see `DataSizeBase`), applied
//  before parsing, so the conversion math itself never needs special cases.
//  Bit units (bit, kbit, Mbit, Gbit, Tbit) are 1/8 of their byte cousins
//  and are never remapped.
//

// MARK: - DataSizeBase

/// Chooses how loose data-size tokens (kB/MB/GB/TB/PB) are interpreted.
///
/// `.decimal` is the default and changes nothing (the registry is already
/// decimal-native). `.binary` rewrites the loose tokens to their IEC
/// equivalents before parsing, which is what `--base2` / `--iec` request.
public enum DataSizeBase: String, CaseIterable {

    /// SI decimal base: kB = 1000 B.
    case decimal
    /// IEC binary base: loose tokens behave like KiB/MiB/GiB/TiB/PiB.
    case binary

    /// Parses a user-facing base name ("base2", "iec", "si", "1000"...).
    public static func parse(_ token: String) -> DataSizeBase? {
        switch token.lowercased() {
        case "decimal", "si", "dec", "1000":
            return .decimal
        case "binary", "iec", "base2", "1024":
            return .binary
        default:
            return nil
        }
    }

    /// The loose tokens whose meaning depends on the preferred base.
    /// Deliberately excludes single letters (k/m/g) to avoid stealing
    /// tokens that other categories own (kelvin, meter, gram...).
    static let ambiguousTokens: [String] = ["kb", "mb", "gb", "tb", "pb"]

    /// Token substitutions applied before parsing, keyed by the lowercased
    /// loose token. Decimal mode is an identity map.
    public var substitutions: [String: String] {
        switch self {
        case .decimal:
            return [:]
        case .binary:
            return [
                "kb": "kib",
                "mb": "mib",
                "gb": "gib",
                "tb": "tib",
                "pb": "pib"
            ]
        }
    }

    /// Rewrites loose data-size tokens inside a whitespace-separated
    /// expression. Separator words ("to", "in", "->"...) and numbers are
    /// untouched, and non-data-size tokens pass through unchanged, so the
    /// remap is safe to apply to any expression.
    public func remapExpression(_ expression: String) -> String {
        let map = substitutions
        guard !map.isEmpty else { return expression }
        var parts: [String] = []
        parts.reserveCapacity(expression.count / 2 + 1)
        for part in expression.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
            let lowered = part.lowercased()
            parts.append(map[lowered] ?? String(part))
        }
        return parts.joined(separator: " ")
    }

    /// Human-readable byte count ("1.50 KiB", "1.50 kB", "0 B") using the
    /// 1024 or 1000 ladder depending on `base`. Used by `convert --human`
    /// and by the history listing to size the history file.
    public static func humanBytes(_ byteCount: Double,
                                  base: DataSizeBase = .decimal,
                                  decimals: Int = 2) -> String {
        guard byteCount.isFinite, byteCount > 0 else {
            return byteCount == 0 ? "0 B" : Unit.trimNumber(byteCount) + " B"
        }
        let ladder: [(threshold: Double, suffix: String)] = base == .binary
            ? [(1, "B"),
               (1024, "KiB"),
               (1048576, "MiB"),
               (1073741824, "GiB"),
               (1099511627776, "TiB"),
               (1125899906842624, "PiB")]
            : [(1, "B"),
               (1000, "kB"),
               (1e6, "MB"),
               (1e9, "GB"),
               (1e12, "TB"),
               (1e15, "PB")]
        var chosen = ladder[0]
        for candidate in ladder where byteCount >= candidate.threshold {
            chosen = candidate
        }
        let scaled = byteCount / chosen.threshold
        let clamped = max(0, min(8, decimals))
        if chosen.suffix == "B" {
            return String(format: "%.0f", scaled) + " B"
        }
        return String(format: "%.\(clamped)f", scaled) + " " + chosen.suffix
    }
}

// MARK: - DataSizeCategory

/// Builds the `datasize` category for `CategoryRegistry`.
public enum DataSizeCategory {

    /// Registry identifier shared by every member unit.
    static let categoryID = "datasize"

    /// The two ladder steps, as named constants.
    static let decimalStep = 1000.0
    static let binaryStep = 1024.0

    /// Assembles the category.
    public static func make() -> Category {
        let units: [Unit] = [
            Unit.linear(
                categoryID: categoryID,
                id: "bit",
                symbol: "b",
                singular: "bit",
                factor: 0.125,
                plural: "bits",
                aliases: ["bits"],
                tags: ["bits"],
                definition: "Smallest unit; note lowercase b, 8 bits = 1 byte."),
            Unit.linear(
                categoryID: categoryID,
                id: "byte",
                symbol: "B",
                singular: "byte",
                factor: 1,
                plural: "bytes",
                aliases: [],
                tags: ["base"],
                definition: "8 bits; the category base unit."),
            Unit.linear(
                categoryID: categoryID,
                id: "kilobit",
                symbol: "kbit",
                singular: "kilobit",
                factor: 125,
                plural: "kilobits",
                aliases: ["kbits", "kilobits"],
                tags: ["bits", "decimal"],
                definition: "1000 bits; telecom link speeds."),
            Unit.linear(
                categoryID: categoryID,
                id: "megabit",
                symbol: "Mbit",
                singular: "megabit",
                factor: 125000,
                plural: "megabits",
                aliases: ["mbits", "megabits"],
                tags: ["bits", "decimal"],
                definition: "1e6 bits; internet bandwidth."),
            Unit.linear(
                categoryID: categoryID,
                id: "gigabit",
                symbol: "Gbit",
                singular: "gigabit",
                factor: 1.25e8,
                plural: "gigabits",
                aliases: ["gbits", "gigabits"],
                tags: ["bits", "decimal"],
                definition: "1e9 bits; gigabit ethernet."),
            Unit.linear(
                categoryID: categoryID,
                id: "terabit",
                symbol: "Tbit",
                singular: "terabit",
                factor: 1.25e11,
                plural: "terabits",
                aliases: ["tbits", "terabits"],
                tags: ["bits", "decimal"],
                definition: "1e12 bits; backbone links."),
            Unit.linear(
                categoryID: categoryID,
                id: "kilobyte",
                symbol: "kB",
                singular: "kilobyte",
                factor: decimalStep,
                plural: "kilobytes",
                aliases: ["kb", "kilobytes"],
                tags: ["decimal"],
                definition: "DECIMAL kilobyte: exactly 1000 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "megabyte",
                symbol: "MB",
                singular: "megabyte",
                factor: decimalStep * decimalStep,
                plural: "megabytes",
                aliases: ["mb", "meg", "megs", "megabytes"],
                tags: ["decimal"],
                definition: "DECIMAL megabyte: exactly 1e6 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "gigabyte",
                symbol: "GB",
                singular: "gigabyte",
                factor: decimalStep * decimalStep * decimalStep,
                plural: "gigabytes",
                aliases: ["gb", "gig", "gigs", "gigabytes"],
                tags: ["decimal"],
                definition: "DECIMAL gigabyte: exactly 1e9 bytes; disk marketing."),
            Unit.linear(
                categoryID: categoryID,
                id: "terabyte",
                symbol: "TB",
                singular: "terabyte",
                factor: decimalStep * decimalStep * decimalStep * decimalStep,
                plural: "terabytes",
                aliases: ["tb", "terabytes"],
                tags: ["decimal"],
                definition: "DECIMAL terabyte: exactly 1e12 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "petabyte",
                symbol: "PB",
                singular: "petabyte",
                factor: decimalStep * decimalStep * decimalStep * decimalStep * decimalStep,
                plural: "petabytes",
                aliases: ["pb", "petabytes"],
                tags: ["decimal"],
                definition: "DECIMAL petabyte: exactly 1e15 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "kibibyte",
                symbol: "KiB",
                singular: "kibibyte",
                factor: binaryStep,
                plural: "kibibytes",
                aliases: ["kib", "kibibytes"],
                tags: ["binary"],
                definition: "BINARY kilobyte: exactly 1024 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "mebibyte",
                symbol: "MiB",
                singular: "mebibyte",
                factor: binaryStep * binaryStep,
                plural: "mebibytes",
                aliases: ["mib", "mebibytes"],
                tags: ["binary"],
                definition: "BINARY megabyte: exactly 1048576 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "gibibyte",
                symbol: "GiB",
                singular: "gibibyte",
                factor: binaryStep * binaryStep * binaryStep,
                plural: "gibibytes",
                aliases: ["gib", "gibibytes"],
                tags: ["binary"],
                definition: "BINARY gigabyte: exactly 1073741824 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "tebibyte",
                symbol: "TiB",
                singular: "tebibyte",
                factor: binaryStep * binaryStep * binaryStep * binaryStep,
                plural: "tebibytes",
                aliases: ["tib", "tebibytes"],
                tags: ["binary"],
                definition: "BINARY terabyte: exactly 1099511627776 bytes."),
            Unit.linear(
                categoryID: categoryID,
                id: "pebibyte",
                symbol: "PiB",
                singular: "pebibyte",
                factor: binaryStep * binaryStep * binaryStep * binaryStep * binaryStep,
                plural: "pebibytes",
                aliases: ["pib", "pebibytes"],
                tags: ["binary"],
                definition: "BINARY petabyte: exactly 1125899906842624 bytes.")
        ]
        return Category(
            id: categoryID,
            displayName: "Data Size",
            summary: "Bits, decimal bytes (kB = 1000), and binary bytes (KiB = 1024).",
            baseUnitID: "byte",
            aliases: ["data", "digital", "storage", "size", "bytes", "datasizes"],
            units: units,
            note: "kB/MB/GB/TB/PB are decimal (×1000) and KiB/MiB/GiB/TiB/PiB "
                + "are binary (×1024). Pass --base2 (or --iec) to read the loose "
                + "kB-style tokens as binary; bit units are never remapped.")
    }
}
