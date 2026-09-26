//
//  Unit.swift
//  unitwise
//
//  The unit model. A `Unit` is an immutable value describing one unit of
//  measurement: its identity (id/symbol/names), every token accepted for it
//  (aliases), and — crucially — its `UnitScale`, the canonical-factor mapping
//  between the unit and its category's base unit.
//
//  Conversion is canonical-factor based: to convert A → B we map A onto the
//  category base and then project onto B. Linear units need only a factor;
//  affine units (temperature scales) carry a scale *and* an offset so that
//  the math  base = value·scale + offset  is applied on both sides.
//

import Foundation

// MARK: - UnitScale

/// How a unit relates to its category's canonical base unit.
///
/// Invariants enforced by `UnitResolver` at registry-build time:
///   * `linear(factor:)` — factor must be finite and non-zero.
///   * `affine(scale:offset:)` — scale must be finite and non-zero.
public enum UnitScale: Equatable, Hashable {

    /// Pure proportionality: `base = value × factor`.
    case linear(factor: Double)

    /// Affine mapping: `base = value × scale + offset`.
    /// Used by temperature scales where the zero points differ.
    case affine(scale: Double, offset: Double)

    /// True when the scale carries an offset (non-pure-proportional).
    public var isAffine: Bool {
        if case .affine = self { return true }
        return false
    }

    /// The multiplicative component of the scale, if any.
    public var linearFactor: Double? {
        switch self {
        case .linear(let factor): return factor
        case .affine(let scale, _): return scale
        }
    }

    /// Maps a quantity expressed in this unit onto the base unit.
    public func toBase(_ value: Double) -> Double {
        switch self {
        case .linear(let factor):
            return value * factor
        case .affine(let scale, let offset):
            return value * scale + offset
        }
    }

    /// Maps a base-unit quantity back into this unit.
    public func fromBase(_ value: Double) -> Double {
        switch self {
        case .linear(let factor):
            return value / factor
        case .affine(let scale, let offset):
            return (value - offset) / scale
        }
    }

    /// Short human-readable form used by `list` and `--verbose`.
    public var readable: String {
        switch self {
        case .linear(let factor):
            return "× \(Unit.trimNumber(factor))"
        case .affine(let scale, let offset):
            return "× \(Unit.trimNumber(scale)) + \(Unit.trimNumber(offset))"
        }
    }

    /// Inverse human-readable form ("base → this unit").
    public var readableInverse: String {
        switch self {
        case .linear(let factor):
            return "÷ \(Unit.trimNumber(factor))"
        case .affine(let scale, let offset):
            return "(base − \(Unit.trimNumber(offset))) ÷ \(Unit.trimNumber(scale))"
        }
    }
}

// MARK: - Dimension

/// Minimal contract shared by every measurable unit in the registry.
///
/// `Unit` is the only conforming type today; the protocol exists so future
/// composite units (e.g. compound rates) can join the conversion engine
/// without changing call sites.
public protocol Dimension {
    /// Display symbol, e.g. "m", "°F", "MiB".
    var symbol: String { get }
    /// Canonical-factor mapping to the category base unit.
    var scale: UnitScale { get }
    /// The multiplicative component of `scale` (factor, or affine scale).
    var linearFactor: Double? { get }
    /// Whether two dimensions can be converted into each other.
    func isCompatible(with other: Self) -> Bool
}

// MARK: - Unit

/// One unit of measurement inside one category.
///
/// All string identity fields are immutable. Aliases are matched by
/// `UnitResolver`: first with exact case (so "MB" ≠ "mb"), then
/// case-insensitively, then after plural stripping.
public struct Unit: Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {

    /// Identifier of the owning category, e.g. "length".
    public let categoryID: String
    /// Stable identifier inside the category, e.g. "kilometer".
    public let id: String
    /// Display symbol, e.g. "km".
    public let symbol: String
    /// Singular display name, e.g. "kilometer".
    public let singular: String
    /// Plural display name, e.g. "kilometers" (may be irregular: "feet").
    public let plural: String
    /// Extra lookup tokens beyond symbol/singular/plural, e.g. ["klick"].
    public let aliases: [String]
    /// Canonical-factor mapping to the base unit.
    public let scale: UnitScale
    /// Free-form classification tags ("si", "binary", "decimal", "bits"...).
    public let tags: Set<String>
    /// Optional one-line definition shown by `list <category>`.
    public let definition: String?

    /// Full memberwise initializer with convenient defaults.
    public init(categoryID: String,
                id: String,
                symbol: String,
                singular: String,
                plural: String? = nil,
                aliases: [String] = [],
                scale: UnitScale,
                tags: Set<String> = [],
                definition: String? = nil) {
        self.categoryID = categoryID
        self.id = id
        self.symbol = symbol
        self.singular = singular
        self.plural = plural ?? singular + "s"
        self.aliases = Unit.dedupe(aliases)
        self.scale = scale
        self.tags = tags
        self.definition = definition
    }

    /// Convenience factory for proportional units.
    public static func linear(categoryID: String,
                              id: String,
                              symbol: String,
                              singular: String,
                              factor: Double,
                              plural: String? = nil,
                              aliases: [String] = [],
                              tags: Set<String> = [],
                              definition: String? = nil) -> Unit {
        Unit(categoryID: categoryID,
             id: id,
             symbol: symbol,
             singular: singular,
             plural: plural,
             aliases: aliases,
             scale: .linear(factor: factor),
             tags: tags,
             definition: definition)
    }

    /// Convenience factory for offset-carrying units (temperature).
    public static func affine(categoryID: String,
                              id: String,
                              symbol: String,
                              singular: String,
                              scale: Double,
                              offset: Double,
                              plural: String? = nil,
                              aliases: [String] = [],
                              tags: Set<String> = [],
                              definition: String? = nil) -> Unit {
        Unit(categoryID: categoryID,
             id: id,
             symbol: symbol,
             singular: singular,
             plural: plural,
             aliases: aliases,
             scale: .affine(scale: scale, offset: offset),
             tags: tags,
             definition: definition)
    }

    // MARK: Derived identity

    /// Every token that should resolve to this unit, in priority order.
    /// The symbol is listed first so exact-case matching prefers it.
    public var allAliases: [String] {
        Unit.dedupe([symbol, singular, plural] + aliases)
    }

    /// Preferred display name (singular).
    public var displayName: String { singular }

    /// Short description used in tables: "mass.kilogram (kg)".
    public var qualifiedName: String {
        "\(categoryID).\(id) (\(symbol))"
    }

    /// True when `scale` is a pure multiplication (no offset).
    public var isLinear: Bool { !scale.isAffine }

    // MARK: Conversion

    /// Canonical-factor conversion of `value` from this unit to `other`.
    /// Returns nil when the units belong to different categories.
    public func convert(_ value: Double, to other: Unit) -> Double? {
        guard isCompatible(with: other) else { return nil }
        return other.scale.fromBase(scale.toBase(value))
    }

    /// Converts through the category base and reports the intermediate value.
    /// Returns (baseValue, result) or nil on category mismatch.
    public func convertViaBase(_ value: Double, to other: Unit) -> (base: Double, result: Double)? {
        guard isCompatible(with: other) else { return nil }
        let base = scale.toBase(value)
        return (base, other.scale.fromBase(base))
    }

    // MARK: Dimension conformance

    /// Two units are compatible when they share a category.
    public func isCompatible(with other: Unit) -> Bool {
        categoryID == other.categoryID
    }

    // MARK: Descriptions

    public var description: String { qualifiedName }

    public var debugDescription: String {
        "Unit(id: \(id), symbol: \(symbol), scale: \(scale.readable))"
    }

    // MARK: Helpers

    /// Order-preserving, empty-dropping de-duplication.
    static func dedupe(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for candidate in candidates where !candidate.isEmpty {
            if seen.insert(candidate).inserted {
                output.append(candidate)
            }
        }
        return output
    }

    /// Compact number rendering for formulas and tables (12 significant
    /// digits, trailing zeros trimmed, locale-independent "." decimal point).
    public static func trimNumber(_ value: Double) -> String {
        if value == 0 { return "0" }
        let formatted = String(format: "%.12g", value)
        return formatted
    }
}

// MARK: - Dimension conformance declaration

extension Unit: Dimension {}
