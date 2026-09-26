//
//  main.swift
//  unitwise
//
//  CLI front-end: dispatch table, flag parsing, help text, and error
//  reporting. The built-in self-checks live in Core/SelfTest.swift. This
//  is the only file in the target allowed to carry top-level statements
//  (the two-line bootstrap at the bottom).
//
//  Commands: convert (default), list, table, batch, history, help,
//  version, selftest — each with the aliases listed in `Command.aliases`.
//
//  Exit-code contract (mirrors Errors.swift):
//    0   success
//    1   usage error            — bad flags, unknown command/category
//    2   conversion error       — bad expression, unknown/ambiguous unit
//    3   partial batch failure  — at least one CSV row failed
//    4   I/O error              — unreadable input, unwritable output
//    70  internal config error  — registry invariants violated
//

import Foundation

// MARK: - Command

/// Top-level commands and their aliases.
public enum Command: String, CaseIterable {

    case convert, list, table, batch, history, help, version, selftest

    /// Alias table. "-h"/"--help" and "--version"/"-V" are routed here so
    /// `unitwise --help` needs no special-casing in the flag parser.
    public static let aliases: [String: Command] = [
        "c": .convert, "conv": .convert, "cv": .convert,
        "ls": .list, "cats": .list,
        "tbl": .table, "grid": .table,
        "b": .batch, "csv": .batch,
        "hist": .history, "log": .history,
        "h": .help, "-h": .help, "--help": .help,
        "ver": .version, "--version": .version, "-V": .version,
        "test": .selftest, "self-check": .selftest
    ]

    /// Resolves a command word: exact case, alias, then case-insensitively.
    public static func resolve(_ token: String) -> Command? {
        if let exact = Command(rawValue: token) { return exact }
        if let alias = aliases[token] { return alias }
        let lowered = token.lowercased()
        return aliases[lowered] ?? Command(rawValue: lowered)
    }

    /// Sorted vocabulary used for "did you mean" hints.
    public static var vocabulary: [String] {
        allCases.map { $0.rawValue } + aliases.keys.sorted()
    }
}

// MARK: - Options

/// Parsed command-line flags shared by all commands.
public struct Options {

    /// Output format (human by default, JSON via --json).
    public var format: OutputFormat = .human
    /// Significant-figure policy (--digits 1...15).
    public var precision: PrecisionRules = PrecisionRules()
    /// Data-size base preference (--base2/--iec, --decimal).
    public var base: DataSizeBase = .decimal
    /// Verbose extras (category notes, history footer).
    public var verbose = false
    /// --to UNIT override for the target unit.
    public var toOverride: String?
    /// --in FILE for batch input.
    public var inputPath: String?
    /// --out FILE for batch output.
    public var outputPath: String?
    /// --limit N for history listings.
    public var limit: Int?
    /// --header / --no-header for batch CSVs.
    public var header = false
    /// --clear for history.
    public var clearHistory = false
    /// --no-history skips recording successful conversions.
    public var noHistory = false
    /// Positional arguments left after flag removal.
    public var positional: [String] = []

    public init() {}

    /// Parses `--flag value` and `--flag=value` forms plus boolean flags.
    /// Unknown flags throw `unknownFlag`; value flags without a value throw
    /// `missingFlagValue`. Negative numbers ("-3") are positional values.
    public static func parse(_ arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            if argument == "-" || !argument.hasPrefix("-") || Options.isNegativeNumber(argument) {
                options.positional.append(argument)
                index += 1
                continue
            }

            var name = argument
            var attached: String?
            if let equals = argument.firstIndex(of: "=") {
                name = String(argument[argument.startIndex..<equals])
                attached = String(argument[argument.index(after: equals)...])
            }

            func consumeValue() throws -> String {
                if let attached = attached { return attached }
                let next = index + 1
                guard next < arguments.count else {
                    throw UnitWiseError.missingFlagValue(name)
                }
                index = next
                return arguments[next]
            }

            switch name {
            case "--digits":
                let raw = try consumeValue()
                guard let figures = Int(raw),
                      PrecisionRules.allowedRange.contains(figures) else {
                    throw UnitWiseError.invalidPrecision(raw)
                }
                options.precision = PrecisionRules(significantFigures: figures)
            case "--to":
                options.toOverride = try consumeValue()
            case "--in":
                options.inputPath = try consumeValue()
            case "--out":
                options.outputPath = try consumeValue()
            case "--limit":
                let raw = try consumeValue()
                guard let parsed = Int(raw), parsed >= 0 else {
                    throw UnitWiseError.usage(
                        "--limit expects a non-negative integer, got '\(raw)'")
                }
                options.limit = parsed
            case "--json":
                options.format = .json
            case "--human":
                options.format = .human
            case "--base2", "--iec":
                options.base = .binary
            case "--decimal":
                options.base = .decimal
            case "--verbose":
                options.verbose = true
            case "--header":
                options.header = true
            case "--no-header":
                options.header = false
            case "--clear":
                options.clearHistory = true
            case "--no-history":
                options.noHistory = true
            default:
                throw UnitWiseError.unknownFlag(argument)
            }
            index += 1
        }
        return options
    }

    /// True for forms like "-3" or "-.5" (numbers, not flags).
    static func isNegativeNumber(_ argument: String) -> Bool {
        guard argument.hasPrefix("-"), argument.count > 1 else { return false }
        let second = argument[argument.index(after: argument.startIndex)]
        return second.isNumber || second == "."
    }
}

// MARK: - UsageText

/// The short and long help screens.
public enum UsageText {

    /// One-glance usage printed when no arguments are given.
    public static let short = """
    usage: unitwise <command> [arguments]

    commands: convert, list, table, batch, history, help, version, selftest
    quick start: unitwise 5 km to mi
    run 'unitwise help' for the full manual.
    """

    /// Full manual printed by `unitwise help`.
    public static let full = """
    unitwise \(UnitWiseCLI.version) — precise unit conversion from the terminal

    usage:
      unitwise [convert] VALUE FROM to TO      one-shot conversion
      unitwise list [CATEGORY]                 categories or one unit table
      unitwise table CATEGORY [VALUE]          N×N conversion matrix
      unitwise batch --in FILE [--out FILE]    CSV in, CSV out
      unitwise history [--limit N] [--clear]   recent conversions
      unitwise help | version | selftest       meta commands

    commands:
      convert   parse an expression like "5 km to mi", "72F", "4 GB in MiB"
      list      overview of all categories, or the unit table of one
      table     every unit of a category converted against every other
      batch     convert a CSV with rows "value,from,to" or one expression
      history   show, trim (--limit), or erase (--clear) history
      selftest  run the built-in sanity checks (Core/SelfTest.swift)

    flags:
      --digits N     significant figures for results (1...15, default 6)
      --to UNIT      provide the target unit outside the expression
      --json         machine-readable output (convert, list, history)
      --base2,--iec  read loose data tokens (MB, GB...) as binary MiB-style
      --decimal      read loose data tokens as decimal MB-style (default)
      --verbose      extra detail lines and footers
      --in FILE      batch input ('-' reads standard input)
      --out FILE     batch output (default: standard output)
      --header       batch input's first row is a header; emit one back
      --no-header    batch input has no header row (default)
      --limit N      history rows to show
      --clear        erase the history file
      --no-history   convert without recording to history

    examples:
      unitwise 5 km to mi
      unitwise convert --digits 8 "3.5 MB to kB"
      unitwise temperature 72 f to c
      unitwise 0.5 c to mps              # lightspeed, not celsius
      unitwise --base2 3.5 MB to kB
      unitwise table pressure 1
      unitwise batch --in lengths.csv --header --out lengths-out.csv
      unitwise history --limit 5

    exit codes:
      0 success   1 usage error   2 conversion error
      3 partial batch failure     4 I/O error   70 internal config error

    history lives at ~/.unitwise/history.json (JSON array, newest last).
    """
}

// MARK: - UnitWiseCLI

/// The application: dispatch, command implementations, error reporting.
/// (Self-test checks themselves live in Core/SelfTest.swift.)
public enum UnitWiseCLI {

    /// Version reported by `unitwise version` and the help screen.
    public static let version = "1.0.0"

    /// Registry built once; a failure here is the documented exit-70 case.
    static let sharedResolver: UnitResolver? =
        try? UnitResolver(categories: CategoryRegistry.categories)

    /// Entry point: runs the CLI and returns the process exit code.
    public static func run(_ arguments: [String]) -> Int {
        do {
            return try dispatch(arguments)
        } catch let error as UnitWiseError {
            printError("unitwise: error: \(error)")
            if var hint = error.hint {
                if hint.hasPrefix(" — ") { hint.removeFirst(3) }
                printError("unitwise: hint: \(hint)")
            }
            return error.exitCode
        } catch {
            printError("unitwise: unexpected error: \(error)")
            return 70
        }
    }

    /// Routes the first token to a command, defaulting to `convert`.
    static func dispatch(_ arguments: [String]) throws -> Int {
        var tokens = Array(arguments.dropFirst())
        guard !tokens.isEmpty else {
            printError(UsageText.short)
            return 1
        }
        let first = tokens.removeFirst()
        guard let command = Command.resolve(first) else {
            tokens.insert(first, at: 0)
            return try runConvert(options: try Options.parse(tokens))
        }
        switch command {
        case .convert:
            return try runConvert(options: try Options.parse(tokens))
        case .list:
            return try runList(options: try Options.parse(tokens))
        case .table:
            return try runTable(options: try Options.parse(tokens))
        case .batch:
            return try runBatch(options: try Options.parse(tokens))
        case .history:
            return try runHistory(options: try Options.parse(tokens))
        case .help:
            print(UsageText.full)
            return 0
        case .version:
            print("unitwise \(version)")
            return 0
        case .selftest:
            return runSelfTest()
        }
    }

    // MARK: convert

    /// Default command: parse, evaluate, print, record.
    static func runConvert(options: Options) throws -> Int {
        let resolver = try requireResolver()
        guard !options.positional.isEmpty else {
            throw UnitWiseError.usage(
                "expected an expression, e.g. unitwise convert 5 km to mi")
        }
        let rawExpression = options.positional.joined(separator: " ")
        let expression = options.base.remapExpression(rawExpression)
        let request = try ExpressionParser.parse(expression: expression,
                                                 resolver: resolver,
                                                 toOverride: options.toOverride)
        let engine = ConversionEngine(precision: options.precision)
        let result = try engine.evaluate(request)
        let formatter = ResultFormatter(format: options.format,
                                        precision: options.precision,
                                        includeDetails: options.verbose)
        print(formatter.render(result))
        if !options.noHistory {
            let store = HistoryStore()
            try store.append(HistoryEntry.make(request: request, result: result))
        }
        return 0
    }

    // MARK: list

    /// Category overview or one category's unit table.
    static func runList(options: Options) throws -> Int {
        _ = try requireResolver()
        if options.positional.isEmpty {
            return runCategoryOverview(options: options)
        }
        let token = options.positional[0]
        guard let category = CategoryRegistry.category(matching: token) else {
            throw UnitWiseError.unknownCategory(token,
                                                suggestions: categorySuggestions(token))
        }
        if options.format == .json {
            let objects = category.units.map { unitJSON($0) }
            print("{\n  \"category\": \"\(NumberText.escape(category.id))\","
                + "\n  \"base\": \"\(NumberText.escape(category.baseUnitID))\","
                + "\n  \"units\": [\n    " + objects.joined(separator: ",\n    ")
                + "\n  ]\n}")
            return 0
        }
        let rows = category.units.map { unit -> [String] in
            [unit.symbol, unit.singular, unit.scale.readable, unit.definition ?? ""]
        }
        print("\(category.displayName) — \(category.summary) "
            + "(\(category.units.count) units, base \(category.baseUnitID))")
        print(TableFormatter.render(headers: ["symbol", "name", "per base", "definition"],
                                    rows: rows))
        if let note = category.note {
            print("note: \(note)")
        }
        return 0
    }

    /// The no-argument branch of `list`.
    static func runCategoryOverview(options: Options) -> Int {
        if options.format == .json {
            let objects = CategoryRegistry.categories.map { category -> String in
                let aliasList = NumberText.escape(category.aliases.joined(separator: ","))
                return "{ \"id\": \"\(NumberText.escape(category.id))\","
                    + " \"title\": \"\(NumberText.escape(category.displayName))\","
                    + " \"units\": \(category.units.count),"
                    + " \"aliases\": \"\(aliasList)\" }"
            }
            print("[\n" + objects.joined(separator: ",\n") + "\n]")
            return 0
        }
        print("unitwise categories (\(CategoryRegistry.categories.count))")
        for category in CategoryRegistry.categories {
            let idColumn = category.id.padding(toLength: 12, withPad: " ", startingAt: 0)
            let countColumn = String(category.units.count)
                .padding(toLength: 3, withPad: " ", startingAt: 0)
            var line = "  \(idColumn) \(countColumn)  \(category.summary)"
            if options.verbose, let note = category.note {
                line += "\n      note: \(note)"
            }
            print(line)
        }
        print("run 'unitwise list <category>' for a unit table.")
        return 0
    }

    // MARK: table

    /// N×N matrix for one category at one value.
    static func runTable(options: Options) throws -> Int {
        let resolver = try requireResolver()
        guard let first = options.positional.first else {
            throw UnitWiseError.usage(
                "table expects a category, e.g. unitwise table length 5")
        }
        guard let category = CategoryRegistry.category(matching: first) else {
            throw UnitWiseError.unknownCategory(first,
                                                suggestions: categorySuggestions(first))
        }
        var value = 1.0
        if options.positional.count > 1 {
            let raw = options.positional[1].replacingOccurrences(of: "_", with: "")
            guard let parsed = Double(raw), parsed.isFinite else {
                throw UnitWiseError.invalidNumber(options.positional[1])
            }
            value = parsed
        }
        let engine = ConversionEngine(precision: options.precision)
        let matrix = engine.matrix(category: category, value: value, units: category.units)
        let headers = ["unit"] + category.symbols
        let rows = zip(category.units, matrix).map { unit, row -> [String] in
            [unit.symbol] + row.map {
                NumberText.significant($0, figures: options.precision.significantFigures)
            }
        }
        print("\(Unit.trimNumber(value)) \(category.baseUnit?.symbol ?? "") — "
            + "\(category.displayName) conversion matrix")
        print(TableFormatter.render(headers: headers, rows: rows))
        return 0
    }

    // MARK: batch

    /// CSV in, CSV out; exit 3 when any row failed.
    static func runBatch(options: Options) throws -> Int {
        let resolver = try requireResolver()
        guard let path = options.inputPath ?? options.positional.first else {
            throw UnitWiseError.usage(
                "batch expects --in FILE (or '-' for standard input)")
        }
        let text = try BatchProcessor.readInput(at: path)
        let report = BatchProcessor.process(text,
                                            resolver: resolver,
                                            hasHeader: options.header,
                                            toOverride: options.toOverride)
        if let outputPath = options.outputPath {
            try BatchProcessor.writeOutput(report, to: outputPath)
        } else {
            print(report.csv, terminator: "")
        }
        var summary = "batch: \(report.succeeded) of \(report.total) rows converted"
        if report.failed > 0 {
            summary += ", \(report.failed) failed"
        }
        printError(summary)
        if report.failed > 0 {
            throw UnitWiseError.batchPartial(failed: report.failed, total: report.total)
        }
        return 0
    }

    // MARK: history

    /// Lists, trims, or clears the conversion history.
    static func runHistory(options: Options) throws -> Int {
        let store = HistoryStore()
        if options.clearHistory {
            try store.clear()
            print("history cleared (\(store.filePath))")
            return 0
        }
        let entries = store.load()
        if entries.isEmpty {
            print("no conversion history yet — run e.g. unitwise 5 km to mi")
            return 0
        }
        let take = options.limit ?? 20
        let shown = take <= 0 ? entries : Array(entries.suffix(take).reversed())
        if options.format == .json {
            let objects = shown.map { entry -> String in
                "{ \"timestamp\": \"\(NumberText.escape(entry.timestamp))\","
                    + " \"expression\": \"\(NumberText.escape(entry.expression))\","
                    + " \"category\": \"\(NumberText.escape(entry.category))\","
                    + " \"input\": \(NumberText.jsonNumber(entry.inputValue)),"
                    + " \"from\": \"\(NumberText.escape(entry.fromSymbol))\","
                    + " \"to\": \"\(NumberText.escape(entry.toSymbol))\","
                    + " \"result\": \(NumberText.jsonNumber(entry.result)),"
                    + " \"exact\": \(entry.exact) }"
            }
            print("[\n" + objects.joined(separator: ",\n") + "\n]")
            return 0
        }
        let rows = shown.map { entry -> [String] in
            [entry.timestamp,
             entry.category,
             entry.expression,
             "\(Unit.trimNumber(entry.result)) \(entry.toSymbol)"]
        }
        print(TableFormatter.render(headers: ["when", "category", "expression", "result"],
                                    rows: rows))
        if options.verbose {
            print(store.describe())
        }
        return 0
    }

    // MARK: selftest

    /// Runs the built-in checks; exit 0 only when every check passes.
    static func runSelfTest() -> Int {
        let checks = SelfTest.runAll()
        for check in checks where !check.passed {
            printError("FAIL \(check.name): \(check.detail)")
        }
        let failed = checks.filter { !$0.passed }.count
        print("\(checks.count - failed)/\(checks.count) self-checks passed")
        return failed == 0 ? 0 : 1
    }

    // MARK: Shared helpers

    /// Resolver accessor with the internal-error translation.
    static func requireResolver() throws -> UnitResolver {
        guard let resolver = sharedResolver else {
            throw UnitWiseError.config("category registry failed to build")
        }
        return resolver
    }

    /// Levenshtein suggestions over the category vocabulary.
    static func categorySuggestions(_ token: String) -> [String] {
        let target = token.lowercased()
        guard !target.isEmpty else { return [] }
        var scored: [(token: String, distance: Int)] = []
        for candidate in CategoryRegistry.categoryVocabulary {
            let distance = ExpressionParser.levenshtein(target, candidate)
            if distance <= max(1, target.count / 2) {
                scored.append((candidate, distance))
            }
        }
        return scored.sorted {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            return $0.token < $1.token
        }.prefix(3).map { $0.token }
    }

    /// One unit as a JSON object string (used by `list <category> --json`).
    static func unitJSON(_ unit: Unit) -> String {
        let factor = unit.scale.linearFactor.map { NumberText.jsonNumber($0) } ?? "null"
        var offset = "null"
        if case .affine(_, let shift) = unit.scale {
            offset = NumberText.jsonNumber(shift)
        }
        let aliasList = unit.allAliases
            .map { "\"\(NumberText.escape($0))\"" }
            .joined(separator: ", ")
        return "{ \"id\": \"\(NumberText.escape(unit.id))\","
            + " \"symbol\": \"\(NumberText.escape(unit.symbol))\","
            + " \"name\": \"\(NumberText.escape(unit.singular))\","
            + " \"factor\": \(factor), \"offset\": \(offset),"
            + " \"aliases\": [\(aliasList)] }"
    }

    /// Writes one line to standard error without buffering surprises.
    static func printError(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}

// MARK: - Bootstrap

// Entry point: run the CLI and exit with its status code.
let unitwiseExitCode = UnitWiseCLI.run(CommandLine.arguments)
exit(Int32(unitwiseExitCode))
