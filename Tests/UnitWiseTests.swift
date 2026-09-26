//
//  UnitWiseTests.swift
//  unitwise
//
//  Primary XCTest suite exercising the public pipeline:
//    * registry invariants (ten categories, resolver validation),
//    * the Unit model (linear/affine scales, alias deduplication),
//    * temperature offsets (affine scales through kelvin),
//    * binary vs decimal data sizes and the --base2 token remap,
//    * parser aliases, plural stripping, µ normalization, anchoring.
//
//  Round trips, the newer category factors, formatters, batch, history,
//  and CLI plumbing live in IntegrationTests.swift. The file also ships
//  `PlainSelfTestRunner`, a non-XCTest entry point so the package can be
//  smoke-tested on systems without a usable XCTest.
//

import XCTest
import Foundation
import UnitWise

// MARK: - Shared helpers

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

// MARK: - PlainSelfTestRunner

/// Non-XCTest smoke runner: returns true when every built-in check passes.
public enum PlainSelfTestRunner {

    /// Runs the module self-test and reports pass/fail.
    public static func allPassed() -> Bool {
        SelfTest.runAll().allSatisfy { $0.passed }
    }

    /// The raw checks, for custom reporting.
    public static func checks() -> [SelfTest.Check] {
        SelfTest.runAll()
    }
}

// MARK: - Registry tests

public final class RegistryTests: XCTestCase {

    func testAllTenCategoriesInOrder() {
        let ids = CategoryRegistry.categories.map { $0.id }
        XCTAssertEqual(ids, ["length", "mass", "temperature", "volume",
                             "speed", "datasize", "time", "energy",
                             "pressure", "area"])
    }

    func testEveryCategoryDeclaresAnExistingBaseUnit() {
        for category in CategoryRegistry.categories {
            XCTAssertNotNil(category.baseUnit,
                            "\(category.id) is missing base \(category.baseUnitID)")
        }
    }

    func testResolverValidatesProductionRegistry() {
        XCTAssertNoThrow(try makeResolver())
    }

    func testResolverRejectsDuplicateUnitIDs() {
        let duplicate = Unit.linear(categoryID: "length",
                                    id: "meter",
                                    symbol: "m-dup",
                                    singular: "meter clone",
                                    factor: 1)
        let broken = Category(id: "length",
                              displayName: "Length",
                              summary: "broken on purpose",
                              baseUnitID: "meter",
                              units: [duplicate, duplicate])
        XCTAssertThrowsError(try UnitResolver(categories: [broken]))
    }

    func testCategoryAliasesResolve() throws {
        let resolver = try makeResolver()
        XCTAssertNotNil(CategoryRegistry.category(matching: "weight"))
        XCTAssertNotNil(CategoryRegistry.category(matching: "temp"))
        XCTAssertNotNil(resolver.category(withID: "datasize"))
        XCTAssertNil(CategoryRegistry.category(matching: "nonsense"))
    }
}

// MARK: - Unit model tests

public final class UnitModelTests: XCTestCase {

    func testLinearScaleMapsBothDirections() {
        let unit = Unit.linear(categoryID: "length",
                               id: "km-test",
                               symbol: "km~",
                               singular: "kilometer test",
                               factor: 1000)
        XCTAssertEqual(unit.scale.toBase(2.5), 2500, accuracy: 1e-12)
        XCTAssertEqual(unit.scale.fromBase(2500), 2.5, accuracy: 1e-12)
        XCTAssertTrue(unit.isLinear)
        XCTAssertFalse(unit.scale.isAffine)
    }

    func testAffineScaleAppliesOffsetInBaseSpace() {
        let unit = Unit.affine(categoryID: "temperature",
                               id: "c-test",
                               symbol: "°C~",
                               singular: "celsius test",
                               scale: 1,
                               offset: 273.15)
        XCTAssertEqual(unit.scale.toBase(0), 273.15, accuracy: 1e-12)
        XCTAssertEqual(unit.scale.fromBase(273.15), 0, accuracy: 1e-12)
        XCTAssertFalse(unit.isLinear)
        XCTAssertTrue(unit.scale.isAffine)
    }

    func testAliasesDeduplicateAndDropEmpties() {
        let unit = Unit.linear(categoryID: "test",
                               id: "u",
                               symbol: "s",
                               singular: "unit",
                               factor: 1,
                               aliases: ["s", "alt", "alt", ""])
        XCTAssertEqual(unit.allAliases, ["s", "unit", "units", "alt"])
    }

    func testIncompatibleUnitsAreNotConvertible() {
        let meter = Unit.linear(categoryID: "length", id: "m", symbol: "m",
                                singular: "meter", factor: 1)
        let gram = Unit.linear(categoryID: "mass", id: "g", symbol: "g",
                               singular: "gram", factor: 1)
        XCTAssertNil(meter.convert(1, to: gram))
        XCTAssertFalse(meter.isCompatible(with: gram))
    }
}

// MARK: - Temperature tests

public final class TemperatureTests: XCTestCase {

    private func evaluate(_ expression: String) throws -> ConversionResult {
        let resolver = try makeResolver()
        let request = try ExpressionParser.parse(expression: expression,
                                                 resolver: resolver)
        return try ConversionEngine().evaluate(request)
    }

    func testCelsiusToKelvinAnchors() throws {
        XCTAssertEqual(try evaluate("0 c to k").result, 273.15, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("100 c to k").result, 373.15, accuracy: 1e-9)
    }

    func testFahrenheitAnchors() throws {
        XCTAssertEqual(try evaluate("32 f to c").result, 0, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("212 f to c").result, 100, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("-40 f to c").result, -40, accuracy: 1e-9)
    }

    func testKelvinToFahrenheit() throws {
        XCTAssertEqual(try evaluate("0 k to f").result, -459.67, accuracy: 1e-9)
    }

    func testCelsiusFreezingAcrossEveryScale() throws {
        XCTAssertEqual(try evaluate("0 c to r").result, 491.67, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("0 c to de").result, 150, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("0 c to n").result, 0, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("0 c to re").result, 0, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("0 c to ro").result, 7.5, accuracy: 1e-9)
    }

    func testTemperatureRoundTripPreservesValue() throws {
        let result = try evaluate("23.5 c to f")
        XCTAssertTrue(result.exact)
        XCTAssertEqual(result.roundTrip, 23.5, accuracy: 1e-9)
        let back = try evaluate("76.1 f to c")
        XCTAssertEqual(back.result, 24.5, accuracy: 1e-9)
    }
}

// MARK: - Data size tests

public final class DataSizeTests: XCTestCase {

    private func evaluate(_ expression: String) throws -> ConversionResult {
        let resolver = try makeResolver()
        let request = try ExpressionParser.parse(expression: expression,
                                                 resolver: resolver)
        return try ConversionEngine().evaluate(request)
    }

    func testDecimalKilobyteIsExactly1000Bytes() throws {
        XCTAssertEqual(try evaluate("1 kb to byte").result, 1000, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 mb to kb").result, 1000, accuracy: 1e-9)
    }

    func testBinaryKibibyteIsExactly1024Bytes() throws {
        XCTAssertEqual(try evaluate("1 kib to byte").result, 1024, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 gib to mib").result, 1024, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("1 gib to byte").result, 1073741824, accuracy: 1e-6)
    }

    func testBitsAreOneEighthOfBytes() throws {
        XCTAssertEqual(try evaluate("8 b to byte").result, 1, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("1 megabit to byte").result, 125000, accuracy: 1e-6)
    }

    func testBase2RemapRewritesOnlyLooseTokens() {
        let remapped = DataSizeBase.binary.remapExpression("3.5 MB to kB")
        XCTAssertEqual(remapped, "3.5 MiB to kB")
        let untouched = DataSizeBase.binary.remapExpression("5 km to mi")
        XCTAssertEqual(untouched, "5 km to mi")
        let decimal = DataSizeBase.decimal.remapExpression("3.5 MB to kB")
        XCTAssertEqual(decimal, "3.5 MB to kB")
    }

    func testBase2ConversionEndToEnd() throws {
        let remapped = DataSizeBase.binary.remapExpression("3.5 mb to kb")
        XCTAssertEqual(try evaluate(remapped).result, 3670.016, accuracy: 1e-9)
    }

    func testHumanBytesLadder() {
        XCTAssertEqual(DataSizeBase.humanBytes(0), "0 B")
        XCTAssertEqual(DataSizeBase.humanBytes(1536, base: .binary), "1.50 KiB")
        XCTAssertEqual(DataSizeBase.humanBytes(2000), "2.00 kB")
        XCTAssertEqual(DataSizeBase.humanBytes(1.5e9), "1.50 GB")
        XCTAssertEqual(DataSizeBase.humanBytes(2.5 * 1048576.0, base: .binary), "2.50 MiB")
    }
}

// MARK: - Parser tests

public final class ParserTests: XCTestCase {

    private func evaluate(_ expression: String,
                          toOverride: String? = nil) throws -> ConversionResult {
        let resolver = try makeResolver()
        let request = try ExpressionParser.parse(expression: expression,
                                                 resolver: resolver,
                                                 toOverride: toOverride)
        return try ConversionEngine().evaluate(request)
    }

    func testCaseInsensitiveAliases() throws {
        let lowered = try evaluate("5 km to mi")
        let upper = try evaluate("5 KM TO MI")
        XCTAssertEqual(lowered.result, upper.result, accuracy: 1e-12)
        XCTAssertEqual(upper.result, 3.1068559611866697, accuracy: 1e-9)
    }

    func testPluralStrippingResolvesKms() throws {
        let resolver = try makeResolver()
        let candidates = resolver.candidates(for: "kms")
        XCTAssertEqual(candidates.first?.id, "kilometer")
        XCTAssertEqual(try evaluate("3 kms to mi").result,
                       try evaluate("3 km to mi").result, accuracy: 1e-12)
    }

    func testMicroNormalization() throws {
        XCTAssertEqual(ExpressionParser.normalizeToken("µs"), "us")
        XCTAssertEqual(try evaluate("5 us to ms").result, 0.005, accuracy: 1e-12)
    }

    func testArrowSeparatorWithoutSpaces() throws {
        XCTAssertEqual(try evaluate("5km->mi").result,
                       try evaluate("5 km to mi").result, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("5km=>mi").result,
                       try evaluate("5 km to mi").result, accuracy: 1e-12)
    }

    func testInSeparatorAfterSourceUnit() throws {
        XCTAssertEqual(try evaluate("4 GB in MiB").result, 3814.697265625, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("3 in to cm").result, 7.62, accuracy: 1e-9)
    }

    func testCategoryPrefixScopesResolution() throws {
        XCTAssertEqual(try evaluate("temperature 72 f to c").result,
                       22.22222222222222, accuracy: 1e-9)
    }

    func testAmbiguousTokensAnchorAcrossSides() throws {
        XCTAssertEqual(try evaluate("72 f to c").result, 22.22222222222222, accuracy: 1e-9)
        XCTAssertEqual(try evaluate("0.5 c to mps").result, 149896229, accuracy: 1e-6)
    }

    func testToOverrideMatchesInlineTarget() throws {
        XCTAssertEqual(try evaluate("5 km to mi", toOverride: "mi").result,
                       3.1068559611866697, accuracy: 1e-9)
    }

    func testConflictingTargetsThrow() {
        XCTAssertThrowsError(try evaluate("5 km to mi", toOverride: "m")) { error in
            guard case UnitWiseError.conflictingTargets = error else {
                return XCTFail("expected conflictingTargets, got \(error)")
            }
        }
    }

    func testMissingTargetThrows() {
        XCTAssertThrowsError(try evaluate("5 km")) { error in
            guard case UnitWiseError.missingTarget = error else {
                return XCTFail("expected missingTarget, got \(error)")
            }
        }
    }

    func testUnknownUnitCarriesSuggestions() {
        do {
            _ = try evaluate("5 kilmeter to mi")
            XCTFail("expected unknownUnit")
        } catch let error as UnitWiseError {
            guard case .unknownUnit(_, let suggestions) = error else {
                return XCTFail("expected unknownUnit, got \(error)")
            }
            XCTAssertTrue(suggestions.contains("kilometer"))
        } catch {
            XCTFail("unexpected error type \(error)")
        }
    }

    func testCategoryMismatchThrows() {
        XCTAssertThrowsError(try evaluate("5 km to kg")) { error in
            guard case UnitWiseError.categoryMismatch = error else {
                return XCTFail("expected categoryMismatch, got \(error)")
            }
        }
    }

    func testParseErrorsReportOffsets() {
        do {
            let resolver = try makeResolver()
            _ = try ExpressionParser.parse(expression: "5 km $ mi", resolver: resolver)
            XCTFail("expected a parse error")
        } catch let error as UnitWiseError {
            guard case .parse(_, let offset) = error else {
                return XCTFail("expected parse error, got \(error)")
            }
            XCTAssertNotNil(offset)
        } catch {
            XCTFail("unexpected error type \(error)")
        }
    }

    func testLevenshteinBasics() {
        XCTAssertEqual(ExpressionParser.levenshtein("km", "km"), 0)
        XCTAssertEqual(ExpressionParser.levenshtein("kms", "km"), 1)
        XCTAssertEqual(ExpressionParser.levenshtein("abc", "yde"), 3)
    }
}
