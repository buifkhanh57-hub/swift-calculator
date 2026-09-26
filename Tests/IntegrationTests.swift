//
//  IntegrationTests.swift
//  unitwise
//
//  Second half of the XCTest suite, covering the layers that sit on top of
//  the parser and engine:
//    * round trips, inversion, and the N×N matrix diagonal,
//    * energy / pressure / area factors and their helper functions,
//    * formatter output (significant figures, human, JSON, tables),
//    * CSV parsing and batch reports,
//    * history persistence against a temporary directory,
//    * CLI plumbing (command aliases, flag parsing, exit codes),
//    * the bridge to the module self-test.
//

import XCTest
import Foundation
import UnitWise

// MARK: - Shared helpers (file-local)

/// Builds the production resolver for every test.
private func makeResolver() throws -> UnitResolver {
    try UnitResolver(categories: CategoryRegistry.categories)
}

/// Relative floating-point comparison used across the numeric anchors.
private func approx(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
    guard lhs.isFinite, rhs.isFinite else { return false }
    if lhs == rhs { return true }
    return abs(lhs - rhs) <= tolerance * max(abs(lhs), abs(rhs))
}

// MARK: - Round trip tests

public final class RoundTripTests: XCTestCase {

    private func evaluate(_ expression: String) throws -> ConversionResult {
        let resolver = try makeResolver()
        let request = try ExpressionParser.parse(expression: expression,
                                                 resolver: resolver)
        return try ConversionEngine().evaluate(request)
    }

    func testLengthRoundTripIsExact() throws {
        let result = try evaluate("5 km to mi")
        XCTAssertTrue(result.exact)
        XCTAssertEqual(result.baseValue, 5000, accuracy: 1e-9)
        XCTAssertEqual(result.roundTrip, 5, accuracy: 1e-9)
    }

    func testInvertedResultFlowsBackToSource() throws {
        let result = try evaluate("5 km to mi")
        let inverted = result.inverted()
        XCTAssertEqual(inverted.result, 5, accuracy: 1e-9)
        XCTAssertEqual(inverted.request.from.symbol, "mi")
        XCTAssertEqual(inverted.request.to.symbol, "km")
    }

    func testMassRoundTripThroughGrams() throws {
        let result = try evaluate("2.5 kg to g")
        XCTAssertEqual(result.result, 2500, accuracy: 1e-9)
        XCTAssertEqual(result.roundTrip, 2.5, accuracy: 1e-9)
        XCTAssertTrue(result.exact)
    }

    func testMatrixDiagonalEqualsInputValue() throws {
        let resolver = try makeResolver()
        let category = resolver.category(withID: "length")!
        let engine = ConversionEngine()
        let matrix = engine.matrix(category: category, value: 7, units: category.units)
        for (index, row) in matrix.enumerated() {
            XCTAssertEqual(row[index], 7, accuracy: 1e-9)
        }
        XCTAssertEqual(matrix.count, category.units.count)
    }
}

// MARK: - New category factor tests

public final class CategoryFactorTests: XCTestCase {

    private func evaluate(_ expression: String) throws -> ConversionResult {
        let resolver = try makeResolver()
        let request = try ExpressionParser.parse(expression: expression,
                                                 resolver: resolver)
        return try ConversionEngine().evaluate(request)
    }

    func testEnergyAnchors() throws {
        XCTAssertEqual(try evaluate("1 kcal to j").result, 4184, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 kwh to j").result, 3.6e6, accuracy: 1e-6)
        XCTAssertEqual(try evaluate("1 btu to j").result, 1055.05585262, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 ftlb to j").result,
                       1.3558179483314004, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 kcal to cal").result, 1000, accuracy: 1e-9)
    }

    func testEnergyHelpersMatchEngine() {
        XCTAssertTrue(approx(EnergyCategory.kilocaloriesToJoules(2), 8368))
        XCTAssertTrue(approx(EnergyCategory.joulesToKilocalories(4184), 1))
        XCTAssertTrue(approx(EnergyCategory.kilowattHoursToJoules(1), 3.6e6))
    }

    func testPressureAnchors() throws {
        XCTAssertEqual(try evaluate("1 bar to pa").result, 1e5, accuracy: 1e-6)
        XCTAssertEqual(try evaluate("1 atm to pa").result, 101325, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("760 torr to pa").result, 101325, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 psi to pa").result,
                       6894.757293168361, accuracy: 1e-6)
        XCTAssertEqual(try evaluate("1 bar to mbar").result, 1000, accuracy: 1e-9)
    }

    func testPressureHelpersMatchEngine() {
        XCTAssertTrue(approx(PressureCategory.psiToBar(1), 0.06894757293168361))
        XCTAssertTrue(approx(PressureCategory.psiToBar(10),
                             10.0 * 6894.757293168361 / 1e5))
        XCTAssertTrue(approx(PressureCategory.inchesMercuryToHectopascals(1),
                             25.4 * 133.322387415 / 100))
    }

    func testAreaAnchors() throws {
        XCTAssertEqual(try evaluate("1 ha to m2").result, 10000, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 acre to m2").result,
                       4046.8564224, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 sqmi to sqft").result, 27878400, accuracy: 1e-3)
        XCTAssertEqual(try evaluate("1 acre to sqft").result, 43560, accuracy: 1e-6)
    }

    func testAreaASCIIAliasesResolve() throws {
        let resolver = try makeResolver()
        XCTAssertEqual(resolver.candidates(for: "m2").first?.id, "squaremeter")
        XCTAssertEqual(resolver.candidates(for: "sqft").first?.id, "squarefoot")
        XCTAssertEqual(resolver.candidates(for: "sqmi").first?.id, "squaremile")
        XCTAssertEqual(resolver.candidates(for: "ha").first?.id, "hectare")
    }

    func testAreaHelpersMatchEngine() {
        XCTAssertTrue(approx(AreaCategory.acresToHectares(1), 0.40468564224))
        XCTAssertTrue(approx(AreaCategory.squareFeetToAcres(43560), 1))
    }
}

// MARK: - Formatter tests

public final class FormatterTests: XCTestCase {

    private func evaluate(_ expression: String) throws -> ConversionResult {
        let resolver = try makeResolver()
        let request = try ExpressionParser.parse(expression: expression,
                                                 resolver: resolver)
        return try ConversionEngine().evaluate(request)
    }

    func testSignificantFigures() {
        XCTAssertEqual(NumberText.significant(3.1068559611866697, figures: 6), "3.10686")
        XCTAssertEqual(NumberText.significant(123456789, figures: 6), "123457000")
        XCTAssertEqual(NumberText.significant(0.00064516, figures: 6), "0.000645160")
        XCTAssertEqual(NumberText.significant(0, figures: 4), "0")
        XCTAssertEqual(NumberText.significant(1e15, figures: 4), "1.000e+15")
        XCTAssertEqual(NumberText.significant(273.15, figures: 6), "273.150")
    }

    func testJSONNumberAndEscape() {
        XCTAssertEqual(NumberText.jsonNumber(5.0), "5.0")
        XCTAssertEqual(NumberText.jsonNumber(0.001), "0.001")
        XCTAssertEqual(NumberText.jsonNumber(.infinity), "null")
        XCTAssertEqual(NumberText.escape("a\"b\\c\nd"), "a\\\"b\\\\c\\nd")
    }

    func testHumanRendering() throws {
        let result = try evaluate("5 km to mi")
        let formatter = ResultFormatter(format: .human,
                                        precision: PrecisionRules(significantFigures: 6))
        XCTAssertEqual(formatter.render(result), "5 km = 3.10686 mi")
    }

    func testVerboseHumanRenderingAddsDetailLine() throws {
        let result = try evaluate("5 km to mi")
        let formatter = ResultFormatter(format: .human,
                                        precision: PrecisionRules(),
                                        includeDetails: true)
        let rendered = formatter.render(result)
        XCTAssertTrue(rendered.contains("via m: 5000"))
        XCTAssertTrue(rendered.contains("round-trip 5 km"))
        XCTAssertTrue(rendered.contains("exact"))
    }

    func testJSONRenderingIsWellFormed() throws {
        let result = try evaluate("3.5 mb to kb")
        let rendered = ResultFormatter(format: .json).render(result)
        XCTAssertTrue(rendered.hasPrefix("{"))
        XCTAssertTrue(rendered.contains("\"exact\": true"))
        XCTAssertTrue(rendered.contains("\"unit\": \"kB\""))
        XCTAssertTrue(rendered.contains("\"value\": 3500.0"))
        let data = rendered.data(using: .utf8) ?? Data()
        let object = try? JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertNotNil(object)
    }

    func testTableFormatterAlignsColumns() {
        let rendered = TableFormatter.render(headers: ["a", "bb"],
                                             rows: [["1", "2"], ["xxx", "y"]])
        let lines = rendered.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(Set(lines.map { $0.count }).count, 1)
        XCTAssertTrue(lines[0].hasPrefix("a"))
        XCTAssertTrue(lines[1].contains("---"))
    }

    func testOutputFormatParsing() {
        XCTAssertEqual(OutputFormat.parse("json"), .json)
        XCTAssertEqual(OutputFormat.parse("TEXT"), .human)
        XCTAssertNil(OutputFormat.parse("yaml"))
    }
}

// MARK: - Batch tests

public final class BatchTests: XCTestCase {

    private var resolver: UnitResolver {
        // Registry invariants are covered elsewhere; safe to force here.
        (try? makeResolver())!
    }

    func testCSVParseQuotesAndCRLF() {
        let grid = BatchProcessor.parseCSV("a,\"b,c\"\r\nd,\"e\"\"f\",g\n")
        XCTAssertEqual(grid, [["a", "b,c"], ["d", "e\"f", "g"]])
    }

    func testCSVParseTrailingNewlineProducesNoEmptyRow() {
        let grid = BatchProcessor.parseCSV("1,2,3\n")
        XCTAssertEqual(grid, [["1", "2", "3"]])
    }

    func testCSVEscapeWrapsSpecials() {
        XCTAssertEqual(BatchProcessor.escapeCSV("plain"), "plain")
        XCTAssertEqual(BatchProcessor.escapeCSV("a,b"), "\"a,b\"")
        XCTAssertEqual(BatchProcessor.escapeCSV("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testBatchThreeColumnRows() {
        let report = BatchProcessor.process("5,km,mi\n10,kg,g\n",
                                            resolver: resolver,
                                            hasHeader: false)
        XCTAssertEqual(report.total, 2)
        XCTAssertEqual(report.succeeded, 2)
        XCTAssertEqual(report.failed, 0)
        XCTAssertTrue(report.csv.contains("3.10685596119"))
        XCTAssertTrue(report.csv.contains("10000"))
        XCTAssertFalse(report.csv.hasPrefix("line"))
    }

    func testBatchHeaderModeEmitsHeader() {
        let report = BatchProcessor.process("value,from,to\n5,km,mi\n",
                                            resolver: resolver,
                                            hasHeader: true)
        XCTAssertEqual(report.succeeded, 1)
        XCTAssertTrue(report.csv.hasPrefix("line,input,from,to,result,status,error"))
    }

    func testBatchSingleColumnExpressions() {
        let report = BatchProcessor.process("5 km to mi\n2.5 kg to g\n",
                                            resolver: resolver,
                                            hasHeader: false)
        XCTAssertEqual(report.succeeded, 2)
        XCTAssertEqual(report.failed, 0)
    }

    func testBatchCollectsRowFailures() {
        let report = BatchProcessor.process("5,km,mi\n1,km,lol\n5,km,kg\n",
                                            resolver: resolver,
                                            hasHeader: false)
        XCTAssertEqual(report.total, 3)
        XCTAssertEqual(report.failed, 2)
        XCTAssertTrue(report.csv.contains("error"))
        XCTAssertTrue(report.csv.contains("different measurement categories")
            || report.csv.contains("unknown unit"))
    }

    func testBatchSkipsBlankLines() {
        let report = BatchProcessor.process("5,km,mi\n\n\n10,kg,g\n",
                                            resolver: resolver,
                                            hasHeader: false)
        XCTAssertEqual(report.total, 2)
    }

    func testBatchPartialExitCodeContract() {
        let error = UnitWiseError.batchPartial(failed: 2, total: 5)
        XCTAssertEqual(error.exitCode, 3)
    }
}

// MARK: - History tests

public final class HistoryTests: XCTestCase {

    private func temporaryDirectory() -> String {
        NSTemporaryDirectory() + "unitwise-tests-\(UUID().uuidString)"
    }

    func testAppendLoadAndClearRoundTrip() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let store = HistoryStore(directory: directory, limit: 10)
        XCTAssertEqual(store.load().count, 0)

        try store.append(HistoryEntry.make(expression: "5 km to mi",
                                           category: "length",
                                           inputValue: 5,
                                           fromSymbol: "km",
                                           toSymbol: "mi",
                                           result: 3.1068559611866697,
                                           exact: true))
        try store.append(HistoryEntry.make(expression: "1 g to kg",
                                           category: "mass",
                                           inputValue: 1,
                                           fromSymbol: "g",
                                           toSymbol: "kg",
                                           result: 0.001,
                                           exact: true))
        XCTAssertEqual(store.load().count, 2)
        XCTAssertEqual(store.recent(1).count, 1)
        XCTAssertEqual(store.recent(1).first?.expression, "1 g to kg")
        XCTAssertEqual(store.load().last?.category, "mass")

        try store.clear()
        XCTAssertEqual(store.load().count, 0)
    }

    func testLimitTrimsOldestEntries() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let store = HistoryStore(directory: directory, limit: 3)
        for index in 1...6 {
            try store.append(HistoryEntry.make(expression: "e\(index)",
                                               category: "length",
                                               inputValue: Double(index),
                                               fromSymbol: "km",
                                               toSymbol: "mi",
                                               result: Double(index),
                                               exact: true))
        }
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded.first?.expression, "e4")
        XCTAssertEqual(loaded.last?.expression, "e6")
    }

    func testCorruptHistoryFileLoadsEmpty() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        try FileManager.default.createDirectory(atPath: directory,
                                                withIntermediateDirectories: true)
        try "this is not json".write(toFile: directory + "/history.json",
                                     atomically: true,
                                     encoding: .utf8)
        let store = HistoryStore(directory: directory)
        XCTAssertEqual(store.load().count, 0)
    }

    func testEntryDictionaryDecodesSymmetrically() {
        let entry = HistoryEntry.make(expression: "2 m to ft",
                                      category: "length",
                                      inputValue: 2,
                                      fromSymbol: "m",
                                      toSymbol: "ft",
                                      result: 6.561679790026247,
                                      exact: true)
        XCTAssertEqual(HistoryEntry.decode(entry.dictionary), entry)
        XCTAssertNil(HistoryEntry.decode(["expression": "incomplete"]))
    }

    func testMakeFromRequestCarriesFields() throws {
        let resolver = try makeResolver()
        let request = try ExpressionParser.parse(expression: "5 km to mi",
                                                 resolver: resolver)
        let result = try ConversionEngine().evaluate(request)
        let entry = HistoryEntry.make(request: request, result: result)
        XCTAssertEqual(entry.expression, "5 km to mi")
        XCTAssertEqual(entry.category, "length")
        XCTAssertEqual(entry.fromSymbol, "km")
        XCTAssertEqual(entry.toSymbol, "mi")
        XCTAssertTrue(approx(entry.result, result.result))
        XCTAssertEqual(entry.timestamp.count, 20)
    }
}

// MARK: - CLI plumbing tests

public final class CLIPlumbingTests: XCTestCase {

    func testCommandResolutionAndAliases() {
        XCTAssertEqual(Command.resolve("convert"), .convert)
        XCTAssertEqual(Command.resolve("ls"), .list)
        XCTAssertEqual(Command.resolve("-h"), .help)
        XCTAssertEqual(Command.resolve("--version"), .version)
        XCTAssertEqual(Command.resolve("self-check"), .selftest)
        XCTAssertNil(Command.resolve("frobnicate"))
    }

    func testOptionsParseFlagsAndValues() throws {
        let options = try Options.parse(["--json", "--digits=8", "--to", "mi",
                                         "--base2", "5", "km"])
        XCTAssertEqual(options.format, .json)
        XCTAssertEqual(options.precision.significantFigures, 8)
        XCTAssertEqual(options.toOverride, "mi")
        XCTAssertEqual(options.base, .binary)
        XCTAssertEqual(options.positional, ["5", "km"])
    }

    func testOptionsTreatNegativeNumbersAsPositional() throws {
        let options = try Options.parse(["-3", "km", "to", "mi"])
        XCTAssertEqual(options.positional.first, "-3")
    }

    func testOptionsRejectUnknownFlagAndBadDigits() {
        XCTAssertThrowsError(try Options.parse(["--nope"]))
        XCTAssertThrowsError(try Options.parse(["--digits", "99"]))
        XCTAssertThrowsError(try Options.parse(["--digits"]))
        XCTAssertThrowsError(try Options.parse(["--to"]))
    }

    func testErrorExitCodes() {
        XCTAssertEqual(UnitWiseError.usage("x").exitCode, 1)
        XCTAssertEqual(UnitWiseError.unknownFlag("--x").exitCode, 1)
        XCTAssertEqual(UnitWiseError.unknownUnit("xx", suggestions: []).exitCode, 2)
        XCTAssertEqual(UnitWiseError.invalidNumber("x").exitCode, 2)
        XCTAssertEqual(UnitWiseError.batchPartial(failed: 1, total: 2).exitCode, 3)
        XCTAssertEqual(UnitWiseError.io("x").exitCode, 4)
        XCTAssertEqual(UnitWiseError.config("x").exitCode, 70)
    }

    func testErrorHintsExistForCommonCases() {
        XCTAssertNotNil(UnitWiseError.missingTarget.hint)
        XCTAssertNotNil(UnitWiseError.unknownFlag("--x").hint)
        XCTAssertNotNil(UnitWiseError.categoryMismatch(from: "a", to: "b").hint)
    }
}

// MARK: - Self-test bridge

public final class SelfTestBridgeTests: XCTestCase {

    func testModuleSelfTestFullyPasses() {
        let checks = SelfTest.runAll()
        XCTAssertFalse(checks.isEmpty)
        for check in checks {
            XCTAssertTrue(check.passed, "\(check.name): \(check.detail)")
        }
        XCTAssertTrue(SelfTest.allPassed(checks))
        XCTAssertTrue(PlainSelfTestRunner.allPassed())
    }
}
