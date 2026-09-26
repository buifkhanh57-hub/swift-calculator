//
//  Converter.swift
//  unitwise
//
//  The conversion engine: precision policy, canonical-factor evaluation,
//  round-trip exactness checks, and the N×N matrices behind `unitwise table`.
//
//  All math goes through the base unit:
//
//      result = to.scale.fromBase(from.scale.toBase(value))
//
//  which keeps every category consistent — including affine temperature
//  scales, where the offset must be applied in base (kelvin) space.
//

import Foundation

// MARK: - PrecisionRules

/// Output precision policy: how many significant figures to render.
public struct PrecisionRules: Equatable {

    /// Default significant-figure count for human output.
    public static let defaultFigures = 6

    /// Allowed range for the `--digits` flag.
    public static let allowedRange: ClosedRange<Int> = 1...15

    /// Significant figures used when formatting values.
    public let significantFigures: Int

    /// Creates rules; callers validate the range via `isValid` first.
    public init(significantFigures: Int = PrecisionRules.defaultFigures) {
        self.significantFigures = significantFigures
    }

    /// Whether the figure count is inside the accepted range.
    public var isValid: Bool {
        PrecisionRules.allowedRange.contains(significantFigures)
    }
}

// MARK: - ConversionResult

/// The outcome of one evaluated conversion, including round-trip metadata.
public struct ConversionResult: Equatable {

    /// The request that produced this result.
    public let request: ConversionRequest
    /// Intermediate value in the category's base unit.
    public let baseValue: Double
    /// Final converted value.
    public let result: Double
    /// Value after converting result back to the source unit.
    public let roundTrip: Double
    /// True when the round trip reproduces the input within 1e-9 relative.
    public let exact: Bool

    /// The same conversion run in the opposite direction.
    public func inverted() -> ConversionResult {
        let request = ConversionRequest(value: result,
                                        from: self.request.to,
                                        to: self.request.from,
                                        category: self.request.category,
                                        expression: self.request.expression + " (inverted)")
        let base = request.from.scale.toBase(request.value)
        let output = request.to.scale.fromBase(base)
        let back = request.from.scale.fromBase(request.to.scale.toBase(output))
        return ConversionResult(request: request,
                                baseValue: base,
                                result: output,
                                roundTrip: back,
                                exact: ConversionEngine.isRoundTripStable(original: request.value,
                                                                          returned: back))
    }
}

// MARK: - ConversionEngine

/// Evaluates conversion requests and builds conversion tables.
public struct ConversionEngine {

    /// Precision used when formatting results.
    public let precision: PrecisionRules

    /// Creates an engine with the given precision policy.
    public init(precision: PrecisionRules = PrecisionRules()) {
        self.precision = precision
    }

    // MARK: Core math

    /// Pure canonical-factor conversion between two same-category units.
    ///
    ///     base   = from.scale.toBase(value)
    ///     result = to.scale.fromBase(base)
    ///
    /// For affine scales this correctly applies the offset in base space,
    /// which is what makes temperature conversions exact.
    public static func convert(_ value: Double, from: Unit, to: Unit) -> Double {
        to.scale.fromBase(from.scale.toBase(value))
    }

    /// Relative round-trip tolerance for the `exact` flag.
    static let roundTripTolerance = 1e-9

    /// True when converting `returned` back reproduces `original` within
    /// tolerance (absolute for zero, relative otherwise).
    public static func isRoundTripStable(original: Double, returned: Double) -> Bool {
        guard original.isFinite, returned.isFinite else { return false }
        if original == 0 {
            return abs(returned) <= 1e-12
        }
        return abs(original - returned) / abs(original) <= roundTripTolerance
    }

    // MARK: Evaluation

    /// Evaluates a parsed request into a full result.
    ///
    /// Throws `invalidNumber` for non-finite input and `numericOverflow`
    /// when the mapping itself leaves the finite Double range.
    public func evaluate(_ request: ConversionRequest) throws -> ConversionResult {
        guard request.value.isFinite else {
            throw UnitWiseError.invalidNumber("\(request.value)")
        }
        let base = request.from.scale.toBase(request.value)
        let output = request.to.scale.fromBase(base)
        guard base.isFinite, output.isFinite else {
            throw UnitWiseError.numericOverflow
        }
        let back = request.from.scale.fromBase(request.to.scale.toBase(output))
        let stable = ConversionEngine.isRoundTripStable(original: request.value, returned: back)
        return ConversionResult(request: request,
                                baseValue: base,
                                result: output,
                                roundTrip: back,
                                exact: stable)
    }

    /// Convenience: evaluate value/from/to directly.
    public func evaluate(value: Double, from: Unit, to: Unit) throws -> ConversionResult {
        let request = ConversionRequest(value: value,
                                        from: from,
                                        to: to,
                                        category: CategoryRegistry.category(withID: from.categoryID)
                                            ?? Category(id: from.categoryID,
                                                        displayName: from.categoryID,
                                                        summary: "",
                                                        baseUnitID: from.id,
                                                        units: [from]),
                                        expression: "\(value) \(from.symbol) to \(to.symbol)")
        return try evaluate(request)
    }

    // MARK: Tables

    /// Builds the full N×N conversion matrix used by `unitwise table`:
    /// `matrix[row][column]` is `value` of `units[row]` expressed in
    /// `units[column]`. The diagonal is therefore exactly `value`.
    public func matrix(category: Category, value: Double, units: [Unit]) -> [[Double]] {
        var grid: [[Double]] = []
        grid.reserveCapacity(units.count)
        for rowUnit in units {
            var row: [Double] = []
            row.reserveCapacity(units.count)
            for columnUnit in units {
                row.append(ConversionEngine.convert(value, from: rowUnit, to: columnUnit))
            }
            grid.append(row)
        }
        return grid
    }
}
