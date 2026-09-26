//
//  Batch.swift
//  unitwise
//
//  CSV-driven bulk conversion behind `unitwise batch`.
//
//  Input accepts two row shapes, decided per row by column count:
//    * "value,from,to"  → 5,km,mi        (columns resolved independently)
//    * one expression   → 5 km to mi     (full parser, --to honored)
//
//  Failure policy is ROW-LOCAL: one bad row never aborts the run. Every row
//  produces an output row with status "ok" or "error" plus the error text,
//  so operators can round-trip the file after fixing the failures. The CLI
//  turns a non-zero failure count into exit code 3 (`batchPartial`) AFTER
//  the CSV has been written — see Errors.swift.
//
//  The CSV reader is a hand-written state machine (quotes, escaped quotes,
//  commas and newlines inside quotes, LF and CRLF) — no dependency, no
//  regex, deterministic on every platform.
//

import Foundation

// MARK: - BatchRowResult

/// The outcome of one input row: its 1-based line number, its status, and
/// the exact CSV cells to emit for it.
public struct BatchRowResult: Equatable {

    /// Status marker for a converted row.
    public static let ok = "ok"
    /// Status marker for a failed row.
    public static let error = "error"

    /// 1-based line number in the INPUT text (header included in counting).
    public let line: Int
    /// "ok" or "error".
    public let status: String
    /// Output cells: line, input, from, to, result, status, error.
    public let cells: [String]

    /// Builds a result; cells are stored as given.
    public init(line: Int, status: String, cells: [String]) {
        self.line = line
        self.status = status
        self.cells = cells
    }
}

// MARK: - BatchReport

/// Aggregated outcome of one batch run plus its CSV rendering.
public struct BatchReport: Equatable {

    /// Header cells emitted only when the input declared a header row.
    public let header: [String]
    /// One result per processed (non-blank) row.
    public let rows: [BatchRowResult]

    /// Total processed rows.
    public var total: Int { rows.count }
    /// Rows that converted successfully.
    public var succeeded: Int { rows.filter { $0.status == BatchRowResult.ok }.count }
    /// Rows that failed (drives the exit-3 contract).
    public var failed: Int { total - succeeded }

    /// Builds a report from its parts.
    public init(header: [String], rows: [BatchRowResult]) {
        self.header = header
        self.rows = rows
    }

    /// Renders the CSV output: optional header line, then one line per row,
    /// every cell escaped, lines terminated with a single trailing newline.
    public var csv: String {
        var lines: [String] = []
        if !header.isEmpty {
            lines.append(header.map { BatchProcessor.escapeCSV($0) }.joined(separator: ","))
        }
        for row in rows {
            lines.append(row.cells.map { BatchProcessor.escapeCSV($0) }.joined(separator: ","))
        }
        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - BatchProcessor

/// Parses CSV text, evaluates every row through the shared engine, and
/// produces a `BatchReport`.
public enum BatchProcessor {

    /// Output column contract, shared by both row shapes.
    public static let outputHeader = ["line", "input", "from", "to", "result", "status", "error"]

    // MARK: Entry point

    /// Processes `text` (UTF-8 CSV) against `resolver`.
    ///
    /// `hasHeader` skips the first row as a header (and emits a header line
    /// in the output). `toOverride` applies to single-column expression rows
    /// exactly like `--to` does in interactive mode. Row failures are
    /// captured into the report; this function itself does not throw.
    public static func process(_ text: String,
                               resolver: UnitResolver,
                               hasHeader: Bool,
                               toOverride: String? = nil) -> BatchReport {
        let grid = parseCSV(text)
        let firstDataRow = hasHeader ? 1 : 0
        var rows: [BatchRowResult] = []

        for (offset, fields) in grid.enumerated() where offset >= firstDataRow {
            let line = offset + 1
            if fields.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                continue // blank line: not an error, just noise
            }
            do {
                let evaluated = try evaluateRow(fields,
                                                resolver: resolver,
                                                toOverride: toOverride)
                let request = evaluated.request
                let result = evaluated.result
                guard result.isFinite else { throw UnitWiseError.numericOverflow }
                let input = "\(Unit.trimNumber(request.value)) \(request.from.symbol)"
                    + " to \(request.to.symbol)"
                let cells = [String(line),
                             input,
                             request.from.symbol,
                             request.to.symbol,
                             Unit.trimNumber(result),
                             BatchRowResult.ok,
                             ""]
                rows.append(BatchRowResult(line: line, status: BatchRowResult.ok, cells: cells))
            } catch let error as UnitWiseError {
                let cells = [String(line),
                             fields.map { $0.trimmingCharacters(in: .whitespaces) }
                                 .joined(separator: " "),
                             "", "", "",
                             BatchRowResult.error,
                             error.description]
                rows.append(BatchRowResult(line: line, status: BatchRowResult.error, cells: cells))
            } catch {
                let cells = [String(line), "", "", "", "",
                             BatchRowResult.error,
                             "unexpected error: \(error)"]
                rows.append(BatchRowResult(line: line, status: BatchRowResult.error, cells: cells))
            }
        }

        return BatchReport(header: hasHeader ? outputHeader : [],
                           rows: rows)
    }

    // MARK: Row evaluation

    /// Converts one CSV row into a request + result, or throws.
    /// Exactly 3 columns → value/from/to; exactly 1 column → expression;
    /// anything else is a row-shape error.
    static func evaluateRow(_ fields: [String],
                            resolver: UnitResolver,
                            toOverride: String?) throws
        -> (request: ConversionRequest, result: Double) {
        let trimmed = fields.map { $0.trimmingCharacters(in: .whitespaces) }

        if trimmed.count == 3 {
            guard let value = Double(trimmed[0]), value.isFinite else {
                throw UnitWiseError.invalidNumber(trimmed[0])
            }
            let from = try ExpressionParser.resolveSingle(trimmed[1],
                                                          anchor: nil,
                                                          resolver: resolver)
            let to = try ExpressionParser.resolveSingle(trimmed[2],
                                                        anchor: nil,
                                                        resolver: resolver)
            guard from.categoryID == to.categoryID else {
                throw UnitWiseError.categoryMismatch(from: from.qualifiedName,
                                                     to: to.qualifiedName)
            }
            guard let category = resolver.category(withID: from.categoryID) else {
                throw UnitWiseError.config(
                    "category '\(from.categoryID)' missing from resolver")
            }
            let request = ConversionRequest(value: value,
                                            from: from,
                                            to: to,
                                            category: category,
                                            expression: trimmed.joined(separator: ","))
            return (request, ConversionEngine.convert(value, from: from, to: to))
        }

        if trimmed.count == 1 {
            let expression = trimmed[0]
            let request = try ExpressionParser.parse(expression: expression,
                                                     resolver: resolver,
                                                     toOverride: toOverride)
            return (request, ConversionEngine.convert(request.value,
                                                      from: request.from,
                                                      to: request.to))
        }

        throw UnitWiseError.parse(
            "row must have 1 expression column or 3 value,from,to columns, "
                + "got \(trimmed.count)",
            offset: nil)
    }

    // MARK: CSV reader

    /// Hand-written CSV parser: supports quoted fields, "" escapes, commas
    /// and newlines inside quotes, and both LF and CRLF line endings.
    /// A trailing newline does not produce an empty trailing row.
    public static func parseCSV(_ text: String) -> [[String]] {
        let characters = Array(text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = 0

        func endField() {
            row.append(field)
            field = ""
        }

        func endRow() {
            endField()
            rows.append(row)
            row = []
        }

        while index < characters.count {
            let character = characters[index]

            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }
                field.append(character)
                index += 1
                continue
            }

            switch character {
            case "\"":
                inQuotes = true
                index += 1
            case ",":
                endField()
                index += 1
            case "\r":
                if index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }
                endRow()
                index += 1
            case "\n":
                endRow()
                index += 1
            default:
                field.append(character)
                index += 1
            }
        }

        if inQuotes || !field.isEmpty || !row.isEmpty {
            endRow()
        }
        return rows
    }

    /// Escapes one CSV cell: quotes wrap fields containing comma, quote, or
    /// newline; embedded quotes double up.
    public static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"")
            || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    // MARK: File helpers

    /// Reads a batch input file (or stdin when path is "-").
    public static func readInput(at path: String) throws -> String {
        if path == "-" {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw UnitWiseError.io("standard input is not valid UTF-8")
            }
            return decoded
        }
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw UnitWiseError.io(
                "cannot read '\(path)': \(error.localizedDescription)")
        }
    }

    /// Writes the CSV output file with a trailing newline.
    public static func writeOutput(_ report: BatchReport, to path: String) throws {
        do {
            try report.csv.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw UnitWiseError.io(
                "cannot write '\(path)': \(error.localizedDescription)")
        }
    }
}
