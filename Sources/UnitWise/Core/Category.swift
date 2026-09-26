//
//  Category.swift
//  unitwise
//
//  A `Category` groups the units of one measurement kind (length, mass,
//  temperature...) and names its canonical base unit. `CategoryRegistry`
//  assembles the ten built-in categories, and `UnitResolver` builds the
//  lookup indexes that let the parser turn raw tokens like "kms" or "MiB"
//  into concrete units.
//
//  Resolution order (exact → caseless → plural-stripped) is what makes
//  "MB" (megabyte) and "mb" (megabit) coexist while "5 KM TO MI" still works.
//

import Foundation

// MARK: - Category

/// One measurement category with its full unit table.
public struct Category: Equatable, CustomStringConvertible {

    /// Registry identifier, e.g. "length".
    public let id: String
    /// Human title, e.g. "Length".
    public let displayName: String
    /// One-line description shown by `unitwise list`.
    public let summary: String
    /// Identifier of the canonical base unit (must exist in `units`).
    public let baseUnitID: String
    /// Extra tokens accepted as the category name ("weight" → mass).
    public let aliases: [String]
    /// The units, ordered for stable table output.
    public let units: [Unit]
    /// Optional footnote (e.g. the data-size base explanation).
    public let note: String?

    /// Full initializer; see the property docs for field semantics.
    public init(id: String,
                displayName: String,
                summary: String,
                baseUnitID: String,
                aliases: [String] = [],
                units: [Unit],
                note: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.baseUnitID = baseUnitID
        self.aliases = Unit.dedupe(aliases)
        self.units = units
        self.note = note
    }

    /// Looks a unit up by its stable identifier.
    public func unit(withID id: String) -> Unit? {
        units.first { $0.id == id }
    }

    /// Looks a unit up by its exact display symbol.
    public func unit(withSymbol symbol: String) -> Unit? {
        units.first { $0.symbol == symbol }
    }

    /// All units in this category accepting `token` (exact alias match).
    public func units(matching token: String) -> [Unit] {
        units.filter { unit in unit.allAliases.contains(token) }
    }

    /// The canonical base unit, if the registry is well-formed.
    public var baseUnit: Unit? {
        unit(withID: baseUnitID)
    }

    /// Display symbols in table order.
    public var symbols: [String] {
        units.map { $0.symbol }
    }

    /// Every alias token of every unit (for suggestions and selftests).
    public var allAliasTokens: [String] {
        var seen = Set<String>()
        var tokens: [String] = []
        for unit in units {
            for alias in unit.allAliases where seen.insert(alias).inserted {
                tokens.append(alias)
            }
        }
        return tokens
    }

    public var description: String {
        "Category(\(id), \(units.count) units, base: \(baseUnitID))"
    }
}

// MARK: - CategoryRegistry

/// Assembles and indexes the ten built-in categories.
public enum CategoryRegistry {

    /// All categories in presentation order (length first, area last).
    /// Built once, lazily, on first access.
    public static let categories: [Category] = [
        LengthCategory.make(),
        MassCategory.make(),
        TemperatureCategory.make(),
        VolumeCategory.make(),
        SpeedCategory.make(),
        DataSizeCategory.make(),
        TimeCategory.make(),
        EnergyCategory.make(),
        PressureCategory.make(),
        AreaCategory.make()
    ]

    /// Categories by their identifier.
    public static func category(withID id: String) -> Category? {
        categories.first { $0.id == id }
    }

    /// Resolves a category by id, alias, or display name (case-insensitive).
    /// Exact-case alias hits are preferred so "temp" cannot collide with
    /// anything registered later.
    public static func category(matching token: String) -> Category? {
        if let exact = categories.first(where: { $0.id == token }) {
            return exact
        }
        for category in categories {
            if category.aliases.contains(token) {
                return category
            }
        }
        let lowered = token.lowercased()
        for category in categories {
            if category.id.lowercased() == lowered
                || category.aliases.map({ $0.lowercased() }).contains(lowered)
                || category.displayName.lowercased() == lowered {
                return category
            }
        }
        return nil
    }

    /// Sorted unique category vocabulary used by "did you mean" hints.
    public static var categoryVocabulary: [String] {
        var tokens = Set<String>()
        for category in categories {
            tokens.insert(category.id)
            tokens.formUnion(category.aliases.map { $0.lowercased() })
        }
        return tokens.sorted()
    }
}

// MARK: - UnitResolver

/// Indexes a set of categories for fast, deterministic unit lookup.
///
/// The resolver owns the exact-case and case-insensitive alias indexes plus
/// the plural-stripping fallback. It performs no error reporting itself —
/// the parser turns empty candidate lists into `unknownUnit` errors with
/// Levenshtein suggestions.
public final class UnitResolver {

    /// The indexed categories, in registry order.
    public let categories: [Category]

    /// alias (exact case) → units accepting it.
    private let exactIndex: [String: [Unit]]
    /// alias (lowercased) → units accepting it.
    private let caselessIndex: [String: [Unit]]
    /// category id → category.
    private let categoryIndex: [String: Category]

    /// Builds the indexes and validates registry invariants.
    ///
    /// Throws `UnitWiseError.config` when:
    ///   * a category id or unit id is duplicated,
    ///   * a unit has no usable alias,
    ///   * a linear factor or affine scale is zero/non-finite,
    ///   * a category's declared base unit is missing.
    public init(categories: [Category]) throws {
        self.categories = categories

        var exact: [String: [Unit]] = [:]
        var caseless: [String: [Unit]] = [:]
        var byID: [String: Category] = [:]

        for category in categories {
            guard byID[category.id] == nil else {
                throw UnitWiseError.config("duplicate category id '\(category.id)'")
            }
            byID[category.id] = category
            guard category.baseUnit != nil else {
                throw UnitWiseError.config(
                    "category '\(category.id)' is missing its base unit '\(category.baseUnitID)'")
            }
            var unitIDs = Set<String>()
            for unit in category.units {
                guard unitIDs.insert(unit.id).inserted else {
                    throw UnitWiseError.config(
                        "duplicate unit id '\(category.id).\(unit.id)'")
                }
                let aliases = unit.allAliases
                guard !aliases.isEmpty else {
                    throw UnitWiseError.config(
                        "unit '\(category.id).\(unit.id)' has no aliases")
                }
                switch unit.scale {
                case .linear(let factor):
                    guard factor.isFinite, factor != 0 else {
                        throw UnitWiseError.config(
                            "unit '\(category.id).\(unit.id)' has invalid factor \(factor)")
                    }
                case .affine(let scale, let offset):
                    guard scale.isFinite, scale != 0, offset.isFinite else {
                        throw UnitWiseError.config(
                            "unit '\(category.id).\(unit.id)' has invalid affine scale")
                    }
                }
                for alias in aliases {
                    exact[alias, default: []].append(unit)
                    caseless[alias.lowercased(), default: []].append(unit)
                }
            }
        }

        self.exactIndex = exact
        self.caselessIndex = caseless
        self.categoryIndex = byID
    }

    // MARK: Lookup

    /// Category for an identifier, or nil.
    public func category(withID id: String) -> Category? {
        categoryIndex[id]
    }

    /// Every candidate unit for a raw token, in registry order.
    ///
    /// Strategy:
    ///   1. exact-case alias match (lets "MB" vs "mb" mean different units),
    ///   2. case-insensitive match,
    ///   3. plural-stripped case-insensitive match
    ///      ("kilometers" → "kilometer", "inches" → "inch", "centuries" → "century").
    public func candidates(for token: String) -> [Unit] {
        if let hits = exactIndex[token], !hits.isEmpty {
            return UnitResolver.unique(hits)
        }
        let lowered = token.lowercased()
        if let hits = caselessIndex[lowered], !hits.isEmpty {
            return UnitResolver.unique(hits)
        }
        for variant in UnitResolver.pluralVariants(of: lowered) {
            if let hits = caselessIndex[variant], !hits.isEmpty {
                return UnitResolver.unique(hits)
            }
        }
        return []
    }

    /// Candidate units restricted to one category id.
    public func candidates(for token: String, in categoryID: String) -> [Unit] {
        candidates(for: token).filter { $0.categoryID == categoryID }
    }

    /// All unit alias tokens, sorted — the vocabulary for suggestions.
    public var vocabulary: [String] {
        caselessIndex.keys.sorted()
    }

    // MARK: Internals

    /// De-duplicates a candidate list by unit identity (category + id).
    static func unique(_ units: [Unit]) -> [Unit] {
        var seen = Set<String>()
        var output: [Unit] = []
        for unit in units where seen.insert("\(unit.categoryID).\(unit.id)").inserted {
            output.append(unit)
        }
        return output
    }

    /// Plural-stripping fallback variants of an already-lowercased token.
    static func pluralVariants(of lowered: String) -> [String] {
        var variants: [String] = []
        if lowered.hasSuffix("s"), lowered.count > 1 {
            variants.append(String(lowered.dropLast()))
        }
        if lowered.hasSuffix("es"), lowered.count > 2 {
            variants.append(String(lowered.dropLast(2)))
        }
        if lowered.hasSuffix("ies"), lowered.count > 3 {
            variants.append(String(lowered.dropLast(3)) + "y")
        }
        return variants
    }
}
