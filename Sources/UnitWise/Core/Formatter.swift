//
//  Formatter.swift
//  unitwise
//
//  Output layer, kept separate from the math so `--json` can be guaranteed
//  byte-stable and the human output can honor `--digits`:
//
//    * NumberText.significant — significant-figure rendering without
//     Foundation's locale machinery (no NumberFormatter, no grouping
//      surprises on Linux). Uses only integer loops for powers of ten, so
//      results are identical on macOS and Linux.
//    * NumberText.jsonNumber / escape — JSON-safe scalar rendering built by
//      hand because unitwise has zero dependencies.
//    * ResultFormatter — turns a ConversionResult into the human line
//      ("5 km = 3.10686 mi") or the pretty JSON document behind --json.
//    * TableFormatter — width-fitted ASCII tables for `list`, `table`,
//      and `history`.
//
//  Rendering is pure: no global state, no locale, no clock — the same
//  result object always renders to the same string, which is what the
//  tests (and scripts that diff output) rely on.
//

import Foundation

// MARK: - OutputFormat

/// Selects between human-readable text and machine-readable JSON.
public enum OutputFormat: String, CaseIterable {

    /// Default: one aligned human line per conversion.
    case human
    /// `--json`: pretty-printed, key-sorted-by-hand JSON document.
    case json

    /// Parses a user-facing format name; nil when unrecognized.
    public static func parse(_ token: String) -> OutputFormat? {
        switch token.lowercased() {
        case "human", "text", "plain":
            return .human
        case "json":
            return .json
        default:
            return nil
        }
    }
}

// MARK: - NumberText

/// Locale-independent number and string rendering helpers.
public enum NumberText {

    // MARK: Significant figures

    /// Renders `value` with exactly `figures` significant digits.
    ///
    /// Strategy (deterministic on every platform):
    ///   1. find the decimal exponent with an integer loop (no log10),
    ///   2. round the value onto a quantum of 10^(exponent - figures + 1),
    ///   3. print fixed-point when the exponent is moderate, and switch to
    ///      scientific notation for |exponent| ≥ 15.
    ///
    /// Examples with figures = 6:
    ///   3.1068559611866697 → "3.10686"      123456789 → "123457000"
    ///   0.00064516         → "0.000645160"  0         → "0"
    ///   1e15               → "1.000e+15"
    public static func significant(_ value: Double, figures: Int) -> String {
        guard value.isFinite else {
            return value.isNaN ? "NaN" : (value > 0 ? "inf" : "-inf")
        }
        let clamped = min(max(figures, 1), 15)
        if value == 0 { return "0" }

        let exponent = decimalExponent(of: value)
        let quantum = powerOfTen(exponent - clamped + 1)
        let rounded = (value / quantum).rounded() * quantum

        let decimals = max(0, clamped - 1 - exponent)
        if decimals > 0 {
            return String(format: "%.\(decimals)f", rounded)
        }
        if abs(exponent) >= 15 {
            return String(format: "%.\(max(0, clamped - 1))e", rounded)
        }
        return String(format: "%.0f", rounded)
    }

    /// Decimal exponent of a finite, non-zero Double, found by repeated
    /// scaling instead of log10 — avoids libm differences across platforms.
    static func decimalExponent(of value: Double) -> Int {
        var magnitude = abs(value)
        var exponent = 0
        if magnitude >= 1 {
            while magnitude >= 10 {
                magnitude /= 10
                exponent += 1
            }
        } else {
            while magnitude < 1, exponent > -400 {
                magnitude *= 10
                exponent -= 1
            }
        }
        return exponent
    }

    /// 10^exponent by explicit multiplication — exact enough for the small
    /// exponents used here and identical on every platform.
    static func powerOfTen(_ exponent: Int) -> Double {
        var result = 1.0
        if exponent >= 0 {
            for _ in 0..<exponent { result *= 10.0 }
        } else {
            for _ in 0..<(-exponent) { result /= 10.0 }
        }
        return result
    }

    // MARK: JSON scalars

    /// Renders a Double as a JSON number. Uses Swift's shortest round-trip
    /// description ("5.0", "3.1068559611866697") and degrades non-finite
    /// values to null rather than emitting invalid JSON.
    public static func jsonNumber(_ value: Double) -> String {
        guard value.isFinite else { return "null" }
        return "\(value)"
    }

    /// Escapes a String for embedding inside a JSON string literal.
    public static func escape(_ string: String) -> String {
        var output = ""
        output.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            default: output.append(character)
            }
        }
        return output
    }
}

// MARK: - ResultFormatter

/// Renders a `ConversionResult` as human text or JSON.
public struct ResultFormatter {

    /// Human line or JSON document.
    public let format: OutputFormat
    /// Significant figures applied to the converted value.
    public let precision: PrecisionRules
    /// When true, human output gains the "via base · round-trip" detail line.
    public let includeDetails: Bool

    /// Creates a formatter; defaults match the CLI's plain mode.
    public init(format: OutputFormat = .human,
                precision: PrecisionRules = PrecisionRules(),
                includeDetails: Bool = false) {
        self.format = format
        self.precision = precision
        self.includeDetails = includeDetails
    }

    /// Renders the result. Human mode yields one line (plus a detail line
    /// when `includeDetails`); JSON mode yields a pretty multi-line document.
    public func render(_ result: ConversionResult) -> String {
        switch format {
        case .human:
            return renderHuman(result)
        case .json:
            return renderJSON(result)
        }
    }

    /// "5 km = 3.10686 mi" (+ detail line when requested).
    func renderHuman(_ result: ConversionResult) -> String {
        let request = result.request
        let input = Unit.trimNumber(request.value)
        let output = NumberText.significant(result.result, figures: precision.significantFigures)
        var line = "\(input) \(request.from.symbol) = \(output) \(request.to.symbol)"
        if includeDetails {
            let baseSymbol = request.category.baseUnit?.symbol ?? "?"
            let base = Unit.trimNumber(result.baseValue)
            let back = Unit.trimNumber(result.roundTrip)
            let quality = result.exact ? "exact" : "approximate"
            line += "\n  via \(baseSymbol): \(base)"
                + " · round-trip \(back) \(request.from.symbol)"
                + " · \(quality)"
        }
        return line
    }

    /// Pretty JSON document, assembled by hand for byte-stable output.
    func renderJSON(_ result: ConversionResult) -> String {
        let request = result.request
        let formatted = NumberText.significant(result.result,
                                               figures: precision.significantFigures)
        return """
        {
          "expression": "\(NumberText.escape(request.expression))",
          "category": "\(NumberText.escape(request.category.id))",
          "input": { "value": \(NumberText.jsonNumber(request.value)), "unit": "\(NumberText.escape(request.from.symbol))" },
          "result": { "value": \(NumberText.jsonNumber(result.result)), "unit": "\(NumberText.escape(request.to.symbol))", "formatted": "\(NumberText.escape(formatted))" },
          "base": { "value": \(NumberText.jsonNumber(result.baseValue)), "unit": "\(NumberText.escape(request.category.baseUnitID))" },
          "roundTrip": \(NumberText.jsonNumber(result.roundTrip)),
          "exact": \(result.exact)
        }
        """
    }
}

// MARK: - TableFormatter

/// Width-fitted ASCII tables shared by `list`, `table`, and `history`.
///
/// Layout contract: every line has the same character count; columns are
/// separated by two spaces; a dashed underline follows the header. Cells
/// are left-aligned — numbers included — because conversion tables read
/// better when units line up with their headers.
public struct TableFormatter {

    /// Creates a formatter (kept as a type for future style options).
    public init() {}

    /// Renders headers plus rows into an aligned multi-line string with no
    /// trailing newline.
    public static func render(headers: [String], rows: [[String]]) -> String {
        var widths = headers.map { $0.count }
        for row in rows {
            for (column, cell) in row.enumerated() where column < widths.count {
                widths[column] = max(widths[column], cell.count)
            }
        }

        func padded(_ text: String, width: Int) -> String {
            text + String(repeating: " ", count: max(0, width - text.count))
        }

        var lines: [String] = []
        lines.append(zip(headers, widths).map { padded($0, width: $1) }
            .joined(separator: "  "))
        lines.append(widths.map { String(repeating: "-", count: $0) }
            .joined(separator: "  "))
        for row in rows {
            var cells: [String] = []
            cells.reserveCapacity(widths.count)
            for (column, width) in widths.enumerated() {
                let cell = column < row.count ? row[column] : ""
                cells.append(padded(cell, width: width))
            }
            lines.append(cells.joined(separator: "  "))
        }
        return lines.joined(separator: "\n")
    }
}
